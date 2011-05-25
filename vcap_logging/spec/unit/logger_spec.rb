require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe VCAP::Logging::Logger do
  before :each do
    @logger = VCAP::Logging::Logger.new('test_logger')
    @levels = {:level2 => 2, :level1 => 1, :level0 => 0}
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
      new_logger = VCAP::Logging::Logger.new('test_logger2')
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

  describe '#log_record' do
    it 'should add records to configured sinks' do
      rec = VCAP::Logging::LogRecord.new(0, 'foo', @logger, [])
      sinks = [mock(:sink1), mock(:sink2)]
      for s in sinks
        s.should_receive(:add_record).with(rec).once
        @logger.add_sink(s)
      end
      @logger.send(:log_record, rec)
    end

    it 'should forward records to parent loggers if no sinks are installed' do
      parent = mock(:parent_logger)

      child = VCAP::Logging::Logger.new('foo.bar')
      child.parent = parent

      grandchild = VCAP::Logging::Logger.new('foo.bar.baz')
      grandchild.parent = child

      rec = VCAP::Logging::LogRecord.new(0, 'foo', grandchild, [])
      parent.should_receive(:log_record).with(rec).once
      grandchild.send(:log_record, rec)
    end
  end

  describe '#log' do
    it 'should raise an exception if called with an invalid level' do
      lambda { @logger.log(3, 'foo') }.should raise_error(ArgumentError)
    end

    it 'should use supplied blocks to generate log data' do
      block_called = false
      sink = mock(:sink)
      sink.should_receive(:add_record).with(an_instance_of(VCAP::Logging::LogRecord)).once
      @logger.add_sink(sink)
      @logger.log_level = :level1
      @logger.log(:level2) { block_called = true; 'foo' }
      block_called.should be_true
    end

    it 'should create log records for active levels' do
      sink = mock(:sink)
      sink.should_receive(:add_record).with(an_instance_of(VCAP::Logging::LogRecord)).twice
      @logger.add_sink(sink)
      @logger.log_level = :level1
      @logger.log(:level2, 'foo')
      @logger.log(:level1, 'foo')
      @logger.log(:level0, 'foo')
    end

    it 'should not create log records for levels that are not active' do
      sink = mock(:sink)
      sink.should_not_receive(:add_record)
      @logger.add_sink(sink)
      @logger.log_level = :level1
      @logger.log(:level0, 'foo')
    end

    it 'should not call blocks associated with inactive levels' do
      sink = mock(:sink)
      sink.should_not_receive(:add_record)
      @logger.add_sink(sink)
      @logger.log_level = :level1
      block_called = false
      @logger.log(:level0) { block_called = true; 'foo' }
      block_called.should be_false
    end
  end

  describe '#logf' do
    it 'should raise an exception if called with an invalid level' do
      lambda { @logger.logf(:level3, 'foo') }.should raise_error(ArgumentError)
    end

    it 'should create log records for active levels' do
      sink = mock(:sink)
      sink.should_receive(:add_record).with(an_instance_of(VCAP::Logging::LogRecord)).twice
      @logger.add_sink(sink)
      @logger.log_level = :level1
      @logger.logf(:level2, 'foo %s', ['bar'])
      @logger.logf(:level1, 'foo %s', ['baz'])
      @logger.logf(:level0, 'foo %s', ['jaz'])
    end

    it 'should not create log records for levels that are not active' do
      sink = mock(:sink)
      sink.should_not_receive(:add_record)
      @logger.add_sink(sink)
      @logger.log_level = :level1
      @logger.logf(:level0, 'foo', [])
    end
  end

  describe 'helper methods' do
    it 'should correctly pass their associated log levels' do
      fmt  = '%s'
      data = 'foo'
      for name in @levels.keys
        @logger.should_receive(:log).with(name, data, {}).once
        @logger.should_receive(:logf).with(name, fmt, [data], {}).once

        @logger.send(name, data)
        name_f = name.to_s + 'f'
        @logger.send(name_f.to_sym, fmt, [data])
      end
    end
  end

end
