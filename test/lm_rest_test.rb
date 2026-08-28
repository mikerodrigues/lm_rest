require 'test_helper'

class LMRestTest < Minitest::Test
  Response = Struct.new(:code, :body, :headers)

  class FakeClient < LMRest::APIClient
    attr_reader :last_request, :last_transport

    def request(method, uri, params = nil, content_type: 'application/json')
      @last_transport = :request
      @last_request = [method, uri, params, content_type]
      { 'id' => 1, 'name' => 'response' }
    end

    def paginate(uri, params, method = :get, payload = nil, content_type = 'application/json')
      @last_transport = :paginate
      @last_request = [method, uri.call(params), payload, content_type]
      { 'items' => [{ 'id' => 1, 'name' => 'response' }], 'total' => 1 }
    end
  end

  class PagingClient < LMRest::APIClient
    attr_reader :requests

    def initialize(total_items, company = 'company', access_id = 'access_id', access_key = 'access_key')
      @total_items = total_items
      @requests = []
      super(company, access_id, access_key)
    end

    def request(method, uri, params = nil, content_type: 'application/json')
      @requests << [method, uri, params, content_type]
      query_params = uri.split('?', 2)[1].to_s.split('&').each_with_object({}) do |part, query|
        next if part.empty?

        key, value = part.split('=', 2)
        query[key] = value
      end

      size = query_params.fetch('size', '0').to_i
      offset = query_params.fetch('offset', '0').to_i
      count = [size, @total_items - offset].min
      count = 0 if count.negative?

      {
        'items' => count.times.map { |index| { 'id' => offset + index + 1 } },
        'total' => @total_items
      }
    end
  end

  def test_that_it_has_a_version_number
    refute_nil ::LMRest::VERSION
  end

  def test_defines_swagger_operation_methods_and_legacy_aliases
    client = FakeClient.new('company', 'access_id', 'access_key')

    assert_respond_to client, :get_device_list
    assert_respond_to client, :get_devices
    assert_respond_to client, :get_device_datasource_instance_list
    assert_respond_to client, :delete_device
    assert_respond_to client, :get_version
    assert_respond_to client, :get_message
  end

  def test_get_alias_builds_path_and_query_string
    client = FakeClient.new('company', 'access_id', 'access_key')

    client.get_device(42, fields: 'name')

    assert_equal [:get, '/device/devices/42?fields=name', nil, 'application/json'], client.last_request
  end

  def test_paginated_list_alias_uses_generated_operation
    client = FakeClient.new('company', 'access_id', 'access_key')

    client.get_devices(filter: 'name:"web*"', size: 1)

    assert_equal :paginate, client.last_transport
    assert_equal [:get, '/device/devices?filter=name%3A%22web*%22&size=1', nil, 'application/json'], client.last_request
  end

  def test_generated_get_list_uses_paginate_when_swagger_marks_paginated_response_only
    client = FakeClient.new('company', 'access_id', 'access_key')

    client.get_log_source_list(format: 'json')

    assert_equal :paginate, client.last_transport
    assert_equal [:get, '/setting/logsources?format=json', nil, 'application/json'], client.last_request
  end

  def test_generated_get_with_path_params_uses_paginate_when_swagger_marks_paginated_response_only
    client = FakeClient.new('company', 'access_id', 'access_key')

    client.get_update_reason_list_by_config_source_id(42, size: 1)

    assert_equal :paginate, client.last_transport
    assert_equal [:get, '/setting/configsources/42/updatereasons?size=1', nil, 'application/json'], client.last_request
  end

  def test_update_alias_accepts_resource_body
    client = FakeClient.new('company', 'access_id', 'access_key')
    device = LMRest::Resource.new('id' => 42, 'name' => 'web01')

    client.update_device(device)

    assert_equal [:put, '/device/devices/42', { 'id' => 42, 'name' => 'web01' }, 'application/json'], client.last_request
  end

  def test_nested_operation_fills_multiple_path_params
    client = FakeClient.new('company', 'access_id', 'access_key')

    client.get_device_datasource_instance_list(10, 20, size: 1)

    assert_equal [:get, '/device/devices/10/devicedatasources/20/instances?size=1', nil, 'application/json'], client.last_request
  end

  def test_ack_collector_down_uses_generated_v3_path
    client = FakeClient.new('company', 'access_id', 'access_key')
    collector = LMRest::Resource.new('id' => 7)

    client.ack_collector_down(collector, 'acked')

    assert_equal [:post, '/setting/collector/collectors/7/ackdown', { comment: 'acked' }, 'application/json'], client.last_request
  end

  def test_resource_uses_hash_backing_without_singleton_method_generation
    resource = LMRest::Resource.new('name' => 'web01', 'to_h' => 'shadow')

    resource.name = 'web02'

    assert_equal 'web02', resource.name
    assert_equal 'shadow', resource['to_h']
    assert_equal({ 'name' => 'web02', 'to_h' => 'shadow' }, resource.to_h)
    refute_includes resource.singleton_methods, :name
  end

  def test_resource_parse_returns_nil_for_nil_body
    assert_nil LMRest::Resource.parse(nil)
  end

  def test_handle_response_raises_without_writing_stdout
    client = FakeClient.new('company', 'access_id', 'access_key')
    response = Response.new(500, '{"message":"secret"}', {})

    out, err = capture_io do
      error = assert_raises(LMRest::APIError) { client.handle_response(response) }
      assert_equal 500, error.status
      assert_equal '{"message":"secret"}', error.body
    end

    assert_empty out
    assert_empty err
  end

  def test_parse_response_handles_string_content_type_header
    client = FakeClient.new('company', 'access_id', 'access_key')
    response = Response.new(200, '{"ok":true}', { 'content_type' => 'application/json' })

    assert_equal({ 'ok' => true }, client.parse_response(response))
  end

  def test_paginate_fetches_all_pages_when_total_exceeds_limit
    client = PagingClient.new(2500)

    datasources = client.get_datasources

    assert_equal 2500, datasources.length
    assert_equal [
      [:get, '/setting/datasources?size=1000&offset=0', nil, 'application/json'],
      [:get, '/setting/datasources?size=1000&offset=1000', nil, 'application/json'],
      [:get, '/setting/datasources?size=500&offset=2000', nil, 'application/json']
    ], client.requests
  end

  def test_paginate_fetches_exact_limit_multiple_without_zero_sized_page
    client = PagingClient.new(2000)

    datasources = client.get_datasources

    assert_equal 2000, datasources.length
    assert_equal [
      [:get, '/setting/datasources?size=1000&offset=0', nil, 'application/json'],
      [:get, '/setting/datasources?size=1000&offset=1000', nil, 'application/json']
    ], client.requests
  end

  def test_paginate_respects_requested_size_below_limit
    client = PagingClient.new(2500)

    datasources = client.get_datasources(size: 50)

    assert_equal 50, datasources.length
    assert_equal [
      [:get, '/setting/datasources?size=50&offset=0', nil, 'application/json']
    ], client.requests
  end
end
