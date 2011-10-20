require "nats/rpc/peer"

module NATS
  module RPC
    class Server < Peer

      def post_initialize
        subscribe(base_subject + ".call.#{peername}") do |message|
          handle(message)
        end
        subscribe(base_subject + ".mcall") do |message|
          handle(message)
        end
        subscribe(base_subject + ".mcast") do |message|
          handle(message)
        end
      end

      def handle(message)
        request = Request.new(self, message)
        request.execute!
      end

      class Request

        attr_reader :server

        def initialize(server, message)
          @server = server
          @message = message
        end

        def message_id
          @message["message_id"]
        end

        def peername
          @message["peername"]
        end

        def method
          @message["method"]
        end

        def payload
          @message["payload"]
        end

        def execute!
          server.service.execute!(self)
        rescue Service::Error => error
          reply_error(error)
        end

        def reply(payload)
          _reply("payload" => payload)
        end

        def reply_error(error)
          error_base_class = Service::Error
          unless error.kind_of?(error_base_class)
            raise ArgumentError.new("expect subclass of #{error_base_class.name}")
          end

          _reply("error" => Service::Error.to_hash(error))
        end

        protected

        def _reply(message)
          server.publish("rpc.inbox.#{peername}", message.merge({
            "message_id" => message_id,
            "peername" => server.peername
          }))
        end
      end
    end
  end # module RPC
end # module NATS
