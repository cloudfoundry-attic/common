require "spec_helper"
require "nats/rpc/service"

class ClientSpecError < NATS::RPC::Service::Error
end

class ClientSpecService < NATS::RPC::Service

  export :echo
  def echo(request)
    request.reply(request.payload)
  end

  export :echo_twice
  def echo_twice(request)
    request.reply(request.payload)
    request.reply(request.payload)
  end

  export :error
  def error(request)
    raise ClientSpecError.new
  end

  export :timeout, :timeout => 0.05
  def timeout(request)
    ::EM.add_timer(0.1) { request.reply(nil) }
  end

  def sinked
    @sinked ||= []
  end

  export :sink
  def sink(request)
    sinked << request
  end
end

describe NATS::RPC::Client do
  include_context :nats

  def start_server
    NATS::RPC::Server.new(nats, :peer_name => "server").tap do |server|
      server.start(ClientSpecService.new)
    end
  end

  let(:client) do
    NATS::RPC::Client.new(nats, :peer_name => "client").service(ClientSpecService.new)
  end

  context "call" do
    it "should be received and processed by a single remote" do
      em do
        server1 = start_server
        server2 = start_server

        request = client.call(server1.peer_id, "echo", "Hi there!")
        request.on("reply") do |reply|
          reply.result.should eq("Hi there!")
          reply.peer_id.should eq(server1.peer_id)
          done
        end

        request.execute!
      end
    end

    it "should raise errors triggered on the remote" do
      em do
        server = start_server

        request = client.call(server.peer_id, "error")
        request.execute!

        request.on("reply") do |reply|
          lambda {
            reply.result
          }.should raise_error(ClientSpecError)
          done
        end
      end
    end

    it "should only emit a reply once" do
      em do
        server = start_server

        # This call emits two replies
        request = client.call(server.peer_id, "echo_twice", "Hi there!")
        request.execute!

        replies = []
        request.on("reply") do |reply|
          replies << reply
        end

        ::EM::add_timer(0.05) do
          replies.should have(1).reply
          done
        end
      end
    end

    it "should take a block for setting up a shortcut" do
      em do
        server = start_server

        client.call(server.peer_id, "echo", "Hi there!") do |request, reply|
          reply.should_not == nil
          reply.result.should == "Hi there!"
          done
        end
      end
    end

    it "should use default timeout when available" do
      em do
        server = start_server

        request = client.call(server.peer_id, "timeout", nil)
        request.execute!

        start = Time.now

        request.on("reply") do
          fail
        end

        request.on("timeout") do
          delta = Time.now - start
          delta.should be_within(0.01).of(0.05)
          done
        end
      end
    end

    it "should pass a nil reply to the shortcut block on a timeout" do
      em do
        server = start_server

        client.call(server.peer_id, "timeout", nil) do |request, reply|
          reply.should be_nil
          done
        end
      end
    end

    it "should allow caller to override default timeout" do
      em do
        server = start_server

        request = client.call(server.peer_id, "timeout", nil, :timeout => 0.01)
        request.execute!

        start = Time.now

        request.on("reply") do
          fail
        end

        request.on("timeout") do
          delta = Time.now - start
          delta.should be_within(0.01).of(0.01)
          done
        end
      end
    end

    it "should not fire timeout when a reply is received" do
      em do
        server = start_server

        request = client.call(server.peer_id, "timeout", nil, :timeout => 0.2)
        request.execute!

        replies = []
        request.on("reply") do |reply|
          replies << reply
        end

        request.on("timeout") do
          fail
        end

        # The remote returns after 100ms. Test that the timeout event doesn't
        # fire when it should have fired if no reply was received.
        ::EM.add_timer(0.3) do
          replies.should have(1).reply
          done
        end
      end
    end
  end

  context "mcall" do
    it "should be received and processed by all remotes" do
      em do
        server1 = start_server
        server2 = start_server

        request = client.mcall("echo", "Hi there!")
        request.execute!

        replies = []
        request.on("reply") do |reply|
          replies << reply
        end

        ::EM.add_timer(0.05) do
          replies.should have(2).replies
          replies.map(&:result).should == (["Hi there!"] * 2)
          replies.map(&:peer_id).sort.should == [server1.peer_id, server2.peer_id].sort
          done
        end
      end
    end

    it "should allow the user to prevent future replies from arriving" do
      em do
        server1 = start_server
        server2 = start_server

        request = client.mcall("echo", "Hi there!")
        request.execute!

        replies = []
        request.on("reply") do |reply|
          replies << reply
          request.stop!
        end

        ::EM.add_timer(0.05) do
          replies.should have(1).reply
          done
        end
      end
    end

    it "should raise errors triggered on the remote" do
      em do
        start_server

        request = client.mcall("error")
        request.execute!

        request.on("reply") do |reply|
          lambda {
            reply.result
          }.should raise_error(ClientSpecError)
          done
        end
      end
    end

    it "should take a block for setting up a shortcut" do
      em do
        start_server

        client.mcall("echo", "Hi there!") do |request, reply|
          reply.should_not == nil
          reply.result.should == "Hi there!"
          done
        end
      end
    end

    it "should use default timeout when available" do
      em do
        start_server

        request = client.mcall("timeout", nil)
        request.execute!

        start = Time.now

        request.on("reply") do
          fail
        end

        request.on("timeout") do
          delta = Time.now - start
          delta.should be_within(0.01).of(0.05)
          done
        end
      end
    end

    it "should pass a nil reply to the shortcut block on a timeout" do
      em do
        start_server

        client.mcall("timeout", nil) do |request, reply|
          reply.should be_nil
          done
        end
      end
    end

    it "should allow caller to override default timeout" do
      em do
        start_server

        request = client.mcall("timeout", nil, :timeout => 0.01)
        request.execute!

        start = Time.now

        request.on("reply") do
          fail
        end

        request.on("timeout") do
          delta = Time.now - start
          delta.should be_within(0.01).of(0.01)
          done
        end
      end
    end

    it "should fire timeout EVEN after replies have been received" do
      em do
        start_server

        request = client.mcall("timeout", nil, :timeout => 0.2)
        request.execute!

        replies = []
        request.on("reply") do |reply|
          replies << reply
        end

        request.on("timeout") do
          replies.should have(1).reply
          done
        end
      end
    end
  end

  context "mcast" do
    it "should be received and processed by all remotes" do
      em do
        server1 = start_server
        server2 = start_server

        request = client.mcast("sink")
        request.execute!

        # There is no reply. Wait for a bit and test that the request has been
        # received by the remotes.
        ::EM.add_timer(0.1) do
          server1.services["ClientSpecService"].sinked.should have(1).request
          server2.services["ClientSpecService"].sinked.should have(1).request
          done
        end
      end
    end
  end
end
