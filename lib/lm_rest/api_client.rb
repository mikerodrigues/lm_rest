require 'json'
require 'lm_rest/request_params'

class LMRest
  module APIClient
    include RequestParams

    def APIClient.define_action_method(category, object, action)
      case action
      when 'get'

        # Define a method to fetch all objects
        define_method("get_#{object}") do | params = {}, &block |
          get("#{category}/#{object}#{parameterize(params)}", nil, &block)
        end

        # Define a method to get once object by it's ID
        define_method("get_#{singularize(object)}") do | id, params = {}, &block |
          get("#{category}/#{object}/#{id}#{parameterize(params)}", nil, &block)
        end

      when 'add'

        # Define a method to add the object
        define_method("add_#{singularize(object)}") do | properties, &block |
          post("#{category}/#{object}", properties, &block)
        end

      when 'update'

        # Define a method to update the object
        define_method("update_#{singularize(object)}") do | id, properties, &block |
          get("#{category}/#{object}/#{id}", properties, &block)
        end

      when 'delete'

        # Define a method to delete the object
        define_method("delete_#{singularize(object)}") do | id, &block |
          get("#{category}/#{object}/#{id}", nil, &block)
        end
      end
    end

    def APIClient.singularize(string)
      case string
      when /.*s$/
        string.match(/(.*)s$/)[1]
      end
    end
  end

  # Define methods based on the JSON structure
  def APIClient.setup
    api_definition_path = File.expand_path(File.join(File.dirname(__FILE__), "../../api.json"))
    api_json = JSON.parse(File.read(api_definition_path))

    api_json['api']['categories'].each do |category, objects|
      objects.each do |object, attributes|
        if attributes.keys.include? "actions"
          attributes['actions'].each do |action|
            self.define_action_method(category, object, action)
          end
        end
      end
    end
  end
end
