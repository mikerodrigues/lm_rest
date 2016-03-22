class LMRest
  module OverviewGraphs
    BASE_URL = '/setting/datasources'
    include RequestParams

    def get_overview_graphs(id, params = {}, &block)
      get("#{BASE_URL}/#{id}/ographs#{parameterize(params)}", nil, &block)
    end

    def add_overview_graph(properties, &block)
      post("#{BASE_URL}/#{id}/ographs", properties, &block)
    end

    def update_overview_graph(id, properties, &block)
      put("#{BASE_URL}/#{id}/ographs", properties, &block)
    end

    def delete_overview_graph(id, &block)
      delete("#{BASE_URL}/#{id}/ographs", nil, &block)
    end
  end
end
