require "rspec"
require "nats/client"
require "nats/rpc/service"
require "nats/rpc/client"
require "nats/rpc/server"

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
    :done.should == :done
    ::EM.stop_event_loop
  }
end

shared_context :nats do

  # Return new NATS connection on every call
  def nats
    NATS.connect(:uri => "nats://localhost:4223", :autostart => true)
  end

  # Terminate auto-started NATS server
  after(:all) do
    if File.exists? NATS::AUTOSTART_PID_FILE
      pid = File.read(NATS::AUTOSTART_PID_FILE).chomp.to_i
      `kill -9 #{pid}`
      FileUtils.rm_f NATS::AUTOSTART_PID_FILE
    end

    # Let NATS clean up its shared state
    NATS.stop
  end
end
