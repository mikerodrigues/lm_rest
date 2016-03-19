class LMRest
  module SDTs 
    BASE_URL = "/sdt/sdts"
    include RequestParams

    def get_sdts(params = {}, &block)
      get("#{BASE_URL}#{parameterize(params)}", nil, &block)
    end

    def get_sdt(id, params = {}, &block)
      get("#{BASE_URL}/#{id}#{parameterize(params)}", nil, &block)
    end

    def add_sdt(properties, &block)
      post(BASE_URL, properties, &block)
    end

    def update_sdt(id, properties, &block)
      put("#{BASE_URL}/#{id}", properties, &block)
    end

    def delete_sdt(id, &block)
      delete("#{BASE_URL}/#{id}", nil, &block)
    end
  end
end
