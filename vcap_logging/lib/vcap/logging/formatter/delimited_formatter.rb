require 'vcap/logging/formatter/base_formatter'
require 'vcap/logging/log_record'

module VCAP::Logging::Formatter

  # A formatter for creating messages delimited by a given value (e.g. space separated logs)
  class DelimitedFormatter < BaseFormatter

    DEFAULT_DELIMITER = ' '

    attr_reader :timestamp_fmt

    def initialize(delim=DEFAULT_DELIMITER)
      @delim = delim
      if defined?(RUBY_VERSION) && RUBY_VERSION >= "1.9.2"
        @timestamp_fmt = '[%F %T.%6N]'
      else
        # Time#strftime on 1.8 doesn't do fractional seconds
        @timestamp_fmt = '[%F %T]'
      end
    end

    def format_record(log_record)
      line = [
       log_record.timestamp.strftime(@timestamp_fmt),            # Timestamp
       log_record.logger_name,                                   # Logger name
       log_record.tags.empty? ? '-' : log_record.tags.join(','), # Tags
       "pid=" + log_record.process_id.to_s,                      # Process id
       "tid=" + log_record.thread_shortid.to_s,                  # Thread id
       "fid=" + log_record.fiber_shortid.to_s,                   # Fiber id
       "%6s" % [log_record.log_level.to_s.upcase],               # Log level
       "--",                                                     # Separator
       format_data(log_record.data)].join(@delim)

      line.gsub(/\n/, '\\n') + "\n"
    end


    private

    def format_data(data)
      # Include the class name, message, and backtrace if the supplied datum
      # is an exception.
      formatted_data = nil
      if data.kind_of?(Exception)
        formatted_data = data.class.to_s + "<<" + data.to_s + ":"
        if backtrace = data.backtrace
          formatted_data += backtrace.join(',')
        end
        formatted_data += ">>"
      else
        # Replace invalid and undefined byte sequences so that any subsequent
        # string operations don't fail with 'invalid byte sequence...'
        formatted_data = data.to_s.encode('ASCII',
                                          :invalid => :replace,
                                          :undef   => :replace)
      end

      formatted_data
    end
  end

end
