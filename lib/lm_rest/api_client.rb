require 'json'
require 'date'
require 'base64'
require 'openssl'
require 'unirest'
require 'lm_rest/resource'
require 'lm_rest/request_params'

module LMRest
  class APIClient
    include RequestParams

    ITEMS_SIZE_LIMIT = 1000
    ITEMS_SIZE_DEFAULT = 50

    BASE_URL_PREFIX = 'https://'
    BASE_URL_SUFFIX = '.logicmonitor.com/santaba/rest'

    attr_reader :company, :user, :api_url

    def initialize(company:, user: nil, password: nil, access_id: nil, access_key: nil)
      APIClient.setup
      @company = company

      if (user && password)
        @credentials = { user: user, password: password }
      elsif (access_id && access_key)
        @api_token = {access_id: access_id, access_key: access_key}
      end

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
          api_token[:access_key],
          message
        )
      )

      "LMv1 #{api_token[:access_id]}:#{signature}:#{time}"
    end

    def request(method, uri, params={})
      if api_token.nil?
        headers = {
          'Content-Type' => 'application/json',
        }
      else
        headers = {}
        headers['Authorization'] = sign(method, uri, params)
        headers['Content-Type'] = 'application/json'
        headers['Accept'] = 'application/json'
      end

      url = api_url + uri
      #puts "URL: " + url

      json_params = params.to_json

      case method
      when :get
        response = Unirest.get(url, auth: credentials, headers: headers)
      when :post
        response = Unirest.post(url, auth: credentials, headers: headers, parameters: json_params)
      when :put
        response = Unirest.put(url, auth: credentials, headers: headers, parameters: json_params)
      when :delete
        response = Unirest.delete(url, auth: credentials, headers: headers)
      end

      if response.code != 200
        puts response.code.to_s + ":" + response.body
        raise
      end

      if response.body.is_a? String
        puts response.body
        # raise
      end

      response.body
    end

    # Handles making multiple requests to the API if pagination is necessary.
    # Pagination is transparent, and simplifies requests that result in more
    # than ITEMS_SIZE_LIMIT being returned.
    #
    # If you need to walk through resources page-by-page manullay, use the
    # request() method with the 'offset' and 'size' params
    #
    def paginate(uri, params)

      # Hooray for pagination logic!
      if (params[:size] == 0 || params[:size].nil? || params[:size] > ITEMS_SIZE_LIMIT)
        # save user-entered size in a param for use later
        user_size = params[:size]

        # set our size param to the max
        params[:size] = ITEMS_SIZE_LIMIT

        # Set our offset to grab the first page of results 
        params[:offset] ||= 0

        # make the initial request
        body = request(:get, uri.call(params), nil)

        # pull the actual items out of the request body and into our
        # item_collector while we build up the items list
        item_collector = body['data']['items']

        # The API sends the total number of objects back in the first request.
        # We need this to determine how many more pages to pull
        total = body['data']['total']

        # If user didn't pass size param, set it to total
        # This just means you'll get all items if not specifying a size
        user_size ||= total

        # If the user passed a size larger than what's available, set it to
        # total to retrieve all items
        if user_size > total
          user_size = total
        end
        
        # calculate the remaining number of items (after first request)
        # then use that to figure out how many more times we need to call
        # request() to get all the items, then do it
        pages_remaining = ((user_size - ITEMS_SIZE_LIMIT).to_f/ITEMS_SIZE_LIMIT).ceil

        pages_remaining.times do |page|

          # Increment the offset by the limit to get the next page
          params[:offset] += ITEMS_SIZE_LIMIT
          
          # if this is the last page, get the remainder
          if page == pages_remaining - 1
            params[:size]  = user_size%ITEMS_SIZE_LIMIT
          else
            # else, get a whole page
            params[:size] = ITEMS_SIZE_LIMIT
          end

          # make a subsequent request with modified params
          body = request(:get, uri.call(params), nil)

          # add these items to our item_collector
          item_collector += body['data']['items']
        end

        body['data']['items'] = item_collector
        body
      else
        # No pagination required, just request the page
        request(:get, uri.call(params), nil)
      end
    end

    def self.define_action_methods(resource_type, attributes)
      singular = attributes['method_names']['singular']
      plural = attributes['method_names']['plural']
      resource_uri = attributes['url']

      attributes['actions'].each do |action|
        case action
        when 'get'

          uri = lambda { |params| "#{resource_uri}#{RequestParams.parameterize(params)}"}

          unless plural.nil?
            # Define a method to fetch multiple resources with optional params
            define_method("get_#{plural}") do |params = {}|
              Resource.parse paginate(uri, params)
            end
          end

          # Define a method to get one resource by it's id number, with optional
          # params, thought now that I think about it I'm not sure why you'd pass
          # params when grabbing just one resource.

          # Some resources are Singletons
          unless singular.nil?
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

        when 'add'

          # Define a method to add a new resource to the account
          define_method("add_#{singular}") do |properties|
            if properties.class == LMRest::Resource
              Resource.parse request(:post, "#{resource_uri}", properties.to_h)
            else
              Resource.parse request(:post, "#{resource_uri}", properties)
            end
          end

        when 'update'

          # Define a method to update a resource
          define_method("update_#{singular}") do |id, properties = {}|
            if id.class == LMRest::Resource
              Resource.parse request(:put, "#{resource_uri}/#{id.id}", id.to_h)
          else
            Resource.parse request(:put, "#{resource_uri}/#{id}", properties)
          end
          end

        when 'delete'

          # Define a method to delete the resource
          define_method("delete_#{singular}") do |id|
            if id.class == LMRest::Resource
              id = id.id
              Resource.parse request(:delete, "#{resource_uri}/#{id}", nil)
            else
              Resource.parse request(:delete, "#{resource_uri}/#{id}", nil)
            end
          end
        end
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
          when 'update'
          when 'delete'
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

    private

    attr_accessor :credentials
    attr_accessor :api_token
  end
end
