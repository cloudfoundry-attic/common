require 'vcap/logging/formatter/base_formatter'
require 'vcap/logging/log_record'

module VCAP::Logging::Formatter

  # A formatter for creating messages delimited by a given value (e.g. space separated logs)
  class DelimitedFormatter < BaseFormatter

    DEFAULT_DELIMITER        = ' '
    DEFAULT_TIMESTAMP_FORMAT = '%F %T %z' # YYYY-MM-DD HH:MM:SS TZ

    # This provides a tiny DSL for constructing the formatting function. We opt
    # to define the method inline in order to avoid incurring multiple method calls
    # per call to format_record().
    #
    # Usage:
    #
    # formatter = VCAP::Logging::Formatter::DelimitedFormatter.new do
    #   timestamp '%s'
    #   log_level
    #   data
    # end
    #
    # @param  delim  String   Delimiter that will separate fields in the message
    # @param         Block    Block that defines the log message format
    def initialize(delim=DEFAULT_DELIMITER, &blk)
      @exprs = []

      # Collect the expressions we want to use when constructing messages in the
      # order that they should appear.
      instance_eval(&blk)

      # Build the format string to that will generate the message along with
      # the arguments
      fmt_chars = @exprs.map {|e| e[0] }
      fmt       = fmt_chars.join(delim) + "\n"
      fmt_args  = @exprs.map {|e| e[1] }.join(', ')

      instance_eval("def format_record(log_record); '#{fmt}' % [#{fmt_args}]; end")
    end

    private

    def log_level
      @exprs << ['%6s', "log_record.log_level.to_s.upcase"]
    end

    def data
      # Not sure of a better way to do this...
      # If we are given an exception, include the class name, string representation, and stacktrace
      snippet = "(log_record.data.kind_of?(Exception) ? " \
                + "log_record.data.class.to_s + '(\"' + log_record.data.to_s + '\", [' + (log_record.data.backtrace ? log_record.data.backtrace.join(',') : '') + '])'" \
                + ": log_record.data.to_s" \
                + ").gsub(/\n/, '\\n')"
      @exprs << ['%s', snippet]
    end

    def tags
      @exprs << ['%s', "log_record.tags.empty? ? '-': log_record.tags.join(',')"]
    end

    def fiber_id
      @exprs << ['%s', "log_record.fiber_id"]
    end

    def fiber_shortid
      @exprs << ['%s', "log_record.fiber_shortid"]
    end

    def process_id
      @exprs << ['%s', "log_record.process_id"]
    end

    def thread_id
      @exprs << ['%s', "log_record.thread_id"]
    end

    def thread_shortid
      @exprs << ['%s', "log_record.thread_shortid"]
    end

    def timestamp(fmt=DEFAULT_TIMESTAMP_FORMAT)
      @exprs << ['%s', "log_record.timestamp.strftime('#{fmt}')"]
    end

    def logger_name
      @exprs << ['%s', "log_record.logger_name"]
    end

    def text(str)
      @exprs << ['%s', "'#{str}'"]
    end

  end

end
