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
      raw_data = nil

      if log_record.data.kind_of?(Exception)
        raw_data = format_exception(log_record.data)
      else
        raw_data = log_record.data.to_s
      end

      escaped_data = escape_data(raw_data)

      [log_record.timestamp.strftime(@timestamp_fmt),            # Timestamp
       log_record.logger_name,                                   # Logger name
       log_record.tags.empty? ? '-' : log_record.tags.join(','), # Tags
       "pid=" + log_record.process_id.to_s,                      # Process id
       "tid=" + log_record.thread_shortid.to_s,                  # Thread id
       "fid=" + log_record.fiber_shortid.to_s,                   # Fiber id
       "%6s" % [log_record.log_level.to_s.upcase],               # Log level
       "--",                                                     # Separator
       escaped_data].join(@delim) + "\n"
    end

    private

    # Includes the class name, message, and backtrace formatted as
    #
    # <<[Exception]:[Backtrace]>>
    #
    # @param [Exception] e
    #
    # @return [String]
    def format_exception(e)
      ret = e.class.to_s + "<<" + e.to_s + ":"

      ret += e.backtrace.join(',') if e.backtrace

      ret += ">>"

      ret
    end

    # Escapes carriage returns and newlines.
    #
    # NB: This will convert strings that contain invalid characters for their
    #     encodings to binary strings with hex-escaped non-printable
    #     characters.
    #
    # @param [String]  data  The string to be escaped.
    #
    # @return [String]
    def escape_data(data)
      unless data.valid_encoding?
        # Treat the line as an arbitrary sequence of bytes. Any invalid
        # character sequences for the original encoding will no longer cause
        # the next statements to blow up with "invalid byte sequence..."
        # errors.
        data = data.dup.force_encoding("BINARY")
        data = escape_nonprintable_ascii(data)
      end

      data.chars.map do |c|
        case c
        when "\n"
          "\\n"
        when "\r"
          "\\r"
        else
          c
        end
      end.join
    end

    # Hex encodes non-printable ascii characters.
    #
    # @param [String] data
    #
    # @return [String]
    def escape_nonprintable_ascii(data)
      data.chars.map do |c|
        ord_val = c.ord

        if (ord_val > 31) && (ord_val < 127)
          c
        else
          "\\x%02x" % [ord_val]
        end
      end.join
    end
  end
end
