require 'lm_rest/version'
require 'unirest'
require 'json'

# API Resource Objects
require 'lm_rest/resource'
require 'lm_rest/resources/batchjob'
require 'lm_rest/resources/datasource'
require 'lm_rest/resources/datapoint'
require 'lm_rest/resources/eventsource'
require 'lm_rest/resources/function'
require 'lm_rest/resources/graph'
require 'lm_rest/resources/overview_graph'
require 'lm_rest/resources/oid'
require 'lm_rest/resources/service'
require 'lm_rest/resources/service_group'
require 'lm_rest/resources/sdt'
require 'lm_rest/resources/access_log_entry'
require 'lm_rest/resources/site_monitor_checkpoint'
require 'lm_rest/resources/widget'

require 'lm_rest/request_params'
require 'lm_rest/api_client'

class LMRest
  include APIClient

  BASE_URL_PREFIX = 'https://'
  BASE_URL_SUFFIX = '.logicmonitor.com/santaba/rest/'

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
      r = Unirest.get(@api_url + uri, auth: credentials, headers: headers)
    elsif method == :post
      r = Unirest.post(@api_url + uri, auth: credentials, headers: headers, parameters: params)
    elsif method == :put
      r = Unirest.put(@api_url + uri, auth: credentials, headers: headers, parameters: params)
    elsif method == :delete
      r = Unirest.delete(@api_url + uri, auth: credentials, headers: headers, parameters: params)
    end

    # yield r.body if block_given?
    # r.body
    #

    response = Resource.parse(uri, r.body)
    yield response if block_given?
    response
  end

  def get(uri, json = nil, &block)
    request(:get, uri, json, &block)
  end

  def post(uri, json = nil, &block)
    request(:post, uri, json, &block)
  end

  def put(uri, json = nil, &block)
    request(:put, uri, json, &block)
  end

  def delete(uri, json = nil, &block)
    request(:delete, uri, json, &block)
  end

  private

  attr_accessor :credentials
end
