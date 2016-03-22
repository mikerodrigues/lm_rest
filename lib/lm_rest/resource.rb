class LMRest
  class Resource
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
      def create(type, properties)
        type.new(properties)
      end

      def parse(uri, response)
        if response.is_a? String
          warn response
          return
        end
        begin
          type = get_type uri
          if response['data'].key? 'items'
            parse_collection(type, response['data']['items'])
          else
            parse_object(type, response['data'])
          end

        rescue => e
          puts e
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
        when /batchjobs/
          Batchjob
        when /eventsource/
          Eventsource
        when /function/
          Function
        when /ographs/
          OverviewGraph
        when /graphs/
          Graph
        when /datapoints/
          Datapoint
        when /datasources/
          Datasource
        when /oid/
          OID
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
          fail "Did not recognize the response type associated with this uri: #{uri}"
        end
      end
    end
  end
end
