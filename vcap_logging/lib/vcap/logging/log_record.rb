module VCAP
  module Logging

    class LogRecord
      attr_reader :data
      attr_reader :log_level
      attr_reader :tags

      def initialize(log_level, data, tags=[])
        @data      = data
        @log_level = log_level
        @tags      = tags
      end
    end

  end
end
