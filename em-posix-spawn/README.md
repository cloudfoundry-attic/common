# `em-posix-spawn`

This module provides an interface to `POSIX::Spawn` for EventMachine. In
particular, it contains an EventMachine equivalent to `POSIX::Spawn::Child`.
This class encapsulates writing to the child process its stdin and reading from
both its stdout and stderr. Only when the process has exited, it triggers a
callback to notify others of its completion. Just as `POSIX::Spawn::Child`,
this module allows the caller to include limits for execution time and number
of bytes read from stdout and stderr.

# Usage

Please refer to the documentation of `POSIX::Spawn::Child` for the complete set
of options that can be passed when creating `Child`.

```ruby
require "em/posix/spawn"

EM.run {
  p = EM::POSIX::Spawn::Child.new("echo something")

  p.callback {
    puts "Child process echo'd: #{p.out.inspect}"
    EM.stop
  }

  p.errback { |err|
    puts "Error running child process: #{err.inspect}"
    EM.stop
  }
}
```

# Credit

The implementation for `EM::POSIX::Spawn::Child` and its tests are based on the
implementation and tests for `POSIX::Spawn::Child`, which is Copyright (c) 2011
by Ryan Tomayko <r@tomayko.com> and Aman Gupta <aman@tmm1.net>.
