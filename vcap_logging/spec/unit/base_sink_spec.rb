require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe VCAP::Logging::Sink::BaseSink do
  before :each do
    @sink = VCAP::Logging::Sink::BaseSink.new
  end

  describe '#add_record' do
    it 'should raise an exception if supplied with something other than a log record' do
      lambda { @sink.add_record('foo') }.should raise_error(ArgumentError)
    end

    it 'should raise an exception if called before the sink is open' do
      rec = VCAP::Logging::LogRecord.new(:info, 'foo', [])
      lambda { @sink.add_record(rec) }.should raise_error(VCAP::Logging::Sink::UsageError)
    end

    it 'should raise an exception if called when a formatter has not been set for the sink' do
      rec = VCAP::Logging::LogRecord.new(:info, 'foo', [])
      @sink.open
      lambda { @sink.add_record(rec) }.should raise_error(VCAP::Logging::Sink::UsageError)
    end
  end
end
