require 'json'
require 'lm_rest/request_params'

class LMRest
  module APIClient
    include RequestParams

    ITEMS_SIZE_LIMIT = 300
    ITEMS_SIZE_DEFAULT = 50

    BASE_URL_PREFIX = 'https://'
    BASE_URL_SUFFIX = '.logicmonitor.com/santaba/rest/'


    @@api_definition_path = File.expand_path(File.join(File.dirname(__FILE__), "../../api.json"))
    @@api_json = JSON.parse(File.read(@@api_definition_path))

    def self.define_action_method(category, object, method_names, action)
      case action
      when 'get'

        # Define a method to fetch all objects
        define_method("get_#{method_names[1]}") do | params = {}, &block |
          # consider converting params's string keys to symbols for flexibility

          # Hooray for pagination logic!
          if (params[:size] == 0 || params[:size].nil? || params[:size] > ITEMS_SIZE_LIMIT)
            user_size = params[:size]

            params[:size] = ITEMS_SIZE_LIMIT
            params[:offset] ||= 0

            body = request(:get, "#{category}/#{object}#{parameterize(params)}", nil, &block)

            item_collector = body['data']['items']

            total = body['data']['total']

            user_size ||= total

            if user_size > total
              user_size = total
            end

            pages_remaining = ((user_size - ITEMS_SIZE_LIMIT).to_f/ITEMS_SIZE_LIMIT).ceil

            pages_remaining.times do |page|
              params[:offset] += ITEMS_SIZE_LIMIT

              if page == pages_remaining - 1
                params[:size]  = user_size%ITEMS_SIZE_LIMIT
              else
                params[:size] += ITEMS_SIZE_LIMIT
              end

              body = request(:get, "#{category}/#{object}#{parameterize(params)}", nil, &block)

              item_collector += body['data']['items']
            end

            body['data']['items'] = item_collector

            Resource.parse(body)
        else
          Resource.parse request(:get, "#{category}/#{object}#{parameterize(params)}", nil, &block)
        end
        end

        # Define a method to get one object by it's ID
        define_method("get_#{method_names[0]}") do | id, params = {}, &block |
          Resource.parse request(:get, "#{category}/#{object}/#{id}#{parameterize(params)}", nil, &block)
        end

      when 'add'

        # Define a method to add the object
        define_method("add_#{method_names[0]}") do | properties, &block |
          if properties.class == LMRest::Resource
            Resource.parse request(:post, "#{category}/#{object}", properties.to_h, &block)
          else
            Resource.parse request(:post, "#{category}/#{object}", properties, &block)
          end
        end

      when 'update'

        # Define a method to update the object
        define_method("update_#{method_names[0]}") do | id, properties = {}, &block |
          if id.class == LMRest::Resource
            Resource.parse request(:put, "#{category}/#{object}/#{(id.id)}", id.to_h, &block)
        else
          Resource.parse request(:put, "#{category}/#{object}/#{id}", properties, &block)
        end
        end

      when 'delete'

        # Define a method to delete the object
        define_method("delete_#{method_names[0]}") do | id, &block |
          if id.class == LMRest::Resource
            Resource.parse request(:delete, "#{category}/#{object}/#{id.id}", nil, &block)
          else
            Resource.parse delete(:delete, "#{category}/#{object}/#{id}", nil, &block)
          end
        end
      end
    end

    # Define methods based on the JSON structure
    def self.setup
      @@api_json['api']['categories'].each do |category, objects|
        objects.each do |object, attributes|
          if attributes.keys.include? "method_names"
            if attributes.keys.include? "actions"
              method_names = attributes['method_names']

              attributes['actions'].each do |action|
                self.define_action_method(category, object, method_names, action)
              end
            end
          end
        end
      end
    end
  end
end
