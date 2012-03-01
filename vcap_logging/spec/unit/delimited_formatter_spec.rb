# encoding: utf-8
require File.join(File.dirname(__FILE__), '..', 'spec_helper')


describe VCAP::Logging::Formatter::DelimitedFormatter do
  let(:logger) { VCAP::Logging::Logger.new('foo', nil) }
  let(:formatter) { VCAP::Logging::Formatter::DelimitedFormatter.new('.') }

  describe '#format_record' do
    it 'should return a correctly formatted message' do
      rec = VCAP::Logging::LogRecord.new(:debug, 'foo', logger, ['bar', 'baz'])
      line = [rec.timestamp.strftime(formatter.timestamp_fmt),
              logger.name,
              'bar,baz',
              'pid=' + rec.process_id.to_s,
              'tid=' + rec.thread_shortid.to_s,
              'fid=' + rec.fiber_shortid.to_s,
              ' DEBUG',
              '--',
              'foo'].join('.') + "\n"
      formatter.format_record(rec).should == line
    end

    it 'should encode newlines' do
      rec = VCAP::Logging::LogRecord.new(:debug, "test\ning123\n\n", logger)
      formatter.format_record(rec).should match(/test\\ning123\\n\\n\n/)
    end

    it 'should format exceptions' do
      begin
        raise StandardError, "Testing 123"
      rescue => e
      end
      rec = VCAP::Logging::LogRecord.new(:error, e, logger)
      bt_str = e.backtrace.join(',')
      match_regex = /StandardError<<Testing 123:/
      formatter.format_record(rec).should match(match_regex)
    end
  end

  it 'should convert data to ascii' do
    data = "HI\u2600"
    rec = VCAP::Logging::LogRecord.new(:error, data, logger)
    formatter.format_record(rec).should match(/HI\?\n$/)
  end
end
