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
      @out = nil
      open
    end

    def open
      @mutex.synchronize do
        @opened = true
        @out = @io
      end
    end

    def close
      @mutex.synchronize do
        @opened = false
        @out = nil
      end
    end

    private

    def write(message)
      @mutex.synchronize do
        @io.write(message)
      end
    end

  end
end
