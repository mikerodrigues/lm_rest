class LMRest
  module Datasources 
    BASE_URL = "/setting/datasources"
    include RequestParams

    def get_datasources(params = {}, &block)
      get("#{BASE_URL}#{parameterize(params)}", nil, &block)
    end

    def get_datasource(id, params = {}, &block)
      get("#{BASE_URL}/#{id}#{parameterize(params)}", nil, &block)
    end

    def add_datasource(properties, &block)
      post(BASE_URL, properties, &block)
    end

    def update_datasource(id, properties, &block)
      post("#{BASE_URL}/#{id}", properties, &block)
    end

    def delete_datasource(id, &block)
      delete("#{BASE_URL}/#{id}", nil, &block)
    end
  end
end
