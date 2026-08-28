require 'date'
require 'base64'
require 'openssl'
require 'rest-client'
require 'json'
require 'uri'
require 'lm_rest/resource'
require 'lm_rest/request_params'

module LMRest
  class APIError < StandardError
    attr_reader :status, :body, :headers

    def initialize(response)
      @status = response.code
      @body = response.body
      @headers = response.headers

      super("LogicMonitor API request failed with status #{@status}")
    end
  end

  class APIClient
    include RequestParams

    ITEMS_SIZE_LIMIT = 1000
    ITEMS_SIZE_DEFAULT = 50

    BASE_URL_PREFIX = 'https://'
    BASE_URL_SUFFIX = '.logicmonitor.com/santaba/rest'

    attr_reader :company, :api_url, :access_id
    attr_reader :limit, :remaining, :window

    def initialize(company = nil, access_id =  nil, access_key = nil)
      APIClient.setup
      @company     = company
      @access_id   = access_id
      @access_key  = access_key
      @api_url     = BASE_URL_PREFIX + company + BASE_URL_SUFFIX
    end

    def uri_to_resource_uri(uri)
      # Split the URL down to the resource
      #
      # Here's an example of the process:
      # /setting/datasources/1/graphs?key-value&
      # /setting/datasources/1/graphs
      # /setting/datasources/
      # /setting/datasources
      #
      uri.split("?")[0].split("/").join("/")
    end

    def sign(method, uri, data = nil, content_type = 'application/json')
      resource_uri = uri_to_resource_uri(uri)

      time = DateTime.now.strftime('%Q')

      http_method = method.to_s.upcase

      data = data_for_signature(data, content_type)

      message =  "#{http_method}#{time}#{data}#{resource_uri}"

      signature = Base64.strict_encode64(
        OpenSSL::HMAC.hexdigest(
          OpenSSL::Digest.new('sha256'),
          access_key,
          message
        )
      )

      "LMv1 #{access_id}:#{signature}:#{time}"
    end

    def request(method, uri, params = nil, content_type: 'application/json')
      headers = build_headers(method, uri, params, content_type)
      url = api_url + uri
      payload = serialize_payload(params, content_type)

      response = execute_request(method.to_sym, url, payload, headers)
      handle_response(response)

      parse_response(response)
    end

    def build_headers(method, uri, params, content_type)
      headers = {
        'Authorization' => sign(method, uri, params, content_type),
        'Accept' => 'application/json, text/javascript',
        'X-version' => '3'
      }

      headers['Content-Type'] = content_type unless multipart_form?(content_type)
      headers
    end

    def execute_request(method, url, payload, headers)
      case method
      when :get
        RestClient.get(url, headers)
      when :post
        RestClient.post(url, payload, headers)
      when :put
        RestClient.put(url, payload, headers)
      when :patch
        RestClient.patch(url, payload, headers)
      when :delete
        if payload.nil?
          RestClient.delete(url, headers)
        else
          RestClient::Request.execute(method: :delete, url: url, payload: payload, headers: headers)
        end
      else
        raise ArgumentError, "unsupported HTTP method: #{method}"
      end
    end

    def handle_response(response)
      raise APIError.new(response) unless response.code.between?(200, 299)

      @limit = response.headers[:x_rate_limit_limit] || response.headers['x_rate_limit_limit']
      @remaining = response.headers[:x_rate_limit_remaining] || response.headers['x_rate_limit_remaining']
      @window = response.headers[:x_rate_limit_window] || response.headers['x_rate_limit_window']
    end

    def parse_response(response)
      return nil if response.body.nil? || response.body.empty?

      content_type = response.headers[:content_type] || response.headers['content_type']

      if content_type.to_s.include?('application/json')
        JSON.parse(response.body)
      else
        response.body
      end
    end

    # Handles making multiple requests to the API if pagination is necessary.
    # Pagination is transparent, and simplifies requests that result in more
    # than ITEMS_SIZE_LIMIT being returned.
    #
    # If you need to walk through resources page-by-page manullay, use the
    # request() method with the 'offset' and 'size' params
    #
    def paginate(uri, params, method = :get, payload = nil, content_type = 'application/json')
      params = normalize_params_hash(params)
      user_size = params[:size]&.to_i
      params[:size] = user_size && user_size < ITEMS_SIZE_LIMIT ? user_size : ITEMS_SIZE_LIMIT
      params[:offset] = (params[:offset] || 0).to_i

      body = request(method, uri.call(params), payload, content_type: content_type)
      return body unless body.is_a?(Hash) && body.key?('items')

      total = (body['total'] || body['items'].length).to_i
      user_size = determine_user_size(user_size, total)
      item_collector = body['items'].first(user_size)

      while item_collector.length < user_size
        params[:offset] += params[:size].to_i
        remaining = user_size - item_collector.length
        params[:size] = [remaining, ITEMS_SIZE_LIMIT].min
        body = request(method, uri.call(params), payload, content_type: content_type)
        break unless body.is_a?(Hash) && body.key?('items')
        break if body['items'].empty?

        item_collector.concat(body['items'].first(remaining))
      end

      body['items'] = item_collector
      body
    end

    def determine_user_size(user_size, total)
      user_size ||= total
      user_size > total ? total : user_size
    end

    def self.define_operation_methods(operations)
      operations.each do |method_name, operation|
        define_operation_method(method_name, operation)
      end
    end

    def self.define_operation_method(method_name, operation)
      define_method(method_name) do |*args|
        perform_operation(operation, args)
      end
    end

    def self.define_alias_methods(aliases)
      aliases.each do |alias_name, target_name|
        next if alias_name == target_name
        next unless method_defined?(target_name)

        define_method(alias_name) do |*args|
          public_send(target_name, *args)
        end
      end
    end

    def self.define_action_methods(resource_type, attributes)
      singular = attributes['method_names']['singular']
      plural = attributes['method_names']['plural']
      resource_uri = attributes['url']

      attributes['actions'].each do |action|
        case action
        when 'get'
          define_get_methods(resource_uri, singular, plural)
        when 'add'
          define_add_method(resource_uri, singular)
        when 'update'
          define_update_method(resource_uri, singular)
        when 'delete'
          define_delete_method(resource_uri, singular)
        end
      end
    end

    def self.define_get_methods(resource_uri, singular, plural)
      uri = lambda { |params| "#{resource_uri}#{RequestParams.parameterize(params)}" }

      define_plural_get_method(uri, plural) unless plural.nil?
      define_singular_get_method(resource_uri, singular) unless singular.nil?
    end

    def self.define_plural_get_method(uri, plural)
      define_method("get_#{plural}") do |params = {}|
        Resource.parse paginate(uri, params)
      end
    end

    def self.define_singular_get_method(resource_uri, singular)
      define_method("get_#{singular}") do |*args|
        case args.size
        when 0
          Resource.parse request(:get, "#{resource_uri}", nil)
        when 1
          Resource.parse request(:get, "#{resource_uri}/#{args[0]}", nil)
        when 2
          Resource.parse request(:get, "#{resource_uri}/#{args[0]}#{RequestParams.parameterize(args[1])}", nil)
        else
          raise ArgumentError.new("wrong number for arguments (#{args.count} for 1..2)")
        end
      end
    end

    def self.define_add_method(resource_uri, singular)
      define_method("add_#{singular}") do |properties|
        properties_hash = properties.is_a?(LMRest::Resource) ? properties.to_h : properties
        Resource.parse request(:post, "#{resource_uri}", properties_hash)
      end
    end

    def self.define_update_method(resource_uri, singular)
      define_method("update_#{singular}") do |id, properties = {}|
        if id.is_a?(LMRest::Resource)
          properties = id.to_h if properties.empty?
          id = id.id
        end

        Resource.parse request(:put, "#{resource_uri}/#{id}", properties)
      end
    end

    def self.define_delete_method(resource_uri, singular)
      define_method("delete_#{singular}") do |id, params = {}|
        id = id.id if id.is_a?(LMRest::Resource)
        uri = "#{resource_uri}/#{id}#{RequestParams.parameterize(params)}"
        Resource.parse request(:delete, uri, nil)
      end
    end

    def self.define_child_methods(resource_type, attributes)
      parent_singular = attributes['method_names']['singular']
      parent_resource_uri = attributes['url']
      children = attributes['children']

      children.each do |child_name|
        if @@api_json[child_name]
          child = @@api_json[child_name]
        else
          raise "Child resource " + child_name + " not defined."
        end

        child_singular = child['method_names']['singular']
        child_plural = child['method_names']['plural']
        child_resource_uri = attributes['url'].split("/").last

        child['actions'].each do |action|
            case action
            when 'get'
            define_method("get_#{parent_singular}_#{child_plural}") do |id, params = {}, &block|
              uri = lambda { |params| "#{parent_resource_uri}/#{id}/#{child['method_names']['plural']}#{RequestParams.parameterize(params)}" }
              Resource.parse paginate(uri, params)
            end

            when 'add'
            define_method("add_#{parent_singular}_#{child_singular}") do |parent_id, properties|
              properties_hash = properties.is_a?(LMRest::Resource) ? properties.to_h : properties
              Resource.parse request(:post, "#{parent_resource_uri}/#{parent_id}/#{child_resource_uri}", properties_hash)
            end

            when 'update'
            define_method("update_#{parent_singular}_#{child_singular}") do |parent_id, child_id, properties = {}|
              Resource.parse request(:put, "#{parent_resource_uri}/#{parent_id}/#{child_resource_uri}/#{child_id}", properties)
            end

            when 'delete'
            define_method("delete_#{parent_singular}_#{child_singular}") do |parent_id, child_id|
              Resource.parse request(:delete, "#{parent_resource_uri}/#{parent_id}/#{child_resource_uri}/#{child_id}", nil)
            end
            end
        end
      end
    end

    # Define methods based on the JSON structure
    def self.setup
      return if @api_methods_defined

      @@api_definition_path = File.expand_path(File.join(File.dirname(__FILE__), "../../api.json"))
      @@api_json = JSON.parse(File.read(@@api_definition_path))

      if @@api_json['operations']
        define_operation_methods(@@api_json['operations'])
        define_alias_methods(@@api_json['aliases'] || {})
      else
        @@api_json.each do |resource_type, attributes|
          define_action_methods(resource_type, attributes) if attributes['actions']
          define_child_methods(resource_type, attributes) if attributes['children']
        end
      end

      @api_methods_defined = true
    end

    # Ack a down collector, pass the ID and a comment
    def ack_collector_down(id, comment)
      ack_collector_down_alert_by_id(resource_id(id), comment: comment)
    end

    # run a report
    def run_report(id, type = "generateReport")
      if id.class == LMRest::Resource
        Resource.parse request(:post, "/functions", {reportId: id.id, type: type})
      else
        Resource.parse request(:post, "/functions", {reportId: id, type: type})
      end
    end

    # Helper to return execution counts for all websites across a time window.
    # Assumes website interval is in minutes and locations/checkpoints is an array
    # or comma-separated list.
    def website_execution_stats(days = 30)
      raise ArgumentError, "days must be positive" if days <= 0

      websites = get_websites

      per_site = websites.map do |site|
        interval = website_interval_minutes(site)
        location_count = website_location_count(site)
        next if interval.nil? || interval <= 0

        executions = (days * 24 * 60.0 / interval * location_count).ceil

        {
          id: site.respond_to?(:id) ? site.id : nil,
          name: site.respond_to?(:name) ? site.name : nil,
          interval_minutes: interval,
          location_count: location_count,
          executions: executions
        }
      end.compact

      {
        days: days,
        website_count: per_site.count,
        total_executions: per_site.sum { |row| row[:executions] },
        websites: per_site
      }
    end

    private

    attr_accessor :access_key

    def perform_operation(operation, args)
      path_values, body, query_params = coerce_operation_arguments(operation, args)
      content_type = request_content_type(operation)
      method = operation['method'].to_sym
      uri = lambda { |params| operation_uri(operation, path_values, params) }

      response =
        if operation_paginated?(operation)
          paginate(uri, query_params, method, body, content_type)
        else
          request(method, uri.call(query_params), body, content_type: content_type)
        end

      Resource.parse(response)
    end

    def coerce_operation_arguments(operation, args)
      args = args.dup
      path_param_names = operation['path_params'] || []
      has_body = !!operation['body_param']
      query_params = {}
      inferred_body = nil

      if has_body
        if args.length > path_param_names.length + 1 && args.last.is_a?(Hash)
          query_params = args.pop
        elsif !operation['body_required'] &&
              args.length == path_param_names.length + 1 &&
              args.last.is_a?(Hash) &&
              query_params_only?(args.last, operation)
          query_params = args.pop
        end

        if path_param_names.length == 1 &&
           args.length == 1 &&
           resource_like?(args.first) &&
           %w[put patch].include?(operation['method'])
          inferred_body = args.first
        end
      elsif args.length > path_param_names.length && args.last.is_a?(Hash)
        query_params = args.pop
      end

      path_values = path_param_names.map do
        value = args.shift
        value = inferred_body if value.nil?
        resource_id(value)
      end

      if path_values.any?(&:nil?)
        raise ArgumentError, "#{operation['name']} requires path params: #{path_param_names.join(', ')}"
      end

      body = nil
      if has_body
        body_arg = args.shift || inferred_body
        if body_arg.nil? && operation['body_required']
          raise ArgumentError, "#{operation['name']} requires a request body"
        end
        body = resource_to_hash(body_arg) unless body_arg.nil?
      end

      unless args.empty?
        raise ArgumentError, "wrong number of arguments for #{operation['name']}"
      end

      [path_values, body, normalize_params_hash(query_params)]
    end

    def operation_uri(operation, path_values, query_params)
      uri = operation['path'].dup

      (operation['path_params'] || []).zip(path_values).each do |name, value|
        uri.gsub!("{#{name}}", URI.encode_www_form_component(value.to_s))
      end

      "#{uri}#{RequestParams.parameterize(query_params)}"
    end

    def request_content_type(operation)
      Array(operation['consumes']).find { |type| type && !type.empty? } || 'application/json'
    end

    def operation_paginated?(operation)
      operation['paginated'] || (operation['method'] == 'get' && operation['paginated_response'])
    end

    def normalize_params_hash(params)
      return {} if params.nil?

      params.each_with_object({}) do |(key, value), normalized|
        normalized[key.to_sym] = value
      end
    end

    def query_params_only?(params, operation)
      query_param_names = operation['query_params'] || []
      return false if query_param_names.empty?

      params.keys.all? { |key| query_param_names.include?(key.to_s) }
    end

    def resource_like?(value)
      value.is_a?(LMRest::Resource) || value.is_a?(Hash)
    end

    def resource_id(value)
      case value
      when LMRest::Resource
        value.id if value.respond_to?(:id)
      when Hash
        value[:id] || value['id']
      else
        value
      end
    end

    def resource_to_hash(value)
      value.is_a?(LMRest::Resource) ? value.to_h : value
    end

    def data_for_signature(data, content_type)
      return '' if data.nil? || (data.respond_to?(:empty?) && data.empty?)
      return '' if multipart_form?(content_type)
      return data if data.is_a?(String)

      data.to_json.to_s
    end

    def serialize_payload(payload, content_type)
      return nil if payload.nil?
      return payload if multipart_form?(content_type)
      return payload if payload.is_a?(String)

      payload.to_json
    end

    def multipart_form?(content_type)
      content_type.to_s.include?('multipart/form-data')
    end

    def website_interval_minutes(site)
      interval_attrs = %i[checkInterval interval pollingInterval testInterval]
      interval_attrs.each do |attr|
        next unless site.respond_to?(attr)
        value = site.send(attr)
        return value.to_f if value
      end
      nil
    end

    def website_location_count(site)
      location_attrs = %i[checkpoints checkpointIds checkpointId locations locationIds]
      location_attrs.each do |attr|
        next unless site.respond_to?(attr)
        value = site.send(attr)
        count = count_locations(value)
        return count unless count.nil?
      end
      0
    end

    def count_locations(value)
      case value
      when Array
        value.compact.length
      when String
        value.split(",").map(&:strip).reject(&:empty?).length
      when Numeric
        1
      else
        nil
      end
    end
  end
end
