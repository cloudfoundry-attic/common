require 'vcap/logging/error'
require 'vcap/logging/formatter'
require 'vcap/logging/log_record'
require 'vcap/logging/logger'
require 'vcap/logging/sink'
require 'vcap/logging/sink_map'
require 'vcap/logging/version'

module VCAP
  module Logging

    FORMATTER = VCAP::Logging::Formatter::DelimitedFormatter.new

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

      def init
        fail "init() can only be called once" if @initialized
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
        VCAP::Logging::Logger.define_log_levels(LOG_LEVELS)
        @default_log_level = pick_default_level(LOG_LEVELS)
        @sink_map = VCAP::Logging::SinkMap.new(LOG_LEVELS)
        @log_level_filters = {}
        @sorted_log_level_filters = []
        @loggers  = {}
      end

      def default_log_level=(log_level_name)
        log_level_name = log_level_name.to_sym if log_level_name.kind_of?(String)
        raise ArgumentError, "Unknown level #{log_level_name}" unless LOG_LEVELS[log_level_name]
        @default_log_level = log_level_name
      end

      # Configures the logging infrastructure using a hash parsed from a config file.
      # The config file is expected to contain a section with the following format:
      # logging:
      #    level: <default_log_level>
      #     file: <filename>
      #   syslog: <program name to use with the syslog sink>
      #
      # This interface is limiting, but it should satisfy the majority of our use cases.
      # I'm imagining usage will be something like:
      #   config = YAML.load(<file>)
      #   ...
      #   VCAP::Logging.setup_from_config(config[:logging])
      def setup_from_config(config={})
        level = config[:level] || config['level']
        if level
          level_sym = level.to_sym
          raise ArgumentError, "Unknown level: #{level}" unless LOG_LEVELS[level_sym]
          @default_log_level = level_sym
        end

        logfile = config[:file] || config['file']
        # Undecided as to whether or not we should enable buffering here. For now, don't buffer to stay consistent with the current logger.
        add_sink(nil, nil, VCAP::Logging::Sink::FileSink.new(logfile, FORMATTER)) if logfile

        syslog_name = config[:syslog] || config['syslog']
        add_sink(nil, nil, VCAP::Logging::Sink::SyslogSink.new(syslog_name, :formatter => FORMATTER)) if syslog_name

        # Log to stdout if no other sinks are supplied
        add_sink(nil, nil, VCAP::Logging::Sink::StdioSink.new(STDOUT, FORMATTER)) unless (logfile || syslog_name)
      end

      # Returns the logger associated with _name_. Creates one if it doesn't exist. The log level will be inherited
      # from the parent logger.
      #
      # @param  name  String  Logger name
      def logger(name)
        if !@loggers.has_key?(name)
          @loggers[name] = VCAP::Logging::Logger.new(name, @sink_map)
          @loggers[name].log_level = @default_log_level
          for level, regex in @sorted_log_level_filters
            if regex.match(name)
              @loggers[name].log_level = level
              break
            end
          end
        end

        @loggers[name]
      end

      def add_sink(*args)
        @sink_map.add_sink(*args)
      end

      # Sets the log level to _log_level_ for every logger whose name matches _path_regex_. Loggers who
      # were previously set to this level and whose names no longer match _path_regex_ are reset to
      # the default level.
      #
      # @param  path_regex      String  Regular expression to use when matching against the logger name
      # @param  log_level_name  Symbol  Name of the log level to set on all matching loggers
      def set_log_level(path_regex, log_level_name)
        log_level_name = log_level_name.to_sym if log_level_name.kind_of?(String)

        raise ArgumentError, "Unknown log level #{log_level_name}" unless LOG_LEVELS[log_level_name]
        regex = Regexp.new("^#{path_regex}$")

        @log_level_filters[log_level_name] = regex
        @sorted_log_level_filters = @log_level_filters.keys.sort {|a, b| LOG_LEVELS[a] <=> LOG_LEVELS[b] }.map {|lvl| [lvl, @log_level_filters[lvl]] }

        for logger_name, logger in @loggers
          if regex.match(logger_name)
            logger.log_level = log_level_name
          elsif logger.log_level == log_level_name
            # Reset any loggers at the supplied level that no longer match
            logger.log_level = @default_log_level
          end
        end
      end

      private

      # The middle level seems like a reasonable default
      def pick_default_level(level_map)
        sorted_levels = level_map.keys.sort {|a, b| level_map[a] <=> level_map[b] }
        sorted_levels[sorted_levels.length / 2]
      end

    end # << self
  end   # VCAP::Logging
end

VCAP::Logging.init
