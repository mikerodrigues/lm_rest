require 'date'
require 'base64'
require 'openssl'
require 'rest-client'
require 'json'
require 'lm_rest/resource'
require 'lm_rest/request_params'

module LMRest
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

    def sign(method, uri, data = nil)

      resource_uri = uri_to_resource_uri(uri)

      time = DateTime.now.strftime('%Q')

      http_method = method.to_s.upcase

      if data.nil? || data.empty?
        data = ''
      else
        data = data.to_json.to_s
      end

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

    def request(method, uri, params = {})
      headers = build_headers(method, uri, params)
      url = api_url + uri
      json_params = params.to_json

      response = execute_request(method, url, json_params, headers)
      handle_response(response)

      if response.headers[:content_type] == "application/json"
        JSON.parse(response.body)
      else
        response.body
      end
    end

    def build_headers(method, uri, params)
      {
        'Authorization' => sign(method, uri, params),
        'Content-Type' => 'application/json',
        'Accept' => 'application/json, text/javascript',
        'X-version' => '3'
      }
    end

    def execute_request(method, url, json_params, headers)
      begin
        case method
        when :get
          RestClient.get(url, headers)
        when :post
          RestClient.post(url, json_params, headers)
        when :put
          RestClient.put(url, json_params, headers)
        when :delete
          RestClient.delete(url, headers: headers)
        end
      rescue => e
        puts e.http_body
        raise
      end
    end

    def handle_response(response)
      if response.code != 200
        puts "#{response.code}: #{response.body}"
        raise
      end

      @limit = response.headers['x_rate_limit_limit']
      @remaining = response.headers['x_rate_limit_remaining']
      @window = response.headers['x_rate_limit_window']
    end

    # Handles making multiple requests to the API if pagination is necessary.
    # Pagination is transparent, and simplifies requests that result in more
    # than ITEMS_SIZE_LIMIT being returned.
    #
    # If you need to walk through resources page-by-page manullay, use the
    # request() method with the 'offset' and 'size' params
    #
    def paginate(uri, params)
      user_size = params[:size]
      params[:size] = ITEMS_SIZE_LIMIT
      params[:offset] ||= 0

      body = request(:get, uri.call(params), nil)
      item_collector = body['items']
      total = body['total']
      user_size = determine_user_size(user_size, total)

      pages_remaining = calculate_pages_remaining(user_size)

      fetch_remaining_pages(uri, params, item_collector, pages_remaining, user_size)

      body['items'] = item_collector
      body
    end

    def determine_user_size(user_size, total)
      user_size ||= total
      user_size > total ? total : user_size
    end

    def calculate_pages_remaining(user_size)
      ((user_size - ITEMS_SIZE_LIMIT).to_f / ITEMS_SIZE_LIMIT).ceil
    end

    def fetch_remaining_pages(uri, params, item_collector, pages_remaining, user_size)
      pages_remaining.times do |page|
        params[:offset] += ITEMS_SIZE_LIMIT
        params[:size] = page == pages_remaining - 1 ? user_size % ITEMS_SIZE_LIMIT : ITEMS_SIZE_LIMIT
        body = request(:get, uri.call(params), nil)
        item_collector += body['items']
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
        Resource.parse request(:put, "#{resource_uri}/#{id}", properties)
      end
    end

    def self.define_child_methods(resource_type, attributes)
      parent_singular = attributes['method_names']['singular']
      parent_plural = attributes['method_names']['plural']
      parent_resource_uri = attributes['url']
      parent_id = attributes['parent_id_key']
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
      @@api_definition_path = File.expand_path(File.join(File.dirname(__FILE__), "../../api.json"))
      @@api_json = JSON.parse(File.read(@@api_definition_path))
      @@api_json.each do |resource_type, attributes|
        define_action_methods(resource_type, attributes) if attributes['actions']
        define_child_methods(resource_type, attributes) if attributes['children']
      end
    end

    # Ack a down collector, pass the ID and a comment
    def ack_collector_down(id, comment)
      if id.class == LMRest::Resource
        Resource.parse request(:post, "/setting/collectors/#{id.id}/ackdown", {comment: comment})
      else
        Resource.parse request(:post, "/setting/collectors/#{id}/ackdown", {comment: comment})
      end
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
