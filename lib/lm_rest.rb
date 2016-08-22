require 'lm_rest/version'
require 'lm_rest/api_client'

class LMRest
  include APIClient

  attr_reader :accountname, :username, :api_url

  def initialize(accountname, username, password)
    APIClient.setup
    @accountname = accountname
    @username    = username
    @password    = password
    @api_url     = BASE_URL_PREFIX + accountname + BASE_URL_SUFFIX
    @credentials = { user: username, password: password }
  end

  private

  attr_accessor :credentials
end
