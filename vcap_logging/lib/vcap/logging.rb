require 'thread'

module VCAP
  module Logging

    class LoggingError < StandardError; end

    DEFAULT_DELIMITER = '.'

    DEFAULT_LOG_LEVELS = {
      :fatal  => 0,
      :error  => 5,
      :warn   => 10,
      :info   => 15,
      :debug  => 16,
      :debug1 => 17,
      :debug2 => 18,
    }

    class << self

      attr_accessor :default_log_level
      attr_reader   :log_level_map
      attr_reader   :sink_map

      # Sets up the logging infrastructure
      #
      # @param  opts  Hash  :log_levels        => Hash    log-levels along with their names
      #                     :default_log_level => Symbol  The log level to use if the logger has no parent in the hierarchy
      #                     :delimiter         => String  Defines how names should be split in determining logger hierarchy
      #
      def init(opts={})
        @log_level_map = opts[:log_levels] || DEFAULT_LOG_LEVELS
        @delimiter = opts[:delimiter]  || DEFAULT_DELIMITER
        if opts[:default_log_level]
          @default_log_level = opts[:default_log_level]
        else
          # The middle level seems like a reasonable default for the root logger
          sorted_levels = @log_level_map.keys.sort {|a, b| @log_level_map[a] <=> @log_level_map[b] }
          @default_log_level = sorted_levels[sorted_levels.length / 2]
        end

        VCAP::Logging::Logger.define_log_levels(@log_level_map)
        @sink_map = VCAP::Logging::SinkMap.new(@log_level_map)
        @loggers  = {}
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
          off = name.rindex(@delimiter)
          while off != nil
            substr = name[0, off]
            if @loggers[substr]
              log_level = @loggers[substr].log_level
              break
            end
            off = off > 2 ? name.rindex(@delimiter, off - 1) : nil
          end
          @loggers[name].log_level = log_level
        end

        @loggers[name]
      end

      # Sets the log level to _log_level_ for every logger whose name matches _path_regex_
      #
      # @param  path_regex      String  Regular expression to use when matching against the logger name
      # @param  log_level_name  Symbol  Name of the log level to set on all matching loggers
      def set_log_level(path_regex, log_level_name)
        log_level_name = log_level_name.to_sym if log_level_name.kind_of?(String)

        raise ArgumentError, "Unknown log level #{log_level_name}" unless @log_level_map[log_level_name]
        regex = Regexp.new("^#{path_regex}$")

        for logger_name, logger in @loggers
          logger.log_level = log_level_name if regex.match(logger_name)
        end
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
