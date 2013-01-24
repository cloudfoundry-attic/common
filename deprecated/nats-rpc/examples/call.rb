require "logger"
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
    logger = Logger.new(STDOUT)
    logger.level = Logger::DEBUG

    nats = NATS.connect
    client = NATS::RPC::Client.new(nats, :logger => logger)
    math_client = client.service(MathService.new)

    # Find out which peers are available
    math_client.mcall("ping") do |request, reply|
      # Don't wait around for future replies
      request.stop!

      # Call the peer that sent the PONG
      math_client.call(reply.peer_id, "multiply", 10) do |request, reply|
        puts "#{reply.peer_id} got #{reply.result} by randomly multiplying 10!"
      end
    end
  end

when "server"
  require "nats/client"
  require "nats/rpc/server"

  EM.run do
    logger = Logger.new(STDOUT)
    logger.level = Logger::DEBUG

    nats = NATS.connect
    server = NATS::RPC::Server.new(nats, :logger => logger)
    server.start(MathService.new)
  end

else
  puts "Nothing to do..."
end
