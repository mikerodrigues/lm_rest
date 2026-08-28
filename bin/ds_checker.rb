#!/usr/bin/env ruby

require 'lm_rest'

STANDARD_GRAPH_NOTE = 'Standard datasource graph checks are skipped because the current LogicMonitor v3 Swagger surface only exposes datasource overview graph endpoints.'.freeze

def usage
  puts "USAGE:\t#{$PROGRAM_NAME} account access_id access_key datasource_name_or_glob"
end

abort('Bad arguments.') unless ARGV.length == 4

@account, @access_id, @access_key, @datasource_filter = ARGV
@lm = LMRest::APIClient.new(@account, @access_id, @access_key)
@standard_graph_note_printed = false

def wrap_resources(items)
  Array(items).map { |item| item.is_a?(LMRest::Resource) ? item : LMRest::Resource.new(item) }
end

def resource_value(resource, *keys)
  keys.each do |key|
    return resource.public_send(key) if resource.respond_to?(key)
    return resource[key] if resource.respond_to?(:key?) && resource.key?(key)
    return resource[key.to_s] if resource.is_a?(Hash) && resource.key?(key.to_s)
    return resource[key] if resource.is_a?(Hash) && resource.key?(key)
  end

  nil
end

def fetch_datasource_details(datasource_id)
  @lm.get_datasource(
    datasource_id,
    fields: 'name,displayName,description,appliesTo,collectInterval,hasMultiInstances,dataPoints'
  )
end

def fetch_datapoints(datasource)
  wrap_resources(resource_value(datasource, :dataPoints))
end

def fetch_overview_graphs(datasource_id)
  wrap_resources(@lm.get_data_source_overview_graph_list(datasource_id))
end

def fetch_standard_graphs(_datasource_id)
  return [] if @standard_graph_note_printed

  puts STANDARD_GRAPH_NOTE
  @standard_graph_note_printed = true
  []
end

def dp_type(datapoint)
  resource_value(datapoint, :postProcessorMethod).to_s == 'expression' ? 'complex' : 'normal'
end

def test_datasource_name(datasource)
  errors = []
  name = resource_value(datasource, :name).to_s
  display_name = resource_value(datasource, :displayName).to_s

  errors << 'datasource name contains whitespace' if name.match?(/\s+/)
  errors << 'datasource name has trailing dash' if name.end_with?('-')
  errors << 'datasource display name has trailing dash' if display_name.end_with?('-')

  errors
end

def test_datasource_description(datasource)
  description = resource_value(datasource, :description).to_s.strip
  return nil unless description.length < 10

  'datasource description is empty or sparse'
end

def test_datapoint_descriptions(datapoints)
  datapoints.filter_map do |datapoint|
    description = resource_value(datapoint, :description).to_s.strip
    next unless description.length < 10

    %(datapoint "#{resource_value(datapoint, :name)}" description is empty or sparse)
  end
end

def test_datapoint_alerts(datapoints)
  errors = []
  tokens = %w[##HOST## ##VALUE## ##DURATION## ##START##]

  datapoints.each do |datapoint|
    check_alert_threshold(datapoint, errors)
    check_custom_alert_message(datapoint, tokens, errors)
  end

  errors
end

def check_alert_threshold(datapoint, errors)
  alert_expr = resource_value(datapoint, :alertExpr).to_s
  alert_body = resource_value(datapoint, :alertBody).to_s
  return if alert_expr.empty? || !alert_body.empty?

  errors << %(datapoint "#{resource_value(datapoint, :name)}" has an alert threshold but no message)
end

def check_custom_alert_message(datapoint, tokens, errors)
  alert_body = resource_value(datapoint, :alertBody).to_s
  return if alert_body.empty?

  tokens.each do |token|
    next if alert_body.include?(token)

    errors << %(custom alert message on "#{resource_value(datapoint, :name)}" datapoint doesn't include token #{token})
  end
end

def test_datapoint_usage(datapoints, complex_datapoints, graphs, overview_graphs)
  datapoint_ok = []

  puts 'Datapoints:'
  datapoints.each do |datapoint|
    if !resource_value(datapoint, :alertExpr).to_s.empty?
      puts %( - #{dp_type(datapoint)} datapoint "#{resource_value(datapoint, :name)}" has alert threshold set)
      next
    end

    check_complex_datapoints(datapoint, complex_datapoints, datapoint_ok)
    track_graph_usage(datapoint, graphs, datapoint_ok, 'graph')
    track_graph_usage(datapoint, overview_graphs, datapoint_ok, 'overview graph')
  end

  check_datapoints(datapoints, datapoint_ok)
end

def check_complex_datapoints(datapoint, complex_datapoints, datapoint_ok)
  complex_datapoints.each do |complex_datapoint|
    next unless resource_value(complex_datapoint, :postProcessorParam).to_s.include?(resource_value(datapoint, :name).to_s)

    puts %( - #{dp_type(datapoint)} datapoint "#{resource_value(datapoint, :name)}" used in complex datapoint #{resource_value(complex_datapoint, :name)})
    datapoint_ok << resource_value(datapoint, :name)
    break
  end
end

def track_graph_usage(datapoint, graphs, datapoint_ok, graph_type)
  datapoint_name = resource_value(datapoint, :name).to_s

  graphs.each do |graph|
    extract_graph_datapoints(graph).each do |graph_datapoint|
      next unless datapoint_name == graph_datapoint_name(graph_datapoint)

      puts %( - #{dp_type(datapoint)} datapoint "#{datapoint_name}" used in #{graph_type} "#{resource_value(graph, :name)}")
      datapoint_ok << datapoint_name
      break
    end
  end
end

def extract_graph_datapoints(graph)
  Array(resource_value(graph, :dataPoints, :lines, :graphDataPoints))
end

def graph_datapoint_name(graph_datapoint)
  if graph_datapoint.is_a?(LMRest::Resource)
    resource_value(graph_datapoint, :name, :dataPointName)
  elsif graph_datapoint.is_a?(Hash)
    graph_datapoint['name'] || graph_datapoint[:name] || graph_datapoint['dataPointName'] || graph_datapoint[:dataPointName]
  else
    nil
  end.to_s
end

def test_graphs(graphs)
  puts 'Graphs:'
  errors = check_graph_definitions(graphs, 'graph')
  separator
  errors
end

def test_overview_graphs(overview_graphs)
  puts 'Overview Graphs:'
  errors = check_graph_definitions(overview_graphs, 'overview graph')
  separator
  errors
end

def check_datapoints(datapoints, used_datapoints)
  used_datapoints = used_datapoints.compact.uniq

  datapoints.filter_map do |datapoint|
    next if used_datapoints.include?(resource_value(datapoint, :name))

    %(datapoint "#{resource_value(datapoint, :name)}" appears to be unused)
  end
end

def check_graph_definitions(graphs, graph_type)
  errors = []
  display_prios = {}

  graphs.each do |graph|
    name = resource_value(graph, :name).to_s
    display_prio = resource_value(graph, :displayPrio, :displayPriority)
    vertical_label = resource_value(graph, :verticalLabel, :yAxisLabel).to_s

    puts %( - "#{name}" at display priority #{display_prio})
    if vertical_label.match?(/[A-Z]/)
      errors << %(#{graph_type} "#{name}" has uppercase letters in the y-axis definition (#{vertical_label}))
    end

    if !display_prio.nil? && display_prios.key?(display_prio)
      errors << %(#{graph_type} "#{name}" is assigned the same display priority (#{display_prio}) as "#{display_prios[display_prio]}")
    elsif !display_prio.nil?
      display_prios[display_prio] = name
    end
  end

  errors
end

def summarize(datasource, datapoints, graphs, overview_graphs)
  datapoint_alert_count = datapoints.count { |datapoint| !resource_value(datapoint, :alertExpr).to_s.empty? }

  puts 'Summary:'
  puts " - datasource name:\t#{resource_value(datasource, :name)}"
  puts " - display name:\t#{resource_value(datasource, :displayName)}"
  puts " - description:\t\t#{resource_value(datasource, :description)}"
  puts " - applies to:\t\t#{resource_value(datasource, :appliesTo)}"
  puts " - polling interval:\t#{resource_value(datasource, :collectInterval).to_i / 60}m"
  puts " - multipoint instance:\t#{resource_value(datasource, :hasMultiInstances)}"
  puts " - datapoints:\t\t#{datapoints.count}"
  puts " - datapoint alerts:\t#{datapoint_alert_count}"
  puts " - graphs:\t\t#{graphs.count}"
  puts " - overview graphs:\t#{overview_graphs.count}"
  separator
end

def propose_fixes(errors)
  puts 'Proposed Fixes:'

  flattened = errors.flatten.compact
  if flattened.empty?
    puts ' * none'
    return
  end

  flattened.each do |error|
    puts " * #{error}"
  end
end

def separator
  puts '-' * 40
end

datasources = @lm.get_datasources(filter: %(name:"#{@datasource_filter}"))
abort("No datasources matched #{@datasource_filter.inspect}") if datasources.empty?

datasources.each do |datasource|
  datasource = fetch_datasource_details(datasource.id)
  datapoints = fetch_datapoints(datasource)
  complex_datapoints = datapoints.select { |dp| dp_type(dp) == 'complex' }
  graphs = fetch_standard_graphs(datasource.id)
  overview_graphs = fetch_overview_graphs(datasource.id)

  errors = []
  summarize(datasource, datapoints, graphs, overview_graphs)
  errors << test_datasource_name(datasource)
  errors << test_datasource_description(datasource)
  errors << test_datapoint_descriptions(datapoints)
  errors << test_datapoint_alerts(datapoints)
  errors << test_datapoint_usage(datapoints, complex_datapoints, graphs, overview_graphs)
  errors << test_graphs(graphs)
  errors << test_overview_graphs(overview_graphs)
  propose_fixes(errors)
  separator
end
