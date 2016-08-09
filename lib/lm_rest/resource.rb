require 'json'

class LMRest
  class Resource

    begin
      api_definition_path = File.expand_path(File.join(File.dirname(__FILE__), "../../api.json"))
      @@api_json = JSON.parse(File.read(api_definition_path))
    rescue
      puts "could not find the api.json file"
      fail
    end

    def initialize(properties)
      @properties = properties.keys
      properties.each do |key, value|
        instance_variable_set(:"@#{key}", value)
        define_singleton_method(key.intern) { instance_variable_get("@#{key}") }
        define_singleton_method("#{key}=".intern) do |new_value|
          instance_variable_set("@#{key}", new_value)
        end
      end
    end

    def to_h
      hash = {}
      @properties.map do |key|
        hash[key] = send(key.intern)
      end

      hash
    end

    class << self

      def parse(uri, response)
        if response.is_a? String
          warn response
          return
        end
        
        if response['status'] != 200
          warn response['errmsg']
          return
        end

        begin
          if response['data'].key? 'items'
            parse_collection(response['data']['items'])
          else
            parse_object(response['data'])
          end

        rescue => e
          puts e
        end
      end

      def parse_collection(items)
        items.map do |item|
          new(item)
        end
      end

      def parse_object(item)
        new(item)
      end
    end
  end
end
