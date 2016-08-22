require 'json'
require 'unirest'
require 'lm_rest/resource'
require 'lm_rest/request_params'

class LMRest
  module APIClient
    include RequestParams

    ITEMS_SIZE_LIMIT = 300
    ITEMS_SIZE_DEFAULT = 50

    BASE_URL_PREFIX = 'https://'
    BASE_URL_SUFFIX = '.logicmonitor.com/santaba/rest'

    @@api_definition_path = File.expand_path(File.join(File.dirname(__FILE__), "../../api.json"))
    @@api_json = JSON.parse(File.read(@@api_definition_path))

    def request(method, uri, json = nil)
      params = json.to_json if json
      headers = {
        'Content-Type' => 'application/json'
      }

      if method == :get
        response = Unirest.get(@api_url + uri, auth: credentials, headers: headers)
      elsif method == :post
        response = Unirest.post(@api_url + uri, auth: credentials, headers: headers, parameters: params)
      elsif method == :put
        response = Unirest.put(@api_url + uri, auth: credentials, headers: headers, parameters: params)
      elsif method == :delete
        response = Unirest.delete(@api_url + uri, auth: credentials, headers: headers, parameters: params)
      end

      if response.body.is_a? String
        raise response
      end

      if response.body['status'] != 200
        raise response.body['status'].to_s + ":" + response.body['errmsg']
      end

      response.body

      #    response = Resource.parse(r.body)
      #    yield response if block_given?
      #    response
    end

    def paginate(uri, params)
      # Hooray for pagination logic!
      if (params[:size] == 0 || params[:size].nil? || params[:size] > ITEMS_SIZE_LIMIT)
        user_size = params[:size]
        params[:size] = ITEMS_SIZE_LIMIT
        params[:offset] ||= 0

        body = request(:get, uri.call(params), nil)

        item_collector = body['data']['items']

        total = body['data']['total']

        user_size ||= total

        if user_size > total
          user_size = total
        end

        # TODO: if pages_remainging == 0, yield to the block
        pages_remaining = ((user_size - ITEMS_SIZE_LIMIT).to_f/ITEMS_SIZE_LIMIT).ceil

        pages_remaining.times do |page|
          params[:offset] += ITEMS_SIZE_LIMIT

          if page == pages_remaining - 1
            params[:size]  = user_size%ITEMS_SIZE_LIMIT
          else
            params[:size] += ITEMS_SIZE_LIMIT
          end

          body = request(:get, uri.call(params), nil)

          item_collector += body['data']['items']
        end

        body['data']['items'] = item_collector
        body
      else
        request(:get, uri.call(params), nil)
      end
    end

    def self.define_action_methods(resource_type, attributes)
      singular = attributes['method_names']['singular']
      plural = attributes['method_names']['plural']
      resource_url = attributes['url']

      attributes['actions'].each do |action|
        case action
        when 'get'

          uri = lambda { |params| "#{resource_url}/#{RequestParams.parameterize(params)}"}

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
                Resource.parse request(:get, "#{resource_url}", nil)
              when 1
                Resource.parse request(:get, "#{resource_url}/#{args[0]}", nil)
              when 2
                Resource.parse request(:get, "#{resource_url}/#{args[0]}#{RequestParams.parameterize(args[1])}", nil)
              else
                raise ArgumentError.new("wrong number for arguments (#{args.count} for 0..2)")
              end
            end
          end

        when 'add'

          # Define a method to add a new resource to the account
          define_method("add_#{singular}") do |properties|
            if properties.class == LMRest::Resource
              Resource.parse request(:post, "#{resource_url}", properties.to_h)
            else
              Resource.parse request(:post, "#{resource_url}", properties)
            end
          end

        when 'update'

          # Define a method to update a resource
          define_method("update_#{singular}") do |id, properties = {}|
            if id.class == LMRest::Resource
              id = id.id
              Resource.parse request(:put, "#{resource_url}/#{id}", id.to_h)
          else
            Resource.parse request(:put, "#{resource_url}/#{id}", properties)
          end
          end

        when 'delete'

          # Define a method to delete the resource
          define_method("delete_#{singular}") do |id|
            if id.class == LMRest::Resource
              id = id.id
              Resource.parse request(:delete, "#{resource_url}/#{id}", nil)
            else
              Resource.parse delete(:delete, "#{resource_url}/#{id}", nil)
            end
          end
        end
      end
    end

    def self.define_child_methods(resource_type, attributes)
      parent_singular = attributes['method_names']['singular']
      parent_plural = attributes['method_names']['plural']
      parent_resource_url = attributes['url']
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
        child_resource_url = attributes['url'].split("/").last

        child['actions'].each do |action|
          case action
          when 'get'

            define_method("get_#{parent_singular}_#{child_plural}") do |id, params = {}, &block|
            uri = lambda { |params| "#{parent_resource_url}/#{id}/#{child['method_names']['plural']}#{RequestParams.parameterize(params)}" }
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
      @@api_json.each do |resource_type, attributes|
        define_action_methods(resource_type, attributes) if attributes['actions']
        define_child_methods(resource_type, attributes) if attributes['children']
      end
    end

    def ack_collector_down(id)
      Resource.parse request(:post, "/setting/collectors/#{id}/ackdown", nil)
    end
  end
end
