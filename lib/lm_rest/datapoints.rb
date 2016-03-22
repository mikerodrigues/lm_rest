class LMRest
  module Datapoints
    BASE_URL = '/setting/datasources'
    include RequestParams

    def get_datapoints(id, params = {}, &block)
      get("#{BASE_URL}/#{id}/datapoints#{parameterize(params)}", nil, &block)
    end

    def add_datapoint(properties, &block)
      post("#{BASE_URL}/#{id}/datapoints", properties, &block)
    end

    def update_datapoint(id, properties, &block)
      put("#{BASE_URL}/#{id}/datapoints", properties, &block)
    end

    def delete_datapoint(id, &block)
      delete("#{BASE_URL}/#{id}/datapoints", nil, &block)
    end
  end
end
