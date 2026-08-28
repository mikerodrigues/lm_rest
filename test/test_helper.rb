$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
begin
  require 'lm_rest'
rescue LoadError => e
  raise unless e.message.include?('rest-client')

  module RestClient; end
  $LOADED_FEATURES << 'rest-client.rb'
  retry
end

require 'minitest/autorun'
