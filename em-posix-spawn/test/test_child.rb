# coding: UTF-8

require 'test/unit'
require 'em/posix/spawn/child'
require 'set'

module Helpers

  def em(options = {})
    raise "no block given" unless block_given?
    timeout = options[:timeout] ||= 1.0

    ::EM.run {
      quantum = 0.005
      ::EM.set_quantum(quantum * 1000) # Lowest possible timer resolution
      ::EM.set_heartbeat_interval(quantum) # Timeout connections asap
      ::EM.add_timer(timeout) { raise "timeout" }
      yield
    }
  end

  def done
    raise "reactor not running" if !::EM.reactor_running?

    ::EM.next_tick {
      # Assert something to show a spec-pass
      assert true
      ::EM.stop_event_loop
    }
  end
end

class ChildTest < Test::Unit::TestCase

  include ::EM::POSIX::Spawn
  include Helpers

  def test_sanity
    assert_same ::EM::POSIX::Spawn::Child, Child
  end

  def test_argv_string_uses_sh
    em {
      p = Child.new("echo via /bin/sh")
      p.callback {
        assert p.success?
        assert_equal "via /bin/sh\n", p.out
        done
      }
    }
  end

  def test_stdout
    em {
      p = Child.new('echo', 'boom')
      p.callback {
        assert_equal "boom\n", p.out
        assert_equal "", p.err
        done
      }
    }
  end

  def test_stderr
    em {
      p = Child.new('echo boom 1>&2')
      p.callback {
        assert_equal "", p.out
        assert_equal "boom\n", p.err
        done
      }
    }
  end

  def test_status
    em {
      p = Child.new('exit 3')
      p.callback {
        assert !p.status.success?
        assert_equal 3, p.status.exitstatus
        done
      }
    }
  end

  def test_env
    em {
      p = Child.new({ 'FOO' => 'BOOYAH' }, 'echo $FOO')
      p.callback {
        assert_equal "BOOYAH\n", p.out
        done
      }
    }
  end

  def test_chdir
    em {
      p = Child.new("pwd", :chdir => File.dirname(Dir.pwd))
      p.callback {
        assert_equal File.dirname(Dir.pwd) + "\n", p.out
        done
      }
    }
  end

  def test_input
    input = "HEY NOW\n" * 100_000 # 800K

    em {
      p = Child.new('wc', '-l', :input => input)
      p.callback {
        assert_equal 100_000, p.out.strip.to_i
        done
      }
    }
  end

  def test_max
    em {
      p = Child.new('yes', :max => 100_000)
      p.callback { fail }
      p.errback { |err|
        assert_equal MaximumOutputExceeded, err
        done
      }
    }
  end

  def test_max_with_child_hierarchy
    em {
      p = Child.new('/bin/sh', '-c', 'yes', :max => 100_000)
      p.callback { fail }
      p.errback { |err|
        assert_equal MaximumOutputExceeded, err
        done
      }
    }
  end

  def test_max_with_stubborn_child
    em {
      p = Child.new("trap '' TERM; yes", :max => 100_000)
      p.callback { fail }
      p.errback { |err|
        assert_equal MaximumOutputExceeded, err
        done
      }
    }
  end

  def test_timeout
    em {
      start = Time.now
      p = Child.new('sleep', '1', :timeout => 0.05)
      p.callback { fail }
      p.errback { |err|
        assert_equal TimeoutExceeded, err
        assert (Time.now-start) <= 0.2
        done
      }
    }
  end

  def test_timeout_with_child_hierarchy
    em {
      p = Child.new('/bin/sh', '-c', 'sleep 1', :timeout => 0.05)
      p.callback { fail }
      p.errback { |err|
        assert_equal TimeoutExceeded, err
        done
      }
    }
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

    em {
      p = Child.new(command, :input => input)
      p.callback {
        assert_equal input.size, p.out.size
        assert_equal input.size, p.err.size
        assert p.success?
        done
      }
    }
  end

  def test_input_cannot_be_written_due_to_broken_pipe
    input = "1" * 100_000

    em {
      p = Child.new('false', :input => input)
      p.callback {
        assert !p.success?
        done
      }
    }
  end

  def test_utf8_input
    input = "hålø"

    em {
      p = Child.new('cat', :input => input)
      p.callback {
        assert p.success?
        done
      }
    }
  end

  def test_many_pending_processes
    EM.epoll

    em {
      target = 100
      finished = 0

      finish = lambda { |p|
        finished += 1

        if finished == target
          done
        end
      }

      spawn = lambda { |i|
        EM.next_tick {
          if i < target
            p = Child.new('sleep %.6f' % (rand(10_000) / 1_000_000.0))
            p.callback { finish.call(p) }
            spawn.call(i+1)
          end
        }
      }

      spawn.call(0)
    }
  end

  # Tests if a listener correctly receives stream updates from a process that
  # has already finished execution without producing any output in its stdout
  # and stderr.
  def test_listener_empty_streams_completed_process
    em {
      p = Child.new("echo -n")
      p.callback {
        assert p.success?

        EM.next_tick {
          num_sentinels = p.add_streams_listener { |update|
            assert update
            assert update.sentinel?
            num_sentinels -= 1
          }

          assert_equal 2, num_sentinels

          EM.next_tick {
            assert_equal 0, num_sentinels
            done
          }
        }
      }
    }
  end

  # Tests if a listener correctly receives out and err stream updates from a
  # process that has already finished execution, and has produced some output
  # in its stdout and stderr.
  def test_listener_nonempty_streams_completed_process
    em {
      p = Child.new("echo test >& 1; echo test >& 2")
      p.callback {
        assert p.success?

        EM.next_tick {
          streams = Set.new
          num_updates = 0
          num_sentinels = p.add_streams_listener { |update|
            if update.sentinel?
              num_sentinels -= 1
            else
              assert_equal "test\n", update.data
              streams << update.name
              num_updates -= 1
            end
          }

          assert_equal 2, num_sentinels
          num_updates = num_sentinels

          EM.next_tick {
            assert_equal 0, num_updates
            assert_equal 0, num_sentinels
            assert_equal 2, streams.length
            assert streams.include?("stdout")
            assert streams.include?("stderr")
            done
          }
        }
      }
    }
  end

  # Tests if a listener correctly receives increment stream updates from an
  # active process that produces large output in stdout.
  def test_listener_large_stdout
    output = "a" * 1024 * 32
    num_updates = 0
    num_sentinels = 0
    em {
      p = Child.new("echo -n #{output}; sleep 0.1; echo -n #{output}")

      p.callback {
        assert p.success?
        assert_equal 0, num_updates
        assert_equal 0, num_sentinels
        done
      }

      num_sentinels = p.add_streams_listener { |update|
        assert update
        if update.sentinel?
          num_sentinels -= 1
        else
          assert update.name
          assert_equal "stdout", update.name
          assert update.data
          assert_equal output.length, update.data.length
          assert_equal output, update.data
          num_updates -= 1
        end
      }

      assert_equal 2, num_sentinels
      num_updates = 2 # one for each output chunk written to stdout.
    }
  end


  # Tests if multiple listeners correctly receives stream updates from the same
  # process.
  def test_listener_nonempty_streams_active_process
    em {
      command = "echo -n A; sleep 0.1"
      command << "; echo -n B; sleep 0.1"
      command << "; echo -n C; sleep 0.1"
      p = Child.new(command)

      first_listener_data = ''
      second_listener_data = ''
      num_sentinels = 0
      p.callback {
        assert p.success?
        assert_equal 0, num_sentinels
        assert_equal "ABC", first_listener_data
        assert_equal "ABC", second_listener_data
        done
      }

      called = false
      num_sentinels = p.add_streams_listener { |update|
        assert update
        if update.sentinel?
          num_sentinels -= 1
        else
          assert update.name
          assert_equal "stdout", update.name
          assert update.data
          first_listener_data << update.data
        end

        unless called
          EM.next_tick {
            p.add_streams_listener { |update|
              assert update
              if update.sentinel?
                num_sentinels -= 1
              else
                assert update.name
                assert_equal "stdout", update.name
                assert update.data
                second_listener_data << update.data
              end
            }
          }

          called = true
        end
      }

      assert_equal 2, num_sentinels
      num_sentinels = 4 # for both listeners
    }
  end
end
