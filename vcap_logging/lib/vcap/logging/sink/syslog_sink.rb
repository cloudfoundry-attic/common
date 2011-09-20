require 'syslog'

require 'vcap/logging/sink/base_sink'

module VCAP::Logging::Sink

  # A sink for logging messages to the local syslog server.
  # NB: The ruby syslog module is a thin wrapper around glibc syslog(). It will first
  #     attempt to open a unix stream socket to '/dev/log', and upon failure will attempt
  #     to open a unix datagram socket there. Make sure you configure your syslog server
  #     to use the appropriate type (probably dgram in our case).
  #
  #     Beware that all messages will be silently lost if the syslog server goes away.
  class SyslogSink < BaseSink

    DEFAULT_LOG_LEVEL_MAP = {
      :fatal  => Syslog::LOG_CRIT,
      :error  => Syslog::LOG_ERR,
      :warn   => Syslog::LOG_WARNING,
      :info   => Syslog::LOG_INFO,
      :debug  => Syslog::LOG_DEBUG,
      :debug1 => Syslog::LOG_DEBUG,
      :debug2 => Syslog::LOG_DEBUG,
    }

    # @param  prog_name  String  Program name to identify lines logged to syslog
    # @param  opts       Hash    :log_level_map  Map of log level => syslog level
    #                            :formatter      LogFormatter
    def initialize(prog_name, opts={})
      super(opts[:formatter])

      @prog_name     = prog_name
      @log_level_map = opts[:log_level_map] || DEFAULT_LOG_LEVEL_MAP
      @syslog        = nil
      open
    end

    def open
      @mutex.synchronize do
        unless @opened
          @syslog = Syslog.open(@prog_name, Syslog::LOG_PID, Syslog::LOG_USER)
          @opened = true
        end
      end
    end

    def close
      @mutex.synchronize do
        if @opened
          @syslog.close
          @syslog = nil
          @opened = false
        end
      end
    end

    def add_record(log_record)
      raise UsageError, "You cannot add a record until the sink has been opened" unless @opened
      raise UsageError, "You must supply a formatter" unless @formatter

      message = @formatter.format_record(log_record)
      pri = @log_level_map[log_record.log_level]
      @mutex.synchronize { @syslog.log(pri, '%s', message) }
    end

  end
end
