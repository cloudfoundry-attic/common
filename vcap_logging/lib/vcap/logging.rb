require 'vcap/logging/error'
require 'vcap/logging/formatter'
require 'vcap/logging/log_record'
require 'vcap/logging/logger'
require 'vcap/logging/sink'
require 'vcap/logging/sink_map'
require 'vcap/logging/version'

module VCAP
  module Logging
    DEFAULT_DELIMITER = '.'

    DEFAULT_FORMATTER = VCAP::Logging::Formatter::DelimitedFormatter.new do
      timestamp '%s'
      log_level
      tags
      process_id
      thread_id
      data
    end

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
        @delimiter     = opts[:delimiter]  || DEFAULT_DELIMITER
        @log_level_map = opts[:log_levels] || DEFAULT_LOG_LEVELS
        if opts[:default_log_level]
          @default_log_level = opts[:default_log_level]
        else
          # The middle level seems like a reasonable default level
          sorted_levels = @log_level_map.keys.sort {|a, b| @log_level_map[a] <=> @log_level_map[b] }
          @default_log_level = sorted_levels[sorted_levels.length / 2]
        end

        VCAP::Logging::Logger.define_log_levels(@log_level_map)
        @sink_map = VCAP::Logging::SinkMap.new(@log_level_map)
        @log_level_filters = {}         # map of level => regex that specifies which loggers should be at that level
        @sorted_log_level_filters = []  # [[level, filter]] sorted by level strictness, most strict first
        @loggers  = {}
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
          raise ArgumentError, "Unknown level: #{level}" unless @log_level_map[level_sym]
          @default_log_level = level_sym
        end

        logfile = config[:file] || config['file']
        add_sink(nil, nil, VCAP::Logging::Sink::FileSink.new(logfile, DEFAULT_FORMATTER, :buffer_size => 512)) if logfile

        syslog_name = config[:syslog] || config['syslog']
        add_sink(nil, nil, VCAP::Logging::Sink::SyslogSink.new(syslog_name, :formatter => DEFAULT_FORMATTER)) if syslog_name

        # Log to stdout if no other sinks are supplied
        add_sink(nil, nil, VCAP::Logging::Sink::StdioSink.new(STDOUT, DEFAULT_FORMATTER)) unless (logfile || syslog_name)
      end

      # Returns the logger associated with _name_. Creates one if it doesn't exist. The log level is computed
      # by checking the masks set using VCAP::Logging.set_log_level in order from most restrictive to
      # least restrictive.
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

        raise ArgumentError, "Unknown log level #{log_level_name}" unless @log_level_map[log_level_name]
        regex = Regexp.new("^#{path_regex}$")

        @log_level_filters[log_level_name] = regex
        @sorted_log_level_filters = @log_level_filters.keys.sort {|a, b| @log_level_map[a] <=> @log_level_map[b] }.map {|lvl| [lvl, @log_level_filters[lvl]] }

        for logger_name, logger in @loggers
          if regex.match(logger_name)
            logger.log_level = log_level_name
          elsif logger.log_level == log_level_name
            # Reset any loggers at the supplied level that no longer match
            logger.log_level = @default_log_level
          end
        end
      end

    end # << self
  end # VCAP::Logging
end

VCAP::Logging.init
