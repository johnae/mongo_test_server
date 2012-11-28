require 'spec_helper'

describe MongoTestServer::Mongod do

  let(:port) { 11129 }
  let(:bad_port) { 112233 }
  let(:server_name) { "random_name_#{Random.new.rand(100000000..900000000)}"}
  let(:path) { `which mongod`.chomp }
  subject { MongoTestServer::Mongod.new(port, server_name, path)}
  let(:server_same_port) { MongoTestServer::Mongod.new(port, server_name, path)}
  let(:correct_mongoid_options) do
    {
      host: "localhost",
      port: port,
      database: "#{server_name}_test_db",
      use_utc: false,
      use_activesupport_time_zone: true
    }
  end
  after(:each) do
    subject.stop
    server_same_port.stop
  end

  context "starting" do

    it "should start" do
      lambda { subject.start }.should_not raise_error
      subject.started?.should be_true
    end

    it "should not complain if starting a started mongod" do
      lambda { subject.start }.should_not raise_error
      subject.started?.should be_true
      lambda { subject.start }.should_not raise_error
    end

    it "should raise if something else is listening on the same port" do
      server_same_port.start
      subject.start.should raise_error
    end

    it "should raise if there is an error starting mongod" do
      subject.port = bad_port ## port number is too high
      lambda { subject.start }.should raise_error
    end

  end

  context "mongoid config" do

    it "should return correct mongoid options" do
      subject.mongoid_options.should == correct_mongoid_options
    end

    it "should return correct mongoid options with requested changes" do
      changed_mongoid_options = correct_mongoid_options.merge(use_utc: true, use_activesupport_time_zone: false)
      subject.mongoid_options(use_utc: true, use_activesupport_time_zone: false).should == changed_mongoid_options
    end

  end

  context "stopping" do

    before(:each) do
      subject.start
    end

    it "should stop a started mongod" do
      subject.started?.should be_true
      subject.stop
      subject.started?.should be_false
      subject.killed?.should be_true
      subject.running?.should be_false
    end

    it "should not complain if stopping a stopped mongod" do
      subject.started?.should be_true
      subject.killed?.should be_false
      subject.stop
      subject.started?.should be_false
      subject.killed?.should be_true
      subject.running?.should be_false
      lambda{ subject.stop }.should_not raise_error
    end

    it "should cleanup after itself" do
      subject.started?.should be_true
      File.directory?(subject.mongo_storage).should be_true
      subject.stop
      File.exists?(subject.mongo_storage).should be_false
    end

  end

  context "MongoTestServer#configure" do

    let(:name) { "somename" }
    let(:port) { 33221 }
    let(:path) { `which mongod`.chomp }

    it "should configure a global mongod" do
      MongoTestServer::Mongod.configure do |server|
        server.name = name
        server.port = port
        server.path = path
      end
      server = MongoTestServer::Mongod.server
      server.port.should == port
      server.name.should == name
      server.path.should == path
    end

    it "should configure a global mongod using options instead of block" do
      MongoTestServer::Mongod.configure(port: (port+1), name: "someothername", path: path)
      server = MongoTestServer::Mongod.server
      server.port.should == (port+1)
      server.name.should == "someothername"
      server.path.should == path
    end

  end

end