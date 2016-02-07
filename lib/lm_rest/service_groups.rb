class LMRest
  module ServiceGroups
    BASE_URL = "/service/groups"
    include RequestParams

    def get_service_groups(params = {}, &block)
      get("#{BASE_URL}#{parameterize(params)}", nil, &block)
    end

    def get_service_group(id, params = {}, &block)
      get("#{BASE_URL}/#{id}#{parameterize(params)}", nil, &block)
    end

    def add_service_group(properties, &block)
      post(BASE_URL, properties, &block)
    end

    def update_service_group(id, properties, &block)
      post("#{BASE_URL}/#{id}", properties, &block)
    end

    def service_group_sdts(id, params = {}, &block)
      get("#{BASE_URL}/#{id}/sdts#{parameterize(params)}", nil, &block)
    end

    def delete_service_group(id, &block)
      delete("#{BASE_URL}/#{id}", nil, &block)
    end
  end
end
