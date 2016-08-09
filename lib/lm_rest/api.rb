require 'json'
require 'singleton'

class LMRest
  class API
    include Singleton

    attr_accessor :api_json

    def initialize(api_json_path)
      api_json_full_path = File.expand_path(File.join(File.dirname(__FILE__), api_json_path))
      @api_json = JSON.parse(File.read(api_json_full_path))
    end
  end
end
