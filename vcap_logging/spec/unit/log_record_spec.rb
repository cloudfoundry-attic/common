require File.join(File.dirname(__FILE__), '..', 'spec_helper')

require 'thread'

describe VCAP::Logging::LogRecord do
  before :each do
    @logger = VCAP::Logging::Logger.new('bar', nil)
    @tags = ['zaz']
    @data = 'foo'
    @log_level = :debug
    @rec = VCAP::Logging::LogRecord.new(@log_level, @data, @logger, @tags)
  end

  describe '#initialize' do
    it "sets the current thread id and short id" do
      @rec.thread_id.should == Thread.current.object_id
      @rec.thread_shortid.should_not == nil
    end

    it "sets the current process id" do
      @rec.process_id.should == Process.pid
    end

    it "sets the current fiber id and short id" do
      begin
        require 'fiber'
        @rec.fiber_id.should == Fiber.current.object_id
        @rec.fiber_shortid.should_not == nil
      rescue LoadError
        @rec.fiber_id.should == nil
        @rec.fiber_shortid.should == nil
      end
    end

    it "sets the logger name" do
      @rec.logger_name.should == @logger.name
    end

    it "sets the timestamp of when the record was created" do
      @rec.timestamp.should_not be_nil
    end

    it "sets tags" do
      @rec.tags.should == @tags
    end

    it "sets the log level" do
      @rec.log_level.should == @log_level
    end
  end
end
