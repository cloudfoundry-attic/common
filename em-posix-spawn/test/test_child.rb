# coding: UTF-8

require 'test/unit'
require 'em/posix/spawn/child'

module Helpers

  def em(options = {})
    raise "no block given" unless block_given?
    timeout = options[:timeout] ||= 1.0

    ::EM.run do
      quantum = 0.005
      ::EM.set_quantum(quantum * 1000) # Lowest possible timer resolution
      ::EM.set_heartbeat_interval(quantum) # Timeout connections asap
      ::EM.add_timer(timeout) { raise "timeout" }
      yield
    end
  end

  def done
    raise "reactor not running" if !::EM.reactor_running?

    ::EM.next_tick do
      # Assert something to show a spec-pass
      assert true
      ::EM.stop_event_loop
    end
  end
end

class ChildTest < Test::Unit::TestCase

  include ::EM::POSIX::Spawn
  include Helpers

  def test_sanity
    assert_same ::EM::POSIX::Spawn::Child, Child
  end

  def test_argv_string_uses_sh
    em do
      p = Child.new("echo via /bin/sh")
      p.callback do
        assert p.success?
        assert_equal "via /bin/sh\n", p.out
        done
      end
    end
  end

  def test_stdout
    em do
      p = Child.new('echo', 'boom')
      p.callback do
        assert_equal "boom\n", p.out
        assert_equal "", p.err
        done
      end
    end
  end

  def test_stderr
    em do
      p = Child.new('echo boom 1>&2')
      p.callback do
        assert_equal "", p.out
        assert_equal "boom\n", p.err
        done
      end
    end
  end

  def test_status
    em do
      p = Child.new('exit 3')
      p.callback do
        assert !p.status.success?
        assert_equal 3, p.status.exitstatus
        done
      end
    end
  end

  def test_env
    em do
      p = Child.new({ 'FOO' => 'BOOYAH' }, 'echo $FOO')
      p.callback do
        assert_equal "BOOYAH\n", p.out
        done
      end
    end
  end

  def test_chdir
    em do
      p = Child.new("pwd", :chdir => File.dirname(Dir.pwd))
      p.callback do
        assert_equal File.dirname(Dir.pwd) + "\n", p.out
        done
      end
    end
  end

  def test_input
    input = "HEY NOW\n" * 100_000 # 800K

    em do
      p = Child.new('wc', '-l', :input => input)
      p.callback do
        assert_equal 100_000, p.out.strip.to_i
        done
      end
    end
  end

  def test_max
    em do
      p = Child.new('yes', :max => 100_000)
      p.callback { fail }
      p.errback do |err|
        assert_equal MaximumOutputExceeded, err
        done
      end
    end
  end

  def test_max_with_child_hierarchy
    em do
      p = Child.new('/bin/sh', '-c', 'yes', :max => 100_000)
      p.callback { fail }
      p.errback do |err|
        assert_equal MaximumOutputExceeded, err
        done
      end
    end
  end

  def test_max_with_stubborn_child
    em do
      p = Child.new("trap '' TERM; yes", :max => 100_000)
      p.callback { fail }
      p.errback do |err|
        assert_equal MaximumOutputExceeded, err
        done
      end
    end
  end

  def test_timeout
    em do
      start = Time.now
      p = Child.new('sleep', '1', :timeout => 0.05)
      p.callback { fail }
      p.errback do |err|
        assert_equal TimeoutExceeded, err
        assert (Time.now-start) <= 0.2
        done
      end
    end
  end

  def test_timeout_with_child_hierarchy
    em do
      p = Child.new('/bin/sh', '-c', 'sleep 1', :timeout => 0.05)
      p.callback { fail }
      p.errback do |err|
        assert_equal TimeoutExceeded, err
        done
      end
    end
  end

  def test_lots_of_input_and_lots_of_output_at_the_same_time
    input = "stuff on stdin \n" * 1_000
    command = "
      while read line
      do
        echo stuff on stdout;
        echo stuff on stderr 1>&2;
      done
    "

    em do
      p = Child.new(command, :input => input)
      p.callback do
        assert_equal input.size, p.out.size
        assert_equal input.size, p.err.size
        assert p.success?
        done
      end
    end
  end

  def test_input_cannot_be_written_due_to_broken_pipe
    input = "1" * 100_000

    em do
      p = Child.new('false', :input => input)
      p.callback do
        assert !p.success?
        done
      end
    end
  end

  def test_utf8_input
    input = "hålø"

    em do
      p = Child.new('cat', :input => input)
      p.callback do
        assert p.success?
        done
      end
    end
  end

  def test_many_pending_processes
    EM.epoll

    em do
      target = 100
      finished = 0

      finish = lambda do |p|
        finished += 1

        if finished == target
          done
        end
      end

      spawn = lambda do |i|
        EM.next_tick do
          if i < target
            p = Child.new('sleep %.6f' % (rand(10_000) / 1_000_000.0))
            p.callback { finish.call(p) }
            spawn.call(i+1)
          end
        end
      end

      spawn.call(0)
    end
  end

  # Tests if expected listeners are returned by
  # Child#add_stream_listeners(&block).
  def test_add_listeners
    em do
      p = Child.new("printf ''")

      listeners = p.add_streams_listener { |*args| }

      assert listeners
      assert_equal 2, listeners.size
      listeners = listeners.sort_by { |x| x.name }

      assert !listeners[0].closed?
      assert "stderr", listeners[0].name

      assert !listeners[1].closed?
      assert "stdout", listeners[1].name

      p.callback do
        assert p.success?
        done
      end
    end
  end

  # Tests if a listener correctly receives stream updates after it attaches to a
  # process that has already finished execution without producing any output in
  # its stdout and stderr.
  def test_listener_empty_streams_completed_process
    em do
      p = Child.new("printf ''")
      p.callback do
        assert p.success?

        num_calls = 0
        listeners = p.add_streams_listener do |listener, data|
          assert listeners.include?(listener)
          assert listener.closed?

          assert data.empty?

          listeners.delete(listener)
          num_calls += 1
          # The test times out if listeners are not called required number
          # of times.
          done if num_calls == 2
        end
      end
    end
  end

  # Tests if a listener correctly receives out and err stream updates after it
  # attaches to a process that has already finished execution, and has produced
  # some output in its stdout and stderr.
  def test_listener_nonempty_streams_completed_process
    em do
      p = Child.new("printf test >& 1; printf test >& 2")
      p.callback do
        assert p.success?

        num_calls = 0
        listeners = p.add_streams_listener do |listener, data|
          assert listeners.include?(listener)
          assert listener.closed?

          assert_equal "test", data

          listeners.delete(listener)
          num_calls += 1

          # The test times out if listeners are not called required number
          # of times.
          done if num_calls == 2
        end
      end
    end
  end

  # Tests if a listener correctly receives incremental stream updates after it
  # attaches to an active process that produces large output in stdout.
  def test_listener_large_stdout
    output_a = "a" * 1024 * 32
    output_b = "b" * 1024 * 32

    em do
      p = Child.new("printf #{output_a}; sleep 0.1; printf #{output_b}")
      received_data = ''
      listeners = p.add_streams_listener do |listener, data|
        assert listener
        assert data
        if listener.name == "stdout"
          received_data << data
        end
      end

      p.callback do
        assert p.success?
        assert "#{output_a}#{output_b}", received_data
        done
      end
    end
  end

  # Tests if multiple listeners correctly receives stream updates after they
  # attached to the same process.
  def test_listener_nonempty_streams_active_process
    em do
      command = "printf A; sleep 0.01"
      command << "; printf B; sleep 0.01"
      command << "; printf C; sleep 0.01"
      p = Child.new(command)

      data = ['', '']
      closed = [false, false]
      called = false
      p.add_streams_listener do |listener_outer, data_outer|
        data[0] << data_outer
        if listener_outer.closed?
          closed[0] = true
          done if closed[1]
        end
        unless called
          EM.next_tick do
            p.add_streams_listener do |listener_inner, data_inner|
              data[1] << data_inner
              if listener_inner.closed?
                closed[1] = true
                done if closed[0]
              end
            end
          end

          called = true
        end
      end

      p.callback do
        assert p.success?
        assert_equal "ABC", data[0]
        assert_equal "ABC", data[1]
      end
    end
  end
end
