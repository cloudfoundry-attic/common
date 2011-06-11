require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe VCAP::Logging::Sink::BaseSink do
  before :each do
    @sink = VCAP::Logging::Sink::BaseSink.new
    @rec = VCAP::Logging::LogRecord.new(:info, 'foo', VCAP::Logging::Logger.new('bar', nil), [])
  end

  describe '#add_record' do
    it 'should raise an exception if called before the sink is open' do
      lambda { @sink.add_record(@rec) }.should raise_error(VCAP::Logging::Sink::UsageError)
    end

    it 'should raise an exception if called when a formatter has not been set for the sink' do
      @sink.open
      lambda { @sink.add_record(@rec) }.should raise_error(VCAP::Logging::Sink::UsageError)
    end
  end

  describe '#autoflush' do
    it 'should immediately call flush when set to true' do
      @sink.formatter = mock(:formatter)
      @sink.should_receive(:flush)
      @sink.open
      @sink.autoflush = true
    end

    it 'should call flush after each add_record call if true' do
      @sink.formatter = mock(:formatter)
      @sink.formatter.should_receive(:format_record).with(@rec).and_return('foo')
      @sink.should_receive(:write).with('foo')
      @sink.should_receive(:flush).twice
      @sink.open
      @sink.autoflush = true
      @sink.add_record(@rec)
    end
  end
end
