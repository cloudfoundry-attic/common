module VCAP::Logging::Sink

  # A sink for writing to a file. Buffering is supported, but disabled by default.
  class FileSink < BaseSink

    attr_reader :filename

    class MessageBuffer
      attr_reader :size
      attr_accessor :max_buffer_size

      def initialize(buffer_size)
        @max_buffer_size = buffer_size
        @buffer = []
        @size   = 0
      end

      def append(msg)
        @buffer << msg
        @size += msg.length
      end

      def compact
        return nil unless @size > 0
        ret = @buffer.join
        @buffer = []
        @size = 0
        ret
      end

      def full?
        @size >= @max_buffer_size
      end

      def empty?
        @size == 0
      end
    end

    # @param  filename  String         Pretty obvious...
    # @param  formatter BaseFormatter  Formatter to use when generating log messages
    # @param  opts      Hash           :buffer_size  =>  Size (in bytes) to buffer in memory before flushing to disk
    #
    def initialize(filename, formatter=nil, opts={})
      super(formatter)

      @filename = filename
      @file     = nil
      if opts[:buffer_size] && (Integer(opts[:buffer_size]) > 0)
        @buffer = MessageBuffer.new(opts[:buffer_size])
      else
        @buffer = nil
      end
      open()
    end

    # Missing Python's decorators pretty badly here. Even guards would be better than the existing solution.
    # Alas, ruby has no real destructors.

    def open
      @mutex.synchronize do
        if !@opened
          @file = File.new(@filename, 'a+')
          @file.sync = true
          @opened = true
        end
      end
    end

    def close
      @mutex.synchronize do
        if @opened
          perform_write(@buffer.compact) if @buffer && !@buffer.empty?
          @file.close
          @file = nil
          @opened = false
        end
      end
    end

    def flush
      @mutex.synchronize do
        perform_write(@buffer.compact) if @buffer && !@buffer.empty?
      end
    end

    private

    def write(message)
      @mutex.synchronize do
        if @buffer
          @buffer.append(message)
          perform_write(@buffer.compact) if @buffer.full?
        else
          perform_write(message)
        end
      end
    end

    def perform_write(message)
      bytes_left = message.length
      begin
        while bytes_left > 0
          written = @file.syswrite(message)
          bytes_left -= written
          message = message[written, message.length - written] if bytes_left
        end
      rescue Errno::EINTR
          # This can only happen if the write is interrupted before any data is written.
          # If a partial write occurs due to an interrupt write(2) will return the number of bytes written
          # instead of -1.
          #
          # The rest of the exceptions that syswrite() can throw cannot be recovered from,
          # and should be propagated up the stack. (See `man 2 write`.)
          retry
      end
    end
  end

end
