class LMRest
  module Batchjobs 
    BASE_URL = "/setting/batchjobs"
    include RequestParams

    def get_batchjobs(params = {}, &block)
      get("#{BASE_URL}#{parameterize(params)}", nil, &block)
    end

    def get_batchjob(id, params = {}, &block)
      get("#{BASE_URL}/#{id}#{parameterize(params)}", nil, &block)
    end

    def add_batchjob(properties, &block)
      post(BASE_URL, properties, &block)
    end

    def update_batchjob(id, properties, &block)
      put("#{BASE_URL}/#{id}", properties, &block)
    end

    def delete_batchjob(id, &block)
      delete("#{BASE_URL}/#{id}", nil, &block)
    end
  end
end
