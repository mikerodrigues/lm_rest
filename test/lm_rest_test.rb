require 'test_helper'

class LMRestTest < Minitest::Test
  class FakeClient < LMRest::APIClient
    attr_reader :last_request

    def request(method, uri, params = nil, content_type: 'application/json')
      @last_request = [method, uri, params, content_type]
      { 'id' => 1, 'name' => 'response' }
    end

    def paginate(uri, params, method = :get, payload = nil, content_type = 'application/json')
      @last_request = [method, uri.call(params), payload, content_type]
      { 'items' => [{ 'id' => 1, 'name' => 'response' }], 'total' => 1 }
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

    assert_equal [:get, '/device/devices?filter=name%3A%22web*%22&size=1', nil, 'application/json'], client.last_request
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
end
