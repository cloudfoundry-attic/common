require "nats/rpc/service"

class MathService < NATS::RPC::Service
  export :ping
  def ping(request)
    request.reply("pong")
  end

  export :multiply
  def multiply(request)
    request.reply(request.payload * rand(10))
  end
end

case ARGV.first
when "client"
  require "nats/client"
  require "nats/rpc/client"

  EM.run do
    nats = NATS.connect
    client = NATS::RPC::Client.new(nats, MathService.new)

    # Find out which peers are available
    client.mcall("ping") do |request, reply|
      # Don't wait around for future replies
      request.unregister

      # Call the peer that sent the PONG
      client.call(reply.peername, "multiply", 10) do |request, reply|
        puts "#{reply.peername} got #{reply.result} by randomly multiplying 10!"
      end
    end
  end

when "server"
  require "nats/client"
  require "nats/rpc/server"

  EM.run do
    nats = NATS.connect
    server = NATS::RPC::Server.new(nats, MathService.new)
  end

else
  puts "Nothing to do..."
end
