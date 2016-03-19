class LMRest
  module Functions 
    BASE_URL = "/setting/functions"
    include RequestParams

    def get_functions(params = {}, &block)
      get("#{BASE_URL}#{parameterize(params)}", nil, &block)
    end

    def get_function(id, params = {}, &block)
      get("#{BASE_URL}/#{id}#{parameterize(params)}", nil, &block)
    end

    def add_function(properties, &block)
      post(BASE_URL, properties, &block)
    end

    def update_function(id, properties, &block)
      put("#{BASE_URL}/#{id}", properties, &block)
    end

    def delete_function(id, &block)
      delete("#{BASE_URL}/#{id}", nil, &block)
    end
  end
end
