require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe VCAP::Logging::Sink::StdioSink do
  it 'should not close the underlying io object when closed' do
    io = mock(:stdout)
    io.should_not_receive(:close)
    sink = VCAP::Logging::Sink::StdioSink.new(io)
    sink.close
  end

  it 'should write formatted messages to the underlying io device' do
    msg = 'test log message'
    fmt = mock(:formatter)
    fmt.should_receive(:format_record).with(nil).and_return(msg)
    io = mock(:stdio)
    io.should_receive(:write).with(msg)
    sink = VCAP::Logging::Sink::StdioSink.new(io, fmt)
    sink.add_record(nil)
  end
end
