require "spec_helper"
require "nats/rpc/service"
require "nats/rpc/client"
require "nats/rpc/server"
require "vcap/locator/service"
require "vcap/locator/sink"
require "vcap/locator/source"

class SinkSpecService < NATS::RPC::Service

  export :echo
  def echo(request)
    request.reply(request.payload)
  end
end

describe VCAP::Locator::Sink do
  include_context :nats

  def start_remote
    server = NATS::RPC::Server.new(nats)
    server.start(SinkSpecService.new)
    source = VCAP::Locator::Source.new(server)
    source.interval = 0.01
    source.start
  end

  it "should pick up broadcasts" do
    em do
      start_remote

      client = NATS::RPC::Client.new(nats)
      sink = VCAP::Locator::Sink.new(client)
      sink.remote_services(SinkSpecService.new).should be_empty

      EM.add_timer(0.05) do
        sink.remote_services(SinkSpecService.new).should have(1).remote_service
        done
      end
    end
  end

  it "should delegate calls to available remotes" do
    em do
      start_remote

      client = NATS::RPC::Client.new(nats)
      sink = VCAP::Locator::Sink.new(client)
      sink.remote_services(SinkSpecService.new).should be_empty

      EM.add_timer(0.05) do
        sink_spec_client = sink.service(SinkSpecService.new)
        sink_spec_client.call("echo", "whatever") do |request, reply|
          reply.result.should == "whatever"
          done
        end
      end
    end
  end
end
