require 'thread'

module VCAP
  module Logging

    class LoggingError < StandardError; end

    DEFAULT_LOG_LEVELS = {
      :fatal  => 6,
      :error  => 5,
      :warn   => 4,
      :info   => 3,
      :debug2 => 2,
      :debug1 => 1,
      :debug  => 0,
    }

    @@log_level_map   = nil
    @@logger_trie = nil
    @@root_logger = nil

    class << self

      def root_logger
        @@root_logger
      end

      # Sets up the logging infrastructure
      #
      # @param  opts  Hash  :log_levels => VCAP::Logging::LogLevelMap  Defines log-levels along with their names
      #                     :delimeter  => String                      Defines how names should be split in determining logger hierarchy
      #
      def setup(opts={})
        @@log_level_map = opts[:log_levels] || DEFAULT_LOG_LEVELS
        delimeter = opts[:delimeter]  || '.'

        VCAP::Logging::Logger.define_log_levels(@@log_level_map)

        @@root_logger = VCAP::Logging::Logger.new(nil, nil)
        # The middle level seems like a reasonable default for the root logger
        sorted_levels = @@log_level_map.keys.sort {|a, b| @@log_level_map[a] <=> @@log_level_map[b] }
        @@root_logger.log_level = sorted_levels[sorted_levels.length / 2]

        @@logger_trie = VCAP::Logging::Trie.new(delimeter, @@root_logger)
      end

      # Returns the logger associated with _name_. Creates one if it doesn't exist. The log level will be inherited
      # from the parent logger.
      #
      # @param  name  String  Logger name
      def logger(name)
        VCAP::Logging.assert_kind_of('name', name, String)

        existing_logger = @@logger_trie.get(name)
        if existing_logger
          existing_logger
        else
          new_logger = VCAP::Logging::Logger.new(name)
          @@logger_trie.put(name, new_logger)
          _, parent_logger  = @@logger_trie.get_parent(name)
          new_logger.parent = parent_logger
          new_logger.log_level = parent_logger.log_level

          # We may have added a logger at an interior node. Update
          # any loggers that may be children of the new logger.
          @@logger_trie.map_children(name) {|child_name, child_logger| child_logger.parent = new_logger }

          new_logger
        end
      end

      # Sets the log level to _log_level_ for every logger whose name matches _path_regex_
      #
      # @param  path_regex      String  Regular expression to use when matching against the logger name
      # @param  log_level_name  Symbol  Name of the log level to set on all matching loggers
      def set_log_level(path_regex, log_level_name)
        VCAP::Logging.assert_kind_of('path_regex', path_regex, String)
        case log_level_name
        when String
          log_level_name = log_level_name.to_sym
        when Symbol
        else
          raise ArgumentError, "log_level_name must be either a String or Symbol"
        end

        raise ArgumentError, "Unknown log level #{log_level_name}" unless @@log_level_map[log_level_name]
        regex = Regexp.new("^#{path_regex}$")

        @@logger_trie.map_descendents {|name, logger| logger.log_level = log_level_name if regex.match(name) }
      end

    end
  end
end

require 'vcap/logging/formatter'
require 'vcap/logging/log_record'
require 'vcap/logging/logger'
require 'vcap/logging/sink'
require 'vcap/logging/trie'
require 'vcap/logging/version'

VCAP::Logging.setup
