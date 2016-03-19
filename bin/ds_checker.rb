#!/usr/bin/env ruby
#
#
require 'lm_rest'


def usage
  puts "USAGE:\t" + $0 + " account userid passwd datasource_name_or_glob"
end

if ARGV.length == 4
  @account = ARGV[0]
  @userid  = ARGV[1]
  @passwd  = ARGV[2]
  lm = LMRest.new(*ARGV)
else
  usage
  fail "Bad arguments."
end


datasources = lm.get_datasources(filter: 'name:#{ARGV[3]}')


datasources.each do |datasource|

puts "Summary:"
puts "- datasource name:\t#{datasource.name}"
puts "- display name:\t #{datasource.displayName}"
puts "- applies to:\t\t  #{datasource.appliesTo}"
puts "- polling interval:\t #{datasource.collectInterval/60}m"
puts "- multipoint instance?:\t #{datasource.hasMultiInstances}"
puts "- datapoints:\t\t #{datasource.dataPoints.count}"
puts "- graphs:\t\t #{lm.get_graphs(datasource.id).count}"
puts "- overview graphs:\t\t #{lm.get_overview_graphs(datasource.id).count}"
end
