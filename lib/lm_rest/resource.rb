class LMRest
  class Resource
    def initialize(properties)
      @properties = properties.keys
      properties.each do |key, value|
        instance_variable_set(:"@#{key}", value)
        define_singleton_method(key.intern) { instance_variable_get("@#{key}") }
        define_singleton_method("#{key}=".intern) do |value|
          instance_variable_set("@#{key}", value)
        end
      end
    end

    def to_h
      hash = {}
      @properties.map do |key|
        hash[key] = self.send(key.intern)
      end
      hash
    end

    class << self
      def create(type, properties)
        type.new(properties)
      end

      def parse(uri, response)
        type = get_type uri
        if response["data"].has_key? 'items'
          parse_collection(type, response["data"]["items"])
        else
          parse_object(type, response["data"])
        end
      end

      def parse_collection(type, items)
        items.map do |item|
          create(type, item)
        end
      end

      def parse_object(type, item)
        create(type, item)
      end

      def get_type(uri)
        case uri
        when /services/
          Service
        when /groups/
          ServiceGroup
        when /sdts/
          SDT
        when /accesslogs/
          AccessLogEntry
        when /smcheckpoints/
          SiteMonitorCheckpoint
        else
          raise "Unrecognized resposne type for uri: #{uri}"
        end
      end
    end
  end
end
