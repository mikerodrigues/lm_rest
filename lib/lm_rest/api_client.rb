require 'json'
require 'lm_rest/request_params'

class LMRest
  module APIClient
    include RequestParams
    @@api_definition_path = File.expand_path(File.join(File.dirname(__FILE__), "../../api.json"))
    @@api_json = JSON.parse(File.read(@@api_definition_path))

    def self.define_action_method(category, object, method_names, action)
      case action
      when 'get'

        # Define a method to fetch all objects
        define_method("get_#{method_names[1]}") do | params = {}, &block |
          get("#{category}/#{object}#{parameterize(params)}", nil, &block)
        end

        # Define a method to get one object by it's ID
        define_method("get_#{method_names[0]}") do | id, params = {}, &block |
          get("#{category}/#{object}/#{id}#{parameterize(params)}", nil, &block)
        end

      when 'add'

        # Define a method to add the object
        define_method("add_#{method_names[0]}") do | properties, &block |
          if properties.class == LMRest::Resource
            post("#{category}/#{object}", properties.to_h, &block)
          else
            post("#{category}/#{object}", properties, &block)
          end
        end

      when 'update'

        # Define a method to update the object
        define_method("update_#{method_names[0]}") do | id, properties = {}, &block |
          if id.class == LMRest::Resource
            put("#{category}/#{object}/#{(id.id)}", id.to_h, &block)
        else
          put("#{category}/#{object}/#{id}", properties, &block)
        end
        end

      when 'delete'

        # Define a method to delete the object
        define_method("delete_#{method_names[0]}") do | id, &block |
          if id.class == LMRest::Resource
            delete("#{category}/#{object}/#{id.id}", nil, &block)
          else
            delete("#{category}/#{object}/#{id}", nil, &block)
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

    def self.summary
      @@api_json['api']['categories'].each do |category, objects|
        objects.each do |object, attributes|
          if attributes.keys.include? "method_names"
            puts "Resource: " + attributes['method_names'][0]
            if attributes.keys.include? "actions"
              puts "  Actions: " + attributes['actions'].join(", ")
            end
          end
        end
      end
    end
  end
end
