require 'vcap/logging/log_record'

module VCAP
  module Logging
    module Formatter

      # Formatters are responsible for taking a log record and
      # producing a string representation suitable for writing to a sink.
      #
      class BaseFormatter
        # Produces a string suitable for writing to a sink
        #
        # @param  log_record  VCAP::Logging::LogRecord  Log record to be formatted
        # @return String
        def format_record(log_record)
          raise NotImplementedError
        end

        # The inverse of format_record()
        #
        # @param  message  String  A string formatted using format_record()
        # @return VCAP::Logging::LogRecord
        def parse_message(message)
          raise NotImplementedError
        end
      end

    end
  end
end
