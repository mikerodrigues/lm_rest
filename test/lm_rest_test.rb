require 'test_helper'

class LMRestTest < Minitest::Test
  class FakeClient < LMRest::APIClient
    attr_reader :last_request

    def request(method, uri, params = {})
      @last_request = [method, uri, params]
      { 'id' => 1, 'name' => 'response' }
    end

    def paginate(uri, params)
      @last_request = [:get, uri.call(params), nil]
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

    def request(method, uri, params = {})
      @requests << [method, uri, params]
      query_string = uri.split('?', 2)[1].to_s
      query_params = query_string.split('&').each_with_object({}) do |part, query|
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

  def test_defines_delete_methods_for_existing_and_new_resources
    client = FakeClient.new('company', 'access_id', 'access_key')

    assert_respond_to client, :delete_device
    assert_respond_to client, :delete_access_group
    assert_respond_to client, :delete_action_chain
    assert_respond_to client, :delete_diagnostic_source
    assert_respond_to client, :delete_log_source
    assert_respond_to client, :delete_report_group
    assert_respond_to client, :delete_topology_source
  end

  def test_delete_method_builds_path_and_query_string
    client = FakeClient.new('company', 'access_id', 'access_key')

    client.delete_device(42, deleteHard: true)

    assert_equal [:delete, '/device/devices/42?deleteHard=true', nil], client.last_request
  end

  def test_delete_method_accepts_resource_objects
    client = FakeClient.new('company', 'access_id', 'access_key')
    device = LMRest::Resource.new('id' => 42, 'name' => 'web01')

    client.delete_device(device)

    assert_equal [:delete, '/device/devices/42', nil], client.last_request
  end

  def test_execute_request_uses_restclient_delete_with_headers
    client = LMRest::APIClient.new('company', 'access_id', 'access_key')
    headers = { 'Authorization' => 'token' }
    captured = nil

    rest_client_singleton = RestClient.singleton_class
    rest_client_singleton.class_eval do
      alias_method :__lm_rest_test_delete, :delete
      define_method(:delete) do |url, passed_headers|
        captured = [url, passed_headers]
      end
    end

    begin
      client.execute_request(:delete, 'https://company.logicmonitor.com/santaba/rest/device/devices/42', nil, headers)
    ensure
      rest_client_singleton.class_eval do
        remove_method :delete
        alias_method :delete, :__lm_rest_test_delete
        remove_method :__lm_rest_test_delete
      end
    end

    assert_equal ['https://company.logicmonitor.com/santaba/rest/device/devices/42', headers], captured
  end

  def test_resource_parse_returns_nil_for_nil_body
    assert_nil LMRest::Resource.parse(nil)
  end

  def test_paginate_fetches_all_pages_when_total_exceeds_limit
    client = PagingClient.new(2500)

    datasources = client.get_datasources

    assert_equal 2500, datasources.length
    assert_equal [
      [:get, '/setting/datasources?size=1000&offset=0', nil],
      [:get, '/setting/datasources?size=1000&offset=1000', nil],
      [:get, '/setting/datasources?size=500&offset=2000', nil]
    ], client.requests
  end

  def test_paginate_fetches_exact_limit_multiple_without_zero_sized_page
    client = PagingClient.new(2000)

    datasources = client.get_datasources

    assert_equal 2000, datasources.length
    assert_equal [
      [:get, '/setting/datasources?size=1000&offset=0', nil],
      [:get, '/setting/datasources?size=1000&offset=1000', nil]
    ], client.requests
  end

  def test_paginate_respects_requested_size_below_limit
    client = PagingClient.new(2500)

    datasources = client.get_datasources(size: 50)

    assert_equal 50, datasources.length
    assert_equal [
      [:get, '/setting/datasources?size=50&offset=0', nil]
    ], client.requests
  end
end
