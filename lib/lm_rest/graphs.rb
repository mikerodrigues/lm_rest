class LMRest
  module Graphs
    BASE_URL = '/setting/datasources'
    include RequestParams

    def get_graphs(id, params = {}, &block)
      get("#{BASE_URL}/#{id}/graphs#{parameterize(params)}", nil, &block)
    end

    def add_graph(properties, &block)
      post("#{BASE_URL}/#{id}/graphs", properties, &block)
    end

    def update_graph(id, properties, &block)
      put("#{BASE_URL}/#{id}/graphs", properties, &block)
    end

    def delete_graph(id, &block)
      delete("#{BASE_URL}/#{id}/graphs", nil, &block)
    end
  end
end
