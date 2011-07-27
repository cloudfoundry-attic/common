require 'vcap/logging/sink/base_sink'

module VCAP::Logging::Sink

  # A sink for writing to stderr/stdout
  # Usage:
  #   stdout_sink = VCAP::Logging::Sink::StdioSink.new(STDOUT)
  #
  class StdioSink < BaseSink
    def initialize(io, formatter=nil)
      super(formatter)
      @io  = io
      open
    end

    private

    def write(message)
      @mutex.synchronize do
        @io.write(message)
      end
    end

  end
end
