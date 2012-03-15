# coding: UTF-8
require 'bundler/setup'

Bundler.require(:default)

mongo_test_server_path = File.expand_path('./lib', File.dirname(__FILE__))
$:.unshift(mongo_test_server_path) if File.directory?(mongo_test_server_path) && !$:.include?(mongo_test_server_path)

require 'mongo_test_server'

mongod = MongoTestServer::Mongod.configure(10203, 'testing_mongo')
mongod.start
sleep 10
mongod.stop