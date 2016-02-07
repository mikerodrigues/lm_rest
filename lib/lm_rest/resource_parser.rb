class LMRest
  module ResourceParser
    def parse(uri, response)
      if response["data"].has_key? 'items'
        type = get_type uri
        parse_collection(type, response["data"]["items"])
      else
        parse_object(type, response["data"])
      end
    end

    def parse_collection(type, items)
      items.each do |item|
        Resource.create(type, item)
      end
    end

    def parse_object(type, item)
      Resource.create(type, item)
    end

    def get_type(uri)
      case uri
      when /services/
        :service
      when /groups/
        :service_group
      when /sdts/
        :sdt
      when /accesslogs/
        :access_log
      when /smcheckpoints/
        :site_monitor_checkpoint
      else
        raise "Unrecognized resposne tyep for uri: #{uri}"
      end
    end
  end
end
