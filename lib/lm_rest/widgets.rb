class LMRest
  module Widgets 
    BASE_URL = '/dashboard/widgets'
    include RequestParams

    def get_widgets(params = {}, &block)
      get("#{BASE_URL}#{parameterize(params)}", nil, &block)
    end

    def get_widget(id, params = {}, &block)
      get("#{BASE_URL}/#{id}#{parameterize(params)}", nil, &block)
    end

    def add_widget(properties, &block)
      post(BASE_URL, properties, &block)
    end

    def update_widget(id, properties, &block)
      put("#{BASE_URL}/#{id}", properties, &block)
    end

    def delete_widget(id, &block)
      delete("#{BASE_URL}/#{id}", nil, &block)
    end
  end
end
