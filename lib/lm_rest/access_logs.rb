class LMRest
  module AccessLogs
    BASE_URL = "/setting/accesslogs"
    include RequestParams

    def get_access_logs(params = {}, &block)
      get("#{BASE_URL}#{parameterize(params)}", nil, &block)
    end

    def get_access_log(id, params = {}, &block)
      get("#{BASE_URL}/#{id}#{parameterize(params)}", nil, &block)
    end
  end
end
