require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe VCAP::Logging::Formatter::DelimitedFormatter do
  describe '#initialize' do

    it 'should define a format_record' do
      fmt = VCAP::Logging::Formatter::DelimitedFormatter.new {}
      fmt.respond_to?(:format_record).should be_true
    end

  end

  describe '#format_record' do
    it 'should return a correctly formatted message' do
      rec = VCAP::Logging::LogRecord.new(:debug, 'foo', VCAP::Logging::Logger.new('foo', nil), ['bar', 'baz'])
      fmt = VCAP::Logging::Formatter::DelimitedFormatter.new('.') do
        timestamp '%s'
        log_level
        tags
        process_id
        thread_id
        data
      end

      fmt.format_record(rec).should == [rec.timestamp.strftime('%s'), 'DEBUG', 'bar,baz', rec.process_id.to_s, rec.thread_id.to_s, 'foo'].join('.')
    end

  end
end
