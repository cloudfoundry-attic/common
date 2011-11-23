
require "em/posix/spawn"

EM.run {
  p = EM::POSIX::Spawn::Child.new("sleep 1 && echo something", :timeout => 0.1, :max => 1)

  p.callback {
    puts "Child process echo'd: #{p.out.inspect}"
    EM.stop
  }

  p.errback { |err|
    puts "Error running child process: #{err.inspect}"
    EM.stop
  }
}
