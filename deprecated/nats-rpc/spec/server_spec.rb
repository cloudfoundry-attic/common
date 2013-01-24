require "spec_helper"
require "nats/rpc/service"

class ServerSpecError < NATS::RPC::Service::Error
end

class ServerSpecService < NATS::RPC::Service

  export :echo
  def echo(request)
    request.reply(request.payload)
  end

  export :error
  def error(request)
    raise ServerSpecError.new
  end

  export :invalid_error
  def invalid_error(request)
    raise "something"
  end

  export :delayed_error
  def delayed_error(request)
    ::EM.add_timer(0.05) { request.reply_error(ServerSpecError.new) }
  end

  export :delayed_invalid_error
  def delayed_invalid_error(request)
    ::EM.add_timer(0.05) { request.reply_error(RuntimeError.new("something")) }
  end
end

describe NATS::RPC::Server do
  include_context :nats

  def start_server
    NATS::RPC::Server.new(nats, :peer_name => "server").tap do |server|
      server.start(ServerSpecService.new)
    end
  end

  let(:client) do
    NATS::RPC::Client.new(nats, :peer_name => "client").service(ServerSpecService.new)
  end

  context "replying with an error" do
    context "that is raised" do
      it "should work when derived from Service::Error" do
        em do
          server = start_server

          client.call(server.peer_id, "error") do |request, reply|
            lambda {
              reply.result
            }.should raise_error(ServerSpecError)
            done
          end
        end
      end

      it "should fail when not derived from Service::Error" do
        err = nil

        begin
          em do
            server = start_server

            request = client.call(server.peer_id, "invalid_error")
            request.execute!
          end
        rescue => aux
          err = aux
        end

        # This error bubbled from the actual service implementation to the EM block
        err.should be_kind_of(RuntimeError)
        err.message.should match(/something/)
      end
    end

    context "that is explicitly passed to the request object" do
      it "should work when derived from Service::Error" do
        em do
          server = start_server

          client.call(server.peer_id, "delayed_error") do |request, reply|
            lambda {
              reply.result
            }.should raise_error(ServerSpecError)
            done
          end
        end
      end

      it "should fail when not derived from Service::Error" do
        err = nil

        begin
          em do
            server = start_server

            request = client.call(server.peer_id, "delayed_invalid_error")
            request.execute!
          end
        rescue => aux
          err = aux
        end

        # This error bubbled from the reply guard to the EM block
        err.should be_kind_of(ArgumentError)
        err.message.should match(/expect subclass/)
      end
    end
  end
end
