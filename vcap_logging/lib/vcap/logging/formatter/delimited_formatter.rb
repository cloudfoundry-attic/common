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
      fmt_chars = (0...@exprs.length).map {|x| '%s' }
      fmt       = fmt_chars.join(delim)
      fmt_args  = @exprs.join(', ')

      instance_eval("def format_record(log_record); '#{fmt}' % [#{fmt_args}]; end")
    end

    private

    def log_level
      @exprs << "log_record.log_level.to_s.upcase"
    end

    def data
      @exprs << "log_record.data.to_s.gsub(/\n/, '\\n')"
    end

    def tags
      @exprs << "log_record.tags.join(',')"
    end

    def fiber_id
      @exprs << "log_record.fiber_id"
    end

    def fiber_shortid
      @exprs << "log_record.fiber_shortid"
    end

    def process_id
      @exprs << "log_record.process_id"
    end

    def thread_id
      @exprs << "log_record.thread_id"
    end

    def thread_shortid
      @exprs << "log_record.thread_shortid"
    end

    def timestamp(fmt=DEFAULT_TIMESTAMP_FORMAT)
      @exprs << "log_record.timestamp.strftime('#{fmt}')"
    end

  end

end
