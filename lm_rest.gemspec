# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lm_rest/version'

Gem::Specification.new do |spec|
  spec.name          = 'lm_rest'
  spec.version       = LMRest::VERSION
  spec.authors       = ['Michael Rodrigues']
  spec.email         = ['mikebrodrigues@gmail.com']

  spec.summary       = 'API Wrapper for LogicMonitor Rest API v2.'
  spec.description   = 'Interact programmatically with your LogicMonitor account via the REST API.'
  spec.homepage      = 'https://github.com/mikerodrigues/lm_rest'

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    fail 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = 'ds_checker.rb'
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'minitest'
  spec.add_dependency 'rest-client'
  spec.add_dependency 'json', '> 2.5.1'
end
