require 'vcap/logging/log_record'
require 'vcap/logging/util'

module VCAP
  module Logging
    class Logger

      # Loggers are responsible for dispatching log messages to an appropriate
      # sink. If no sinks are configured for a logger, the message will be forwarded
      # to the parent logger who repeats the process.

      @@prev_log_methods = []
      @@log_levels       = {}

      LogLevel = Struct.new(:name, :value)

      class << self

        # Defines convenience methods for each log level. For example, if 'debug' is the name of a level
        # corresponding 'debug' and 'debugf' instance methods will be defined for all loggers.
        #
        # @param  levels  Array[VCAP::Logging::LogLevel]  Log levels to use
        def define_log_levels(levels)
          VCAP::Logging.assert_kind_of('levels', levels, Hash)
          for name, level in levels
            VCAP::Logging.assert_kind_of('name', name, Symbol)
            VCAP::Logging.assert_kind_of('level', level, Integer)
          end

          # Clean up previously defined methods
          for meth_name in @@prev_log_methods
            undef_method(meth_name)
          end

          @@prev_log_methods = []
          @@log_levels       = {}

          # Partially evaluate log/logf for the level specified by each name
          # 1.8.7 doesn't have optional block arguments, hence the use of class_eval() instead of define_method()
          for name, level in levels
            @@log_levels[name] = LogLevel.new(name, level)

            class_eval("def #{name}(data, opts={}); log(:#{name}, data, opts); end")
            @@prev_log_methods << name

            name_f = name.to_s + 'f'
            class_eval("def #{name_f}(fmt, fmt_args, opts={}); logf(:#{name}, fmt, fmt_args, opts); end")
            @@prev_log_methods << name_f.to_sym
          end
        end

      end

      attr_reader   :name
      attr_accessor :parent
      attr_reader   :sinks

      def initialize(name, parent=nil)
        @name   = name
        @parent = parent
        @sinks  = []
      end

      def log_level
        @log_level.name
      end

      def log_level=(lvl_name)
        VCAP::Logging.assert_kind_of('lvl_name', lvl_name, Symbol)

        level = @@log_levels[lvl_name]
        raise ArgumentError, "Unknown level #{lvl_name}" unless level
        @log_level = level

        self
      end

      def add_sink(sink)
        @sinks << sink
        self
      end

      # Logs a message to the configured sinks. You may optionally supply a block to be called; its return value
      # will be used as data for the log record.
      #
      # @param  lvl_name  Symbol  Log level for the associated message
      # @param  data      Object      Optional data to log. How this is converted to a string is determined by the formatters.
      # @param  opts      Hash      :tags => Array[String]  Tags to associated with this log message
      def log(lvl_name, data=nil, opts={})
        VCAP::Logging.assert_kind_of('lvl_name', lvl_name, Symbol)
        VCAP::Logging.assert_kind_of(':tags', opts[:tags], Array) if opts[:tags]
        raise ArgumentError, "You must supply either an object to log or a block that returns data" if (data == nil) && (!block_given?)

        level = @@log_levels[lvl_name]
        raise ArgumentError, "Unknown level #{lvl_name}" unless level

        return unless level.value >= @log_level.value
        data = yield if block_given?

        log_record(VCAP::Logging::LogRecord.new(lvl_name, data, opts[:tags] || []))
      end

      # Logs a message to the configured sinks. This is analogous to the printf() family
      #
      # @param  lvl_name  Symbol  Log level for the associated message
      # @param  fmt       String  Format string to use when formatting the message
      # @param  fmt_args  Array   Arguments to format string
      # @param  opts      Hash    See log()
      def logf(lvl_name, fmt, fmt_args, opts={})
        VCAP::Logging.assert_kind_of('lvl_name', lvl_name, Symbol)
        VCAP::Logging.assert_kind_of('fmt', fmt, String)
        VCAP::Logging.assert_kind_of('fmt_args', fmt_args, Array)

        level = @@log_levels[lvl_name]
        raise ArgumentError, "Unknown level #{lvl_name}" unless level

        return unless level.value >= @log_level.value
        data = fmt % fmt_args

        log_record(VCAP::Logging::LogRecord.new(lvl_name, data, opts[:tags] || []))
      end

      protected

      def log_record(rec)
        VCAP::Logging::assert_kind_of('rec', rec, VCAP::Logging::LogRecord)

        if @sinks.length > 0
          for sink in @sinks
            sink.add_record(rec)
          end
        else
          @parent.log_record(rec)
        end
      end

    end
  end
end
