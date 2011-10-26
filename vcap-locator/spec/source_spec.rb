require "spec_helper"
require "nats/rpc/service"
require "nats/rpc/server"
require "vcap/locator/service"
require "vcap/locator/source"

class SourceSpecService < NATS::RPC::Service
end

describe VCAP::Locator::Source do
  include_context :nats

  it "should broadcast all services exported by a server" do
    em do
      locator_service = VCAP::Locator::LocatorService.new
      locator_service.services.should be_empty

      # Start locator service (should receive broadcast)
      locator_server = NATS::RPC::Server.new(nats)
      locator_server.start(locator_service)

      # Start source (emits broadcast)
      server = NATS::RPC::Server.new(nats)
      server.start(SourceSpecService.new)
      source = VCAP::Locator::Source.new(server)
      source.interval = 0.01
      source.start

      EM.add_timer(0.05) do
        locator_service.services.should have(1).remote_service
        done
      end
    end
  end
end
