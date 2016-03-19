class LMRest
  module OIDs 
    BASE_URL = "/setting/oids"
    include RequestParams

    def get_oids(params = {}, &block)
      get("#{BASE_URL}#{parameterize(params)}", nil, &block)
    end

    def get_oid(id, params = {}, &block)
      get("#{BASE_URL}/#{id}#{parameterize(params)}", nil, &block)
    end

    def add_oid(properties, &block)
      post(BASE_URL, properties, &block)
    end

    def update_oid(id, properties, &block)
      put("#{BASE_URL}/#{id}", properties, &block)
    end

    def delete_oid(id, &block)
      delete("#{BASE_URL}/#{id}", nil, &block)
    end
  end
end
