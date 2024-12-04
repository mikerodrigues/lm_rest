#!/usr/bin/env ruby
#
#
#
=begin require 'lm_rest'

def usage
  puts "USAGE:\t" + $PROGRAM_NAME + ' account userid passwd'
end

if ARGV.length == 3
  @account = ARGV[0]
  @userid  = ARGV[1]
  @passwd  = ARGV[2]
  @lm = LMRest.new(@account, @userid, @passwd)
else
  usage
  fail 'Bad arguments.'
end


@datasources = @lm.get_datasources(filter: "name:#{ARGV[3]}")

@datasources.each do |datasource|
  errors = []
  datapoints = @lm.get_datapoints(datasource.id)
  complex_datapoints = datapoints.select { |dp| dp.postProcessorMethod == 'expression' }
  graphs = @lm.get_graphs(datasource.id)
  overview_graphs = @lm.get_overview_graphs(datasource.id)

  summarize(datasource, datapoints, graphs, overview_graphs)
  errors << test_datasource_name(datasource)
  errors << test_datapoint_descriptions(datapoints)
  errors << test_datapoint_alerts(datapoints)
  errors << test_datapoint_usage(datapoints, complex_datapoints, graphs, overview_graphs)
  errors << test_graphs(graphs)
  errors << test_overview_graphs(overview_graphs)
  propose_fixes(errors)

  separator
end =end
