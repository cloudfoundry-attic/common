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

  NATS_PORT = 4223

  def nats_pid_file
    File.expand_path("../tmp/nats-server.pid", __FILE__)
  end

  def nats_pid
    File.read(nats_pid_file).chomp if File.exist?(nats_pid_file)
  end

  def nats_running?
    nats_pid and `ps -o pid= -p #{nats_pid}`.length > 0
  end

  def start_nats_if_its_not_running
    unless nats_running?
      `bundle exec nats-server --port #{NATS_PORT} --pid #{nats_pid_file} --daemonize`
    end
  end

  # Return new NATS connection on every call
  def nats
    start_nats_if_its_not_running
    NATS.connect(:uri => "nats://localhost:#{NATS_PORT}")
  end

  # Terminate running NATS server
  after(:all) do
    if nats_running?
      `kill -9 #{nats_pid}`
      FileUtils.rm_f(nats_pid_file)
    end

    # Let NATS clean up its shared state
    NATS.stop
  end
end
