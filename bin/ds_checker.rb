#!/usr/bin/env ruby
#
#
# Based on a script written originally by Matt Dunham
#
require 'lm_rest'
require 'colorize'

def usage
  puts "USAGE:\t" + $PROGRAM_NAME + ' account userid passwd datasource_name_or_glob'
end

if ARGV.length == 4
  @account = ARGV[0]
  @userid  = ARGV[1]
  @passwd  = ARGV[2]
  @lm = LMRest.new(@account, @userid, @passwd)
else
  usage
  fail 'Bad arguments.'
end

def dp_type(datapoint)
  datapoint.postProcessorMethod == 'expression' ? 'complex' : 'normal'
end

def test_datasource_name(datasource)
  errors = []

  # does the name contain whitespace?
  errors.push('datasource name contains whitespace') if datasource.name =~ /\s+/

  # does the name end in a trailing dash?
  errors.push('datasource name has trailing dash') if datasource.name =~ /\-$/

  # does the display name end in a trailing dash?
  if datasource.displayName =~ /\-$/
    errors.push('datasource display name has trailing dash')
  end

  errors
end

def test_datasource_description(datasource)
  error = nil

  # is the description size less than 10 characters in length?
  if datasource.description.length < 10
    error = 'datasource description is empty or sparse'
  end

  error
end

def test_datapoint_descriptions(datapoints)
  errors = []

  datapoints.each do |datapoint|
    if datapoint.description.length < 10
      errors.push("datapoint \"" + datapoint.name + "\" description is empty or sparse")
    end
  end

  errors
end

def test_datapoint_alerts(datapoints)
  errors = []

  tokens = [
    '##HOST##',
    '##VALUE##',
    '##DURATION##',
    '##START##'
  ]

  datapoints.each do |datapoint|
    check_alert_threshold(datapoint, errors)
    check_custom_alert_message(datapoint, tokens, errors)
  end

  errors
end

def check_alert_threshold(datapoint, errors)
  if datapoint.alertExpr.size > 0 && datapoint.alertBody == 0
    errors.push("datapoint \"#{datapoint.name}\" has an alert threshold but no message")
  end
end

def check_custom_alert_message(datapoint, tokens, errors)
  return unless datapoint.alertBody.size > 0

  tokens.each do |token|
    unless datapoint.alertBody.include? token
      errors.push("custom alert message on \"#{datapoint.name}\" datapoint doesn't include token #{token}")
    end
  end
end

def test_datapoint_usage(datapoints, complex_datapoints, graphs, overview_graphs)
  errors = []
  datapoint_ok = []

  puts 'Datapoints:'
  datapoints.each do |datapoint|
    if datapoint.alertExpr.size > 0
      puts " - #{dp_type(datapoint)} datapoint \"#{datapoint.name}\" has alert threshold set"
    else
      check_complex_datapoints(datapoint, complex_datapoints, datapoint_ok)
      check_graphs(datapoint, graphs, datapoint_ok, 'graph')
      check_graphs(datapoint, overview_graphs, datapoint_ok, 'overview graph')
    end
  end

  errors
end

def check_complex_datapoints(datapoint, complex_datapoints, datapoint_ok)
  complex_datapoints.each do |complex_datapoint|
    if complex_datapoint.postProcessorParam.include? datapoint.name
      puts " - #{dp_type(datapoint)} datapoint \"#{datapoint.name}\" used in complex datapoint #{complex_datapoint.name}"
      datapoint_ok.push(datapoint.name)
      break
    end
  end
end

def check_graphs(datapoint, graphs, datapoint_ok, graph_type)
  graphs.each do |graph|
    graph.dataPoints.each do |graph_datapoint|
      if datapoint.name == graph_datapoint['name']
        puts " - #{dp_type(datapoint)} datapoint \"#{datapoint.name}\" used in #{graph_type} \"#{graph.name}\" datapoint"
        datapoint_ok.push(datapoint.name)
        break
      end
    end
  end
end

def test_graphs(graphs)
  errors = []

  puts 'Graphs:'
  errors.concat(check_graphs(graphs, 'graph'))

  separator
  errors
end

def test_overview_graphs(overview_graphs)
  errors = []

  puts 'Overview Graphs:'
  errors.concat(check_graphs(overview_graphs, 'overview graph'))

  separator
  errors
end

def check_datapoints(datapoints, used_datapoints)
  datapoint_ok = []
  errors = []

  datapoints.each do |datapoint|
    used_datapoints.each do |used|
      if used.include? datapoint.name
        datapoint_ok.push(datapoint.name)
        break
      end
    end

    unless datapoint_ok.include? datapoint.name
      errors.push("datapoint \"#{datapoint.name}\" appears to be unused")
    end
  end

  separator
  errors
end

def check_graphs(graphs, graph_type)
  errors = []
  display_prios = {}

  graphs.each do |graph|
    puts " - \"#{graph.name}\" at display priority #{graph.displayPrio}"
    if graph.verticalLabel.match(/[A-Z]/)
      errors.push("#{graph_type} \"#{graph.name}\" has uppercase letters in the y-axis definition (#{graph.verticalLabel})")
    end

    if display_prios.include? graph.displayPrio
      errors.push("#{graph_type} \"#{graph.name}\" is assigned the same display priority (#{graph.displayPrio}) as \"#{display_prios[graph.displayPrio]}\"")
    else
      display_prios[graph.displayPrio] = graph.name
    end
  end

  errors
end

def summarize(datasource, datapoints, graphs, overview_graphs)
  datapoint_alert_count = 0
  datapoints.each do |datapoint|
    datapoint_alert_count += 1 if datapoint.alertExpr.size > 0
  end

  puts 'Summary:'

  puts " - datasource name:\t#{datasource.name}"
  puts " - display name:\t#{datasource.displayName}"
  puts " - applies to:\t\t#{datasource.appliesTo}"
  puts " - polling interval:\t#{datasource.collectInterval / 60}m"
  puts " - multipoint instance:\t#{datasource.hasMultiInstances}"
  puts " - datapoints:\t\t#{datasource.dataPoints.count}"
  puts " - datapoint alerts:\t#{datapoint_alert_count}"
  puts " - graphs:\t\t#{graphs.count}"
  puts " - overview graphs:\t#{overview_graphs.count}"

  separator
end

def propose_fixes(errors)
  puts 'Proposed Fixes:'

  errors.flatten.each do |error|
    puts " * #{error}".colorize(:red)
  end
end

def separator
  puts '-' * 40
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
end
