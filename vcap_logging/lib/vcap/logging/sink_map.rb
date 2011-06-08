require 'set'

module VCAP
  module Logging
    class SinkMap

      # @param  log_levels  Hash  Map of level_name => value
      def initialize(log_levels)
        @log_levels = log_levels
        @sinks      = {}
        for level in @log_levels.keys
          @sinks[level] = []
        end
      end

      # Adds a sink for all the levels in the supplied range
      #
      # Usage:
      #   add_sink(nil,   :debug, sink)  # Add a sink for all levels up to, and including, the :debug level
      #   add_sink(:info, :info,  sink)  # Add a sink for only the info level
      #   add_sink(:warn, nil,    sink)  # Add a sink for all levels :warn and greater
      #   add_sink(nil,   nil,    sink)  # Add a sink for all levels
      #
      # @param  start_level  Symbol    The most noisy level you want this sink to apply to. Use nil to set no restriction.
      # @param  end_level    Symbol    The least noisy level you want this sink to apply to. Use nil to set no restriction.
      # @param  sink         BaseSink  The sink to add
      def add_sink(start_level, end_level, sink)
        raise ArgumentError, "Unknown level #{start_level}" if start_level && !@log_levels.has_key?(start_level)
        raise ArgumentError, "Unknown level #{end_level}" if end_level && !@log_levels.has_key?(end_level)

        start_value = @log_levels[start_level]
        end_value   = @log_levels[end_level]

        for level, value in @log_levels
          next if start_value && (value > start_value)
          next if end_value && (value < end_value)
          @sinks[level] << sink
        end
      end

      # @param  level  :Symbol  Log level to retrieve sinks for
      # @return Array
      def get_sinks(level)
        @sinks[level]
      end

      def each_sink
        raise "You must supply a block" unless block_given?

        seen = Set.new
        for level, sinks in @sinks
          for sink in sinks
            next if seen.include?(sink)
            yield sink
            seen.add(sink)
          end
        end
      end
    end
  end
end

