#!/usr/bin/env ruby
#
#
# Based on a script written originally by Matt Dunham
#
require 'lm_rest'

def usage
  puts "USAGE:\t" + $PROGRAM_NAME + ' account id key applies_to category'
  puts ""
  puts "\taccount    - just the beginning of your portal name, like 'hooli'"
  puts "\tid         - API key access id"
  puts "\tkey        - API key access key"
  puts "\tapplies_to - AppliesTo (in quotes on one line) matching devices you want to scrub"
  puts "\tcategory   - The system category value you wish to remove."
end

if ARGV.length ==5 
  @account = ARGV[0]
  @id  = ARGV[1]
  @key  = ARGV[2]
  @at = ARGV[3]
  @category = ARGV[4]
  @lm = LMRest::APIClient.new(@account, @id, @key)
else
  usage
  fail 'Bad arguments.'
end

request = {
  currentAppliesTo: @at,
  needInheritProps: true,
  originalAppliesTo: @at,
  type: "testAppliesTo"
}

devices = @lm.request(:post, "/functions", request)['originalMatches'].map do |device|
  [device['id'], device['name']]
end

devices.each do |id, name|
  puts "Fetching device id #{id}, #{name}"
  current = @lm.request(:get, "/device/devices/#{id}/properties/system.categories", nil)
  if (@lm.remaining.to_f / @lm.limit.to_f) * 100 <= 10
    puts "sleeping for #{@lm.window} to avoid rate limit violation"
    sleep @lm.window
  end
  if current['value'].split(',').include? @category
    new_string = current['value'].split(',') - [@category]
    new = current
    new['value'] = new_string.join(",")
    @lm.request(:put, "/device/devices/#{id}/properties/system.categories", new)
    puts "  Successfully scrubbed!"
  else
    puts "  No scrubbing needed."
  end
end
