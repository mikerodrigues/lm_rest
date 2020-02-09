module LMRest
  class Resource

    def initialize(properties)
      properties.each do |key, value|
        instance_variable_set(:"@#{key}", value)
        define_singleton_method(key.intern) { instance_variable_get("@#{key}") }
        define_singleton_method("#{key}=".intern) do |new_value|
          instance_variable_set("@#{key}", new_value)
        end
      end
    end

    def to_h
      instance_variables.map do |var|
        [var[1..-1].to_s, instance_variable_get(var)]
      end.to_h
    end

    class << self

      def parse(body)
        begin
          if body.key? 'items'
            parse_collection(body['items'])
          else
            parse_object(body)
          end

        rescue => e
          puts e
          puts "Response body: " + body
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
