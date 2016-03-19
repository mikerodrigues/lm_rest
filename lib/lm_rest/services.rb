class LMRest
  module Services
    BASE_URL = "/service/services"
    include RequestParams

    def get_services(params = {}, &block)
      get("#{BASE_URL}#{parameterize(params)}", nil, &block)
    end

    def get_service(id, params = {}, &block)
      get("#{BASE_URL}/#{id}#{parameterize(params)}", nil, &block)
    end

    def add_service(properties, &block)
      post(BASE_URL, properties, &block)
    end

    def update_service(id, properties, &block)
      put("#{BASE_URL}/#{id}", properties, &block)
    end

    def service_sdts(id, params = {}, &block)
      get("#{BASE_URL}/#{id}/sdts#{parameterize(params)}", nil, &block)
    end

    def delete_service(id, &block)
      delete("#{BASE_URL}/#{id}", nil, &block)
    end
  end
end
