class LMRest
  module SiteMonitorCheckpoints
    BASE_URL = "/service/smcheckpoints"
    include RequestParams

    def get_site_monitor_checkpoints(params = {}, &block)
      get("#{BASE_URL}#{parameterize(params)}", nil, &block)
    end

    def get_site_monitor_checkpoint(id, params = {}, &block)
      get("#{BASE_URL}/#{id}#{parameterize(params)}", nil, &block)
    end
  end
end
