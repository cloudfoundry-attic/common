require File.join(File.dirname(__FILE__), '..', 'spec_helper')

require 'syslog'

describe VCAP::Logging::Sink::SyslogSink do
  it 'should use the user facility for logging messages' do
    Syslog.should_receive(:open).with('test', Syslog::LOG_PID, Syslog::LOG_USER).and_return(nil)
    sink = VCAP::Logging::Sink::SyslogSink.new('test')
  end

  it 'should map app log levels to syslog levels' do
    msg = 'test message'
    rec = mock(:test_record)
    rec.should_receive(:log_level).and_return(:info)
    fmt = mock(:test_formatter)
    fmt.should_receive(:format_record).with(any_args()).and_return(msg)
    Syslog.should_receive(:open).with('test', Syslog::LOG_PID, Syslog::LOG_USER).and_return(Syslog)
    Syslog.should_receive(:log).with(Syslog::LOG_INFO, '%s', msg).and_return(nil)
    sink = VCAP::Logging::Sink::SyslogSink.new('test')
    sink.formatter = fmt
    sink.add_record(rec)
  end
end
