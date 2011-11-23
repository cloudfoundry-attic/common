require 'eventmachine'
require 'posix/spawn'

module EventMachine

  module POSIX

    module Spawn

      include ::POSIX::Spawn

      class Child

        include Spawn
        include Deferrable

        # Spawn a new process, write all input and read all output. Supports
        # the standard spawn interface as described in the POSIX::Spawn module
        # documentation:
        #
        #   new([env], command, [argv1, ...], [options])
        #
        # The following options are supported in addition to the standard
        # POSIX::Spawn options:
        #
        #   :input   => str      Write str to the new process's standard input.
        #   :timeout => int      Maximum number of seconds to allow the process
        #                        to execute before aborting with a TimeoutExceeded
        #                        exception.
        #   :max     => total    Maximum number of bytes of output to allow the
        #                        process to generate before aborting with a
        #                        MaximumOutputExceeded exception.
        #
        # Returns a new Child instance that is being executed. The object
        # includes the Deferrable module, and executes the success callback
        # when the process has exited, or the failure callback when the process
        # was killed because of exceeding the timeout, or exceeding the maximum
        # number of bytes to read from stdout and stderr combined. Once the
        # success callback is triggered, this objects's out, err and status
        # attributes are available.
        def initialize(*args)
          @env, @argv, options = extract_process_spawn_arguments(*args)
          @options = options.dup
          @input = @options.delete(:input)
          @timeout = @options.delete(:timeout)
          @max = @options.delete(:max)
          @options.delete(:chdir) if @options[:chdir].nil?
          exec!
        end

        # All data written to the child process's stdout stream as a String.
        attr_reader :out

        # All data written to the child process's stderr stream as a String.
        attr_reader :err

        # A Process::Status object with information on how the child exited.
        attr_reader :status

        # Total command execution time (wall-clock time)
        attr_reader :runtime

        # Determine if the process did exit with a zero exit status.
        def success?
          @status && @status.success?
        end

        # Send the SIGTERM signal to the process.
        #
        # Returns the Process::Status object obtained by reaping the process.
        def kill
          ::Process.kill('TERM', @pid) rescue nil
          reap
        end

        private

        # Wait for the child process to exit
        #
        # Returns the Process::Status object obtained by reaping the process.
        def reap
          @timer.cancel if @timer
          ::Process::waitpid(@pid)
          @runtime = Time.now - @start
          @status = $?
        end

        # Execute command, write input, and read output. This is called
        # immediately when a new instance of this object is initialized.
        def exec!
          # spawn the process and hook up the pipes
          @pid, stdin, stdout, stderr = popen4(@env, *(@argv + [@options]))
          @start = Time.now

          # watch fds
          cin = EM.watch stdin, WritableStream, @input.dup if @input
          cout = EM.watch stdout, ReadableStream, ''
          cerr = EM.watch stderr, ReadableStream, ''

          # register events
          cin.notify_writable = true if cin
          cout.notify_readable = true
          cerr.notify_readable = true

          # keep track of open fds
          in_flight = [cin, cout, cerr].compact
          finalize = lambda { |io|
            in_flight.delete(io)
            if in_flight.empty?
              @out = cout.buffer
              @err = cerr.buffer

              reap
              set_deferred_success
            end
          }

          in_flight.each { |io|
            # force binary encoding
            io.force_encoding

            # register finalize hook
            io.callback { finalize.call(io) }
          }

          # keep track of max output
          max = @max
          if max && max > 0
            check_buffer_size = lambda {
              if cout.buffer.size + cerr.buffer.size > max
                in_flight.each(&:close)

                kill
                set_deferred_failure MaximumOutputExceeded
              end
            }

            cout.after_read(&check_buffer_size)
            cerr.after_read(&check_buffer_size)
          end

          # kill process when it doesn't terminate in time
          timeout = @timeout
          if timeout && timeout > 0
            @timer = Timer.new(timeout) {
              in_flight.each(&:close)

              kill
              set_deferred_failure TimeoutExceeded
            }
          end
        end

        class Stream < Connection

          include Deferrable

          attr_reader :buffer

          def initialize(buffer)
            @buffer = buffer
          end

          def force_encoding
            if @buffer.respond_to?(:force_encoding)
              @io.set_encoding('BINARY', 'BINARY')
              @buffer.force_encoding('BINARY')
            end
          end

          def after_read(&blk)
            @after_read = blk if blk
            @after_read
          end

          def after_write(&blk)
            @after_write = blk if blk
            @after_write
          end

          def close
            @io.close rescue nil
            detach
          end
        end

        class ReadableStream < Stream

          # Maximum buffer size for reading
          BUFSIZE = (32 * 1024)

          def notify_readable
            begin
              @buffer << @io.readpartial(BUFSIZE)
              @after_read.call if @after_read
            rescue Errno::EAGAIN, Errno::EINTR
            rescue EOFError
              close
              set_deferred_success
            end
          end
        end

        class WritableStream < Stream

          def notify_writable
            begin
              boom = nil
              size = @io.write_nonblock(@buffer)
              @buffer = @buffer[size, @buffer.size]
              @after_write.call if @after_write
            rescue Errno::EPIPE => boom
            rescue Errno::EAGAIN, Errno::EINTR
            end
            if boom || @buffer.size == 0
              close
              set_deferred_success
            end
          end
        end
      end
    end
  end
end
