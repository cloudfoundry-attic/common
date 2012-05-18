require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe VCAP::Logging::Logger do
  before :each do
    @levels = {:debug => 2, :info => 1, :fatal => 0}
    @sink_map = VCAP::Logging::SinkMap.new(@levels)
    @logger = VCAP::Logging::Logger.new('test_logger', @sink_map)
    VCAP::Logging::Logger.define_log_levels(@levels)
  end

  describe '.define_log_levels' do
    it 'should define helper methods corresponding to the name of the log levels' do
      level_map = {:error => 2, :info => 1, :debug => 0}
      VCAP::Logging::Logger.define_log_levels(level_map)

      # Check that existing loggers are updated
      for name in level_map.keys
        @logger.respond_to?(name).should be_true
        name_f = name.to_s + 'f'
        @logger.respond_to?(name_f.to_sym).should be_true
      end

      # Check that new loggers are updated as well
      new_logger = VCAP::Logging::Logger.new('test_logger2', VCAP::Logging::SinkMap.new(level_map))
      for name in level_map.keys
        new_logger.respond_to?(name).should be_true
        name_f = name.to_s + 'f'
        new_logger.respond_to?(name_f.to_sym).should be_true
      end
    end

    it 'should undefine previously defined helpers' do
      level_map = {:error => 2, :info => 1, :debug => 0}
      VCAP::Logging::Logger.define_log_levels(level_map)
      for name in level_map.keys
        @logger.respond_to?(name).should be_true
        name_f = name.to_s + 'f'
        @logger.respond_to?(name_f.to_sym).should be_true
      end

      # Check that previously defined methods are no longer there, and that the
      # appropriate methods have been defined
      new_levels = {:foo => 2, :bar => 1}
      VCAP::Logging::Logger.define_log_levels(new_levels)
      for name in level_map.keys
        @logger.respond_to?(name).should be_false
        name_f = name.to_s + 'f'
        @logger.respond_to?(name_f.to_sym).should be_false
      end
      for name in new_levels.keys
        @logger.respond_to?(name).should be_true
        name_f = name.to_s + 'f'
        @logger.respond_to?(name_f.to_sym).should be_true
      end
    end
  end

  describe '#log' do
    it 'should raise an exception if called with an invalid level' do
      lambda { @logger.log(3, 'foo') }.should raise_error(ArgumentError)
    end

    it 'should use supplied blocks to generate log data' do
      block_called = false
      sink = mock(:sink)
      sink.should_receive(:add_record).with(an_instance_of(VCAP::Logging::LogRecord)).once do |record|
        record.data.should == 'foo'
      end

      @sink_map.add_sink(nil, nil, sink)
      @logger.log_level = :info
      @logger.fatal { block_called = true; 'foo' }
      block_called.should be_true
    end

    it 'should create log records for active levels' do
      sink = mock(:sink)
      sink.should_receive(:add_record).with(an_instance_of(VCAP::Logging::LogRecord)).twice
      @sink_map.add_sink(nil, nil, sink)
      @logger.log_level = :info
      @logger.log(:fatal, 'foo')
      @logger.log(:info, 'foo')
      @logger.log(:debug, 'foo')
    end

    it 'should not create log records for levels that are not active' do
      sink = mock(:sink)
      sink.should_not_receive(:add_record)
      @sink_map.add_sink(nil, nil, sink)
      @logger.log_level = :info
      @logger.log(:debug, 'foo')
    end

    it 'should not call blocks associated with inactive levels' do
      sink = mock(:sink)
      sink.should_not_receive(:add_record)
      @sink_map.add_sink(nil, nil, sink)
      @logger.log_level = :info
      block_called = false
      @logger.log(:debug) { block_called = true; 'foo' }
      block_called.should be_false
    end

    it 'should indicate if a level is active' do
      @levels.keys.each do |level|
        @logger.log_level = level
        @logger.send(level.to_s + '?').should be_true
      end
      @logger.log_level = :info
      @logger.debug?.should be_false

      @logger.log_level = :fatal
      @logger.info?.should be_false
      @logger.debug?.should be_false
    end

    it "should add an 'exception' tag when data is a kind of Exception" do
      @logger.log_level = :info
      ex = StandardError.new("Testing 123")
      VCAP::Logging::LogRecord.should_receive(:new).with(:info, ex, @logger, [:exception])
      @logger.info(ex)
    end
  end

  describe '#logf' do
    it 'should raise an exception if called with an invalid level' do
      lambda { @logger.logf(:level3, 'foo') }.should raise_error(ArgumentError)
    end

    it 'should create log records for active levels' do
      sink = mock(:sink)
      sink.should_receive(:add_record).with(an_instance_of(VCAP::Logging::LogRecord)).twice
      @sink_map.add_sink(nil, nil, sink)
      @logger.log_level = :info
      @logger.logf(:fatal, 'foo %s', ['bar'])
      @logger.logf(:info, 'foo %s', ['baz'])
      @logger.logf(:debug, 'foo %s', ['jaz'])
    end

    it 'should not create log records for levels that are not active' do
      sink = mock(:sink)
      sink.should_not_receive(:add_record)
      @sink_map.add_sink(nil, nil, sink)
      @logger.log_level = :info
      @logger.logf(:debug, 'foo', [])
    end
  end

  describe 'helper methods' do
    it 'should correctly pass their associated log levels' do
      fmt  = '%s'
      data = 'foo'
      for name in @levels.keys
        @logger.should_receive(:log).with(name, data).once
        @logger.should_receive(:logf).with(name, fmt, [data]).once

        @logger.send(name, data)
        name_f = name.to_s + 'f'
        @logger.send(name_f.to_sym, fmt, [data])
      end
    end
  end

end
