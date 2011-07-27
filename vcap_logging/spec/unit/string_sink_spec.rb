require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe VCAP::Logging::Sink::StringSink do
  it 'should append formatted messages to the given string' do
    msg = 'test log message'
    fmt = mock(:formatter)
    fmt.should_receive(:format_record).with(nil).and_return(msg)
    str = mock(:str)
    str.should_receive(:<<).with(msg)
    sink = VCAP::Logging::Sink::StringSink.new(str, fmt)
    sink.add_record(nil)
  end
end
