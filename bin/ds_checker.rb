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
  @lm = LMRest.new(@account, @userid, @passwd)
else
  usage
  fail "Bad arguments."
end

def dp_type(datapoint)
  datapoint.postProcessorMethod == "expression" ? 'complex' : 'normal'
end

def test_datasource_name(datasource)
  errors = []

  # does the name contain whitespace?
  if datasource.name =~ /\s+/
    errors.push("datasource name contains whitespace")
  end

  # does the name end in a trailing dash?
  if datasource.name =~ /\-$/
    errors.push("datasource name has trailing dash")
  end

  # does the display name end in a trailing dash?
  if datasource.displayName =~ /\-$/
    errors.push("datasource display name has trailing dash")
  end

  errors
end

def test_datasource_description(datasource)
  error = nil

  # is the description size less than 10 characters in length?
  if datasource.description.length < 10
    error = "datasource description is empty or sparse"
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
    # is there a datapoint alert trigger set, but no custom alert message
    #
    if (datapoint.alertExpr.size > 0) && (datapoint.alertBody == 0)
      errors.push("datapoint \"" + datapoint.name +
                  "\" has an alert threshold but no message")
    end

    # is there a custom alert message on this datapoint?
    #
    if datapoint.alertBody.size > 0
      tokens.each do |token|
        # is this token in the datasource definition?
        #
        unless datapoint.alertBody.include? token
          errors.push("custom alert message on \"" + datapoint.name +
                      "\" datpoint doesn't include token " + token)
        end
      end
    end
  end

  errors
end

def test_datapoint_usage(datapoints, complex_datapoints, graphs, overview_graphs)
  datapoint_report = []
  errors = []
  datapoint_ok = []

  puts "Datapoints:"
  # is an alert trigger set?
  datapoints.each do |datapoint|
    if datapoint.alertExpr.size > 0
      puts " - " + dp_type(datapoint) + datapoint.name + " has alert threshold set"
    else

      # is this datapoint used in a complex datapoint?
      complex_datapoints.each do |complex_datapoint|
        if complex_datapoint.postProcessorParam.include? datapoint.name
          puts(' - ' + dp_type(datapoint) + ' "' + datapoint.name +
               '" used in complex datapoint' + complex_datapoint.name)
          datapoint_ok.push(datapoint.name)
          break
        end
      end

      # is this datapoint used in any graphs?
      graphs.each do |graph|
        graph.dataPoints.each do |graph_datapoint|
          if datapoint.name == graph_datapoint["name"]
            puts(' - ' + dp_type(datapoint) + ' "' + datapoint.name +
                 '" used in graph "' + graph.name + '" datapoint')
            datapoint_ok.push(datapoint.name)
            break
          end
        end
      end

      overview_graphs.each do |ograph|
        ograph.dataPoints.each do |ograph_datapoint|
          if datapoint.name == ograph_datapoint["name"]
            puts(' - ' + dp_type(datapoint) + ' "' + datapoint.name +
                 '" used in overview graph "' + ograph.name + '" datapoint')
            datapoint_ok.push(datapoint.name)
            break
          end
        end
      end

      unless datapoint_ok.include? datapoint.name
        errors.push("datapoint \"" + datapoint.name + "\" appears to be unused")
      end
    end
  end

  separator
  errors
end

def test_graphs(graphs)
  errors = []

  puts "Graphs:"

  display_prios = {}
  graphs.each do |graph|
    puts ' - "' + graph.name + '" at display priority ' + graph.displayPrio.to_s
    # does the y-axis label contain capital letters?
    if graph.verticalLabel.match(/[A-Z]/)
      errors.push('graph "' + graph.name +
                  '" has uppercase letters in the y-axis definition (' +
                  graph.verticalLabel + ')')
    end

    # has this graph priority already been used?
    if display_prios.include? graph.displayPrio
      errors.push('graph "' + graph.name + '" is assigned the same display priority (' +
                  graph.displayPrio.to_s + ') as "' +
                  display_prios[graph.displayPrio])
    else
      # no -- store this priority in a hash for further testing
      display_prios[graph.displayPrio] = graph.name
    end
  end

  separator
  errors
end

def test_overview_graphs(overview_graphs)
  errors = []

  puts "Overview Graphs:"

  display_prios = {}
  overview_graphs.each do |ograph|
    puts ' - "' + ograph.name + '" at display priority ' + ograph.displayPrio.to_s
    if ograph.verticalLabel.match(/[A-Z]/)
      errors.push('overview graph "' + ograph.name +
                  '" has uppercase letters in the y-axis definition (' +
                  ograph.verticalLabel + ')')
    end

    if display_prios.include? ograph.displayPrio
      errors.push('overview graph "' + ograph.name + '" is assigned the same display priority (' +
                  ograph.displayPrio.to_s + ') as "' +
                  display_prios[ograph.displayPrio])
    else
      display_prios[ograph.displayPrio] = ograph.name
    end
  end

  separator
  errors
end

def summarize(datasource, datapoints, graphs, overview_graphs)
  datapoint_alert_count = 0
  datapoints.each do |datapoint|
    if datapoint.alertExpr.size > 0
      datapoint_alert_count += 1
    end
  end

  puts "Summary:"

  puts " - datasource name:\t#{datasource.name}"
  puts " - display name:\t\t#{datasource.displayName}"
  puts " - applies to:\t\t#{datasource.appliesTo}"
  puts " - polling interval:\t#{datasource.collectInterval/60}m"
  puts " - multipoint instance?:\t#{datasource.hasMultiInstances}"
  puts " - datapoints:\t\t#{datasource.dataPoints.count}"
  puts " - datapoint_alerts:\t#{datapoint_alert_count}"
  puts " - graphs:\t\t#{graphs.count}"
  puts " - overview graphs:\t#{overview_graphs.count}"

  separator
end

def propose_fixes(errors)
  puts "Proposed Fixes:"

  errors.flatten.each do |error|
    puts " * " + error
  end
end

def separator
  puts "============================="
end

@datasources = @lm.get_datasources(filter: "name:#{ARGV[3]}")

@datasources.each do |datasource|
  errors = []
  datapoint_alert_count = 0
  datapoints = @lm.get_datapoints(datasource.id)
  normal_datapoints = datapoints.select{|dp| dp.postProcessorMethod != "expression"}
  complex_datapoints = datapoints.select{|dp| dp.postProcessorMethod == "expression"}
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
  separator
  separator
end
