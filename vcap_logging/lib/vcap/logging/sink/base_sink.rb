require 'thread'

require 'vcap/logging/error'
require 'vcap/logging/log_record'

module VCAP
  module Logging
    module Sink

      class SinkError  < VCAP::Logging::LoggingError; end
      class UsageError < SinkError;                   end

      # Sinks serve as the final destination for log records.
      # Usually they are lightweight wrappers around other objects that perform IO (files and sockets come to mind).

      class BaseSink
        attr_reader   :opened
        attr_accessor :formatter
        attr_accessor :autoflush

        def initialize(formatter=nil)
          @formatter = formatter
          @opened    = false
          @mutex     = Mutex.new
          @autoflush = false
        end

        # Opens any underlying file descriptors, etc. and ensures that the sink
        # is capable of receiving records.
        #
        # This MUST be called before any calls to add_record().
        def open
          @mutex.synchronize { @opened = true }
        end

        # Closes any underlying file descriptors and ensures that any log records
        # buffered in memory are flushed.
        def close
          @mutex.synchronize { @opened = false }
        end

        def autoflush=(should_autoflush)
          @autoflush = should_autoflush
          flush if @autoflush
        end

        # Formats the log record using the configured formatter and
        # NB: Depending on the implementation of write(), this may buffer the record in memory.
        #
        # @param  log_record  VCAP::Logging::LogRecord  Record to add
        def add_record(log_record)
          raise UsageError, "You cannot add a record until the sink has been opened" unless @opened
          raise UsageError, "You must supply a formatter" unless @formatter

          message = @formatter.format_record(log_record)
          write(message)
          flush if @autoflush
        end

        # Flushes any log records that may have been buffered in memory
        def flush
          nil
        end

        private

        # Writes the formatted log message to the underlying device
        #
        # NB: Implementations MUST:
        #   - Be thread-safe.
        #   - Handle all exceptions that may occur when writing a message.
        #     An appropriate strategy could be as simple as logging the exception to standard error.
        #
        # @param  log_message  String  Message to write
        def write(log_message)
          raise NotImplementedError
        end

      end # VCAP::Logging::Sink::BaseSink

    end
  end
end
