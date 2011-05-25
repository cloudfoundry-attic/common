require 'digest/md5'
require 'thread'

module VCAP
  module Logging

    class LogRecord

      @@have_fibers = nil

      class << self

        def have_fibers?
          if @@have_fibers == nil
            begin
              require 'fiber'
              @@have_fibers = true
            rescue LoadError
              @@have_fibers = false
            end
          else
            @@have_fibers
          end
        end

        def current_fiber_id
          if have_fibers?
            Fiber.current.object_id
          else
            nil
          end
        end

      end

      attr_reader :timestamp
      attr_reader :data
      attr_reader :log_level
      attr_reader :logger_name
      attr_reader :tags
      attr_reader :thread_id
      attr_reader :thread_shortid
      attr_reader :fiber_id
      attr_reader :fiber_shortid
      attr_reader :process_id

      def initialize(log_level, data, logger, tags=[])
        @timestamp   = Time.now
        @data        = data
        @logger_name = logger.name
        @log_level   = log_level
        @tags        = tags

        @thread_id      = Thread.current.object_id
        @thread_shortid = shortid(@thread_id)
        @fiber_id       = LogRecord.current_fiber_id
        @fiber_shortid  = @fiber_id ? shortid(@fiber_id) : nil
        @process_id     = Process.pid
      end

      private

      def shortid(data, len=4)
        digest = Digest::MD5.hexdigest(data.to_s)
        len = len > digest.length ? digest.length : len
        digest[0, len]
      end

    end # VCAP::Logging::LogRecord
  end
end
