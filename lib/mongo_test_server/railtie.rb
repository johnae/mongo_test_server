require 'rails'

module MongoTestServer
  class MongoTestServerRailtie < ::Rails::Railtie #:nodoc:
    config.before_initialize do
      if Rails.env.test?
        $stderr.puts "MongoTestServer: starting..."
        app_name = ENV['APP_NAME'] || Rails.application.class.to_s.split("::").first.downcase
        config_file = File.expand_path(File.join(Rails.root, 'config', 'mongoid.yml'))
        mongoid_options = YAML.load(ERB.new(File.read(config_file)).result)[ENV['RAILS_ENV']]
        port = mongoid_options['sessions']['default']['hosts'].first.split(':').last.to_i
        MongoTestServer::Mongod.configure do |server|
          server.name = app_name
          server.port = port
          server.path = `which mongod`.chomp
        end
        MongoTestServer::Mongod.server.start
      end
    end
  end
end