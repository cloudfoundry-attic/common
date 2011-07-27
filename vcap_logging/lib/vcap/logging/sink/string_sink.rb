require 'vcap/logging/sink/base_sink'

module VCAP::Logging::Sink

  # A sink for writing data to a string. Useful if you want to capture logs
  # in memory along with writing to a file.
  class StringSink < BaseSink
    def initialize(str, formatter=nil)
      super(formatter)
      @str = str
      open
    end

    def write(message)
      @mutex.synchronize { @str << message }
    end
  end
end
