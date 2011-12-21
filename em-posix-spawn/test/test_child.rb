# coding: UTF-8

require 'test/unit'
require 'em/posix/spawn/child'

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
end
