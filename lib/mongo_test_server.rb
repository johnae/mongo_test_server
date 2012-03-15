# coding: UTF-8
require 'mongo'
require 'fileutils'
require 'erb'
require 'yaml'
require 'tempfile'
require "mongo_test_server/version"

module MongoTestServer
  
  class Mongod
  
    class << self
  
      $mongo_test_server = nil
  
      def configure(port_or_config, name)
        port = port_or_config.to_i
        path = nil
        config = {}
        if port_or_config.is_a?(String) && File.exists?(port_or_config)
          if File.exists?(port_or_config)
            config = YAML.load(ERB.new(File.read(port_or_config)).result)[ENV['RAILS_ENV']]
            port = config.key?('port') ? config['port'].to_i : 27017
          end
        end
        path = config.key?('path') ? config['path'] : `which mongod`.chomp
        $mongo_test_server ||= new(port, name, path)
      end
  
      def start_server
        unless $mongo_test_server.nil?
          $mongo_test_server.start
        else
          puts "MongoTestServer not configured properly!"
        end
      end
  
      def stop_server
        unless $mongo_test_server.nil?
          $mongo_test_server.stop
        end
      end
  
    end
  
    def initialize(port, name, path)
      @port = port
      @path = path
      @mongo_process_or_thread = nil
      @mongo_dir = "/tmp/#{name}_mongo_testserver_#{Time.now.to_i}"
      @mongo_log = "#{@mongo_dir}/mongo.log"
      @oplog_size = 200
      @mongo_cmd_line = "#{@path} --port #{@port} --dbpath #{@mongo_dir} --noprealloc --nojournal --noauth --nohttpinterface --nssize 1 --oplogSize #{@oplog_size} --smallfiles --logpath #{@mongo_log}"
      @configured = true
      self.started = false
    end
  
    def prepare
      FileUtils.rm_rf @mongo_dir
      FileUtils.mkdir_p @mongo_dir
    end
  
    def started?
      File.exists?("#{@mongo_dir}/started")
    end

    def killed?
      File.exists?("#{@mongo_dir}/killed")
    end

    def started=(running)
      running ? FileUtils.touch("#{@mongo_dir}/started") : FileUtils.rm_f("#{@mongo_dir}/started")
    end

    def killed=(killing)
      killing ? FileUtils.touch("#{@mongo_dir}/killed") : FileUtils.rm_f("#{@mongo_dir}/killed")
    end
  
    def configured?
      @configured
    end
  
    def start
      #puts "Starting mongod: #{@mongo_cmd_line}"
      unless started?
        prepare
        if RUBY_PLATFORM=='java'
          @mongo_process_or_thread = Thread.new { run(@mongo_cmd_line) }
        else
          @mongo_process_or_thread = fork { run(@mongo_cmd_line) }
        end
        wait_until_ready
      end
      self
    end

    def run(command, *args)
      error_file = Tempfile.new('error')
      error_filepath = error_file.path
      error_file.close
      args = args.join(' ') rescue ''
      command << " #{args}" unless args.empty?
      result = `#{command} 2>"#{error_filepath}"`
      unless killed? || $?.success?
        error_message = <<-ERROR
          <#{self.class.name}> Error executing command: #{command}
          <#{self.class.name}> Result is: #{IO.binread(@mongo_log)}
          <#{self.class.name}> Error is: #{File.read(error_filepath)}
        ERROR
        self.killed=true
        raise Exception.new, error_message
      end
      result
    end
  
    def wait_until_ready
      retries = 10
      begin
        self.started = true
        c = Mongo::Connection.new("localhost", @port)
        c.close
      rescue Exception => e
        if retries>0 && !killed?
          retries -= 1
          sleep 0.5
          retry
        else
          self.started = false
          error_lines = []
          error_lines << "<#{self.class.name}> cmd was: #{@mongo_cmd_line}"
          error_lines << "<#{self.class.name}> ERROR: Failed to connect to mongo database: #{e.message}"
          IO.binread(@mongo_log).split("\n").each do |line|
            error_lines << "<#{self.class.name}> #{line}"
          end
          stop
          raise Exception.new error_lines.join("\n")
          exit(1)
        end
      end
    end
  
    def pids
      pids = `ps ax | grep mongod | grep #{@port} | grep #{@mongo_dir} | grep -v grep | awk '{print \$1}'`.chomp
      pids.split("\n").map {|p| (p.nil? || p=='') ? nil : p.to_i }
    end
  
    def stop
      mongo_pids = pids
      self.killed = true
      mongo_pids.each { |ppid| `kill -9 #{ppid}` }
      sleep 1
      FileUtils.rm_rf @mongo_dir
      self
    end
  
    def mongoid_yml
    mongo_conf_yaml = <<EOY
host: localhost
port: #{@port}
database : #{@name}_spec_db
use_utc: false
use_activesupport_time_zone: true
EOY
    end
  
  end
end