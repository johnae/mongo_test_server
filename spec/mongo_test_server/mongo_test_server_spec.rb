require 'spec_helper'

describe MongoTestServer::Mongod do

  let(:port) { 11129 }
  let(:bad_port) { 112233 }
  let(:server_name) { "random_name_#{Random.new.rand(100000000..900000000)}"}
  let(:path) { `which mongod`.chomp }
  subject { MongoTestServer::Mongod.new(port, server_name, path)}
  let(:server_same_port) { MongoTestServer::Mongod.new(port, server_name, path)}

  after(:each) do
    subject.stop
    server_same_port.stop
  end

  context "starting" do

    it "should start" do
      lambda { subject.start }.should_not raise_error
      subject.started?.should be_true
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

  context "stopping" do

    before(:each) do
      subject.start
    end

    it "should stop a started mongod" do
      subject.started?.should be_true
      subject.stop
      subject.started?.should be_false
      subject.killed?.should be_true
    end

    it "should not complain if stopping a stopped mongod" do
      subject.started?.should be_true
      subject.killed?.should be_false
      subject.stop
      subject.started?.should be_false
      subject.killed?.should be_true
      lambda{ subject.stop }.should_not raise_error
    end

    it "should cleanup after itself" do
      subject.started?.should be_true
      File.directory?(subject.mongo_dir).should be_true
      subject.stop
      File.exists?(subject.mongo_dir).should be_false
    end

  end

end