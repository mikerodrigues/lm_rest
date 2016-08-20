require 'lm_rest/version'
require 'unirest'
require 'json'

require 'lm_rest/request_params'
require 'lm_rest/api_client'
require 'lm_rest/resource'

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

  def request(method, uri, json = nil)
    params = json.to_json if json
    headers = {
      'Content-Type' => 'application/json'
    }

    if method == :get
      response = Unirest.get(@api_url + uri, auth: credentials, headers: headers)
    elsif method == :post
      response = Unirest.post(@api_url + uri, auth: credentials, headers: headers, parameters: params)
    elsif method == :put
      response = Unirest.put(@api_url + uri, auth: credentials, headers: headers, parameters: params)
    elsif method == :delete
      response = Unirest.delete(@api_url + uri, auth: credentials, headers: headers, parameters: params)
    end

    if response.body.is_a? String
      raise response
    end

    if response.body['status'] != 200
      raise response.body['status'].to_s + ":" + response.body['errmsg']
    end

    response.body

    #    response = Resource.parse(r.body)
    #    yield response if block_given?
    #    response
  end

  private

  attr_accessor :credentials
end
