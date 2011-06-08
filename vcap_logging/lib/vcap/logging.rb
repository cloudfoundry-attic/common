require 'thread'

module VCAP
  module Logging

    class LoggingError < StandardError; end

    DELIMITER = '.'

    LOG_LEVELS = {
      :off    => 0,
      :fatal  => 1,
      :error  => 5,
      :warn   => 10,
      :info   => 15,
      :debug  => 16,
      :debug1 => 17,
      :debug2 => 18,
    }

    class << self

      attr_reader :default_log_level

      # Sets up the logging infrastructure
      def init
        fail "init() can only be called once" if @initialized
        VCAP::Logging::Logger.define_log_levels(LOG_LEVELS)
        reset

        # Ideally we would call close() on each sink. Unfortunatley, we can't be sure
        # that close runs last, and that other at_exit handlers aren't attempting to
        # log to a sink. The best we can do is enable autoflushing.
        at_exit do
          @sink_map.each_sink {|s| s.autoflush = true }
        end

        @initialized = true
      end

      # Exists primarily for testing
      def reset
        @default_log_level = pick_default_level(LOG_LEVELS)
        @sink_map = VCAP::Logging::SinkMap.new(LOG_LEVELS)
        @loggers  = {}
      end

      def default_log_level=(log_level_name)
        log_level_name = log_level_name.to_sym if log_level_name.kind_of?(String)
        raise ArgumentError, "Unknown level #{log_level_name}" unless LOG_LEVELS[log_level_name]
        @default_log_level = log_level_name
      end

      # Returns the logger associated with _name_. Creates one if it doesn't exist. The log level will be inherited
      # from the parent logger.
      #
      # @param  name  String  Logger name
      def logger(name)
        if !@loggers.has_key?(name)
          @loggers[name] = VCAP::Logging::Logger.new(name, @sink_map)

          # Not super efficient, but since we're not explicitly storing the parent-child relationships we
          # must brute force it.
          log_level = @default_log_level
          off = name.rindex(DELIMITER)
          while off != nil
            substr = name[0, off]
            if @loggers[substr]
              log_level = @loggers[substr].log_level
              break
            end
            off = off > 2 ? name.rindex(DELIMITER, off - 1) : nil
          end
          @loggers[name].log_level = log_level
        end

        @loggers[name]
      end

      def add_sink(*args)
        @sink_map.add_sink(*args)
      end

      # Sets the log level to _log_level_ for every logger whose name matches _path_regex_
      #
      # @param  path_regex      String  Regular expression to use when matching against the logger name
      # @param  log_level_name  Symbol  Name of the log level to set on all matching loggers
      def set_log_level(path_regex, log_level_name)
        log_level_name = log_level_name.to_sym if log_level_name.kind_of?(String)

        raise ArgumentError, "Unknown log level #{log_level_name}" unless LOG_LEVELS[log_level_name]
        regex = Regexp.new("^#{path_regex}$")

        for logger_name, logger in @loggers
          logger.log_level = log_level_name if regex.match(logger_name)
        end
      end

      private

      # The middle level seems like a reasonable default
      def pick_default_level(level_map)
        sorted_levels = level_map.keys.sort {|a, b| level_map[a] <=> level_map[b] }
        sorted_levels[sorted_levels.length / 2]
      end

    end
  end
end

require 'vcap/logging/formatter'
require 'vcap/logging/log_record'
require 'vcap/logging/logger'
require 'vcap/logging/sink'
require 'vcap/logging/sink_map'
require 'vcap/logging/version'

VCAP::Logging.init
