# coding: UTF-8
#begin
#  require 'mongo'
#rescue LoadError => e
#  require 'moped'
#end
require 'fileutils'
require 'erb'
require 'yaml'
require 'tempfile'
require "mongo_test_server/version"

if defined?(Rails)
  require 'mongo_test_server/railtie'
  require 'mongo_test_server/engine'
end

module MongoTestServer

  class Mongod

    class << self

      def configure(options={}, &block)
        options.each do |k,v|
          server.send("#{k}=",v) if server.respond_to?("#{k}=")
        end
        yield(server) if block_given?
      end

      def server
        @mongo_test_server ||= new
      end

      def start_server
        unless @mongo_test_server.nil?
          @mongo_test_server.start
        else
          puts "MongoTestServer not configured properly!"
        end
      end

      def stop_server
        unless @mongo_test_server.nil?
          @mongo_test_server.stop
        end
      end

    end

    attr_writer :port
    attr_writer :path
    attr_writer :name
    attr_reader :mongo_instance_id
    attr_reader :use_ram_disk

    def initialize(port=nil, name=nil, path=nil)
      self.port = port
      self.path = path
      self.name = name
      @mongo_process_or_thread = nil
      @mongo_instance_id = "#{Time.now.to_i}_#{Random.new.rand(100000..900000)}"
      @oplog_size = 200
      @configured = true
      self.started = false
    end

    def use_ram_disk=(bool)
      if bool && (`which hdiutil`!='')
        @use_ram_disk = true
      else
        $stderr.puts "MongoTestServer: can't use a ram disk on this system"
        @use_ram_disk = false
      end
    end

    def use_ram_disk?
      @use_ram_disk
    end

    def ram_disk_name
      @ram_disk_name ||= "mongodb-ram-#{self.name}"
    end

    def setup_ram_disk
      @ram_disk_device = `hdiutil attach -nomount ram://1000000`.chomp
      `diskutil erasevolume HFS+ #{ram_disk_name} #{@ram_disk_device}`
      ram_disk_mount
    end

    def ram_disk_mount
      "/Volumes/#{ram_disk_name}"
    end

    def teardown_ram_disk
      `umount #{ram_disk_mount} 2> /dev/null`
      `hdiutil detach #{@ram_disk_device} 2> /dev/null`
    end

    def mongo_log
      "#{mongo_dir}/mongo_log"
    end

    def port
      @port ||= 27017
    end

    def path
      @path ||= `which mongod`.chomp
    end

    def name
      @name ||= "#{Random.new.rand(100000..900000)}"
    end

    def mongo_dir
      @mongo_dir ||= lambda {
        if self.use_ram_disk?
          $stderr.puts "MongoTestServer: using ramdisk"
          setup_ram_disk
        else
          "/tmp/#{self.name}_mongo_testserver_#{@mongo_instance_id}"
        end
        }.call
    end

    def remove_mongo_dir
      if self.use_ram_disk?
        teardown_ram_disk
      else
        FileUtils.rm_rf self.mongo_dir
      end
    end

    def mongo_cmd_line
      "#{self.path} --port #{self.port} --dbpath #{self.mongo_dir} --noprealloc --nojournal --noauth --nohttpinterface --nssize 1 --oplogSize #{@oplog_size} --smallfiles --logpath #{self.mongo_log}"
    end

    def prepare
      remove_mongo_dir
      FileUtils.mkdir_p self.mongo_dir
    end

    def running?
      pids = `ps ax | grep mongod | grep #{self.port} | grep #{self.mongo_dir} | grep -v grep | awk '{print \$1}'`.chomp
      !pids.empty?
    end

    def started?
      File.directory?(self.mongo_dir) && File.exists?("#{self.mongo_dir}/started")
    end

    def killed?
      !File.directory?(self.mongo_dir) || File.exists?("#{self.mongo_dir}/killed")
    end

    def started=(running)
      if File.directory?(self.mongo_dir)
        running ? FileUtils.touch("#{self.mongo_dir}/started") : FileUtils.rm_f("#{self.mongo_dir}/started")
      end
    end

    def killed=(killing)
      if File.directory?(self.mongo_dir)
        killing ? FileUtils.touch("#{self.mongo_dir}/killed") : FileUtils.rm_f("#{self.mongo_dir}/killed")
      end
    end

    def error?
      File.exists?("#{self.mongo_dir}/error")
    end

    def configured?
      @configured
    end

    def start
      unless started?
        prepare
        if RUBY_PLATFORM=='java'
          @mongo_process_or_thread = Thread.new { run(mongo_cmd_line) }
        else
          @mongo_process_or_thread = fork { run(mongo_cmd_line) }
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
          <#{self.class.name}> Result is: #{IO.binread(self.mongo_log) rescue "No mongo log on disk"}
          <#{self.class.name}> Error is: #{File.read(error_filepath) rescue "No error file on disk"}
        ERROR
        File.open("#{self.mongo_dir}/error", 'w') do |f|
          f << error_message
        end
        self.killed=true
      end
      result
    end

    def test_connection!
      if defined?(Mongo)
        c = Mongo::Connection.new("localhost", self.port)
        c.close
      elsif defined?(Moped)
        session = Moped::Session.new(["localhost:#{self.port}"])
        session.disconnect
      else
        raise Exeption.new "No mongo driver loaded! Only the official mongo driver and the moped driver are supported"
      end
    end

    def wait_until_ready
      retries = 10
      begin
        self.started = true
        test_connection!
      rescue Exception => e
        if retries>0 && !killed? && !error?
          retries -= 1
          sleep 0.5
          retry
        else
          self.started = false
          error_lines = []
          error_lines << "<#{self.class.name}> cmd was: #{mongo_cmd_line}"
          error_lines << "<#{self.class.name}> ERROR: Failed to connect to mongo database: #{e.message}"
          begin
            IO.binread(self.mongo_log).split("\n").each do |line|
              error_lines << "<#{self.class.name}> #{line}"
            end
          rescue Exception => e
            error_lines << "No mongo log on disk at #{self.mongo_log}"
          end
          stop
          raise Exception.new error_lines.join("\n")
        end
      end
    end

    def pids
      pids = `ps ax | grep mongod | grep #{self.port} | grep #{self.mongo_dir} | grep -v grep | awk '{print \$1}'`.chomp
      pids.split("\n").map {|p| (p.nil? || p=='') ? nil : p.to_i }
    end

    def stop
      mongo_pids = pids
      self.killed = true
      self.started = false
      mongo_pids.each { |ppid| `kill -9 #{ppid} 2> /dev/null` }
      remove_mongo_dir
      self
    end

    def mongoid_options(options={})
      options = {host: "localhost", port: self.port, database: "#{self.name}_test_db", use_utc: false, use_activesupport_time_zone: true}.merge(options)
    end

    def mongoid3_options(options={})
      options = {hosts: ["localhost:#{self.port}"], database: "#{self.name}_test_db", use_utc: false, use_activesupport_time_zone: true}.merge(options)
    end

    def mongoid_yml(options={})
      options = mongoid_options(options)
      mongo_conf_yaml = <<EOY
host: #{options[:host]}
port: #{options[:port]}
database : #{options[:database]}
use_utc: #{options[:use_utc]}
use_activesupport_time_zone: #{options[:use_activesupport_time_zone]}
EOY
    end

    def mongoid3_yml(options={})
      options = mongoid3_options(options)
      mongo_conf_yaml = <<EOY
sessions:
  default:
    hosts:
      - #{options[:hosts].first}
    database : #{options[:database]}
    use_utc: #{options[:use_utc]}
    use_activesupport_time_zone: #{options[:use_activesupport_time_zone]}
EOY
    end

  end
end