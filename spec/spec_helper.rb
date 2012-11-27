# coding: UTF-8

require 'bundler/setup'
Bundler.require(:default, :development)
mongo_test_server_path = File.expand_path('./lib', File.dirname(__FILE__))
$:.unshift(mongo_test_server_path) if File.directory?(mongo_test_server_path) && !$:.include?(mongo_test_server_path)

require 'mongo_test_server'
require 'yaml'
require 'fileutils'

RSpec.configure do |config|
  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  config.mock_with :rspec

  ## perhaps this should be removed as well
  ## and done in Rakefile?
  config.color_enabled = true

  ## dont do this, do it in Rakefile instead
  #config.formatter = 'd'
end