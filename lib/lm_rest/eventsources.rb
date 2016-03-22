class LMRest
  module Eventsources
    BASE_URL = '/setting/eventsources'
    include RequestParams

    def get_eventsources(params = {}, &block)
      get("#{BASE_URL}#{parameterize(params)}", nil, &block)
    end

    def get_eventsource(id, params = {}, &block)
      get("#{BASE_URL}/#{id}#{parameterize(params)}", nil, &block)
    end

    def add_eventsource(properties, &block)
      post(BASE_URL, properties, &block)
    end

    def update_eventsource(id, properties, &block)
      put("#{BASE_URL}/#{id}", properties, &block)
    end

    def delete_eventsource(id, &block)
      delete("#{BASE_URL}/#{id}", nil, &block)
    end
  end
end
