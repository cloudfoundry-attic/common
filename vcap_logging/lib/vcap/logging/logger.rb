require 'vcap/logging/log_record'

module VCAP
  module Logging
    class Logger

      # Loggers are responsible for dispatching log messages to an appropriate
      # sink.

      LogLevel = Struct.new(:name, :value)

      class << self
        attr_reader :log_levels

        # Defines convenience methods for each log level. For example, if 'debug' is the name of a level
        # corresponding 'debug' and 'debugf' instance methods will be defined for all loggers.
        #
        # @param  levels  Array[VCAP::Logging::LogLevel]  Log levels to use
        def define_log_levels(levels)

          @prev_log_methods ||= []
          # Clean up previously defined methods
          for meth_name in @prev_log_methods
            undef_method(meth_name)
          end

          @prev_log_methods = []
          @log_levels       = {}

          # Partially evaluate log/logf for the level specified by each name
          # 1.8.7 doesn't have optional block arguments, hence the use of class_eval() instead of define_method()
          for name, level in levels
            @log_levels[name] = LogLevel.new(name, level)

            class_eval("def #{name}(data, opts={}); log(:#{name}, data, opts); end")
            @prev_log_methods << name

            name_f = name.to_s + 'f'
            class_eval("def #{name_f}(fmt, fmt_args, opts={}); logf(:#{name}, fmt, fmt_args, opts); end")
            @prev_log_methods << name_f.to_sym
          end
        end

      end

      attr_reader   :name
      attr_accessor :sink_map

      def initialize(name, sink_map)
        @name = name
        @sink_map = sink_map
      end

      def log_level
        @log_level.name
      end

      def log_level=(lvl_name)
        level = self.class.log_levels[lvl_name]
        raise ArgumentError, "Unknown level #{lvl_name}" unless level
        @log_level = level

        self
      end

      # Logs a message to the configured sinks. You may optionally supply a block to be called; its return value
      # will be used as data for the log record.
      #
      # @param  lvl_name  Symbol  Log level for the associated message
      # @param  data      Object      Optional data to log. How this is converted to a string is determined by the formatters.
      # @param  opts      Hash      :tags => Array[String]  Tags to associated with this log message
      def log(lvl_name, data=nil, opts={})
        level = self.class.log_levels[lvl_name]
        raise ArgumentError, "Unknown level #{lvl_name}" unless level

        return unless level.value <= @log_level.value
        data = yield if block_given?

        rec = VCAP::Logging::LogRecord.new(lvl_name, data, self, opts[:tags] || [])
        @sink_map.get_sinks(lvl_name).each {|s| s.add_record(rec) }
      end

      # Logs a message to the configured sinks. This is analogous to the printf() family
      #
      # @param  lvl_name  Symbol  Log level for the associated message
      # @param  fmt       String  Format string to use when formatting the message
      # @param  fmt_args  Array   Arguments to format string
      # @param  opts      Hash    See log()
      def logf(lvl_name, fmt, fmt_args, opts={})
        level = self.class.log_levels[lvl_name]
        raise ArgumentError, "Unknown level #{lvl_name}" unless level

        return unless level.value <= @log_level.value
        data = fmt % fmt_args

        rec = VCAP::Logging::LogRecord.new(level, data, self, opts[:tags] || [])
        @sink_map.get_sinks(lvl_name).each {|s| s.add_record(rec) }
      end

    end # VCAP::Logging::Logger
  end
end
