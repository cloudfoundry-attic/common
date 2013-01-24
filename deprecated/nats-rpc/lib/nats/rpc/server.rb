require "nats/rpc/peer"
require "nats/rpc/util/event_emitter"

module NATS
  module RPC
    class Server < Peer

      include Util::EventEmitter

      def post_initialize
        @services = {}
      end

      def services
        @services.dup
      end

      def start(service)
        service_base_class = NATS::RPC::Service
        unless service.kind_of?(service_base_class)
          raise ArgumentError.new("Expected subclass of " + service_base_class.name)
        end

        subscribe_service(service)
        emit("start", service)
        @services[service.name] = service

        nil
      end

      protected

      def subscribe_service(service)
        handler = lambda { |message| Request.execute!(self, service, message) }
        subscribe(call_subject(service), &handler)
        subscribe(mcall_subject(service), &handler)
        subscribe(mcast_subject(service), &handler)
      end

      def unsubscribe_service(service)
        unsubscribe(call_subject(service))
        unsubscribe(mcall_subject(service))
        unsubscribe(mcast_subject(service))
      end

      def call_subject(service)
        [base_subject, service.name, "call", peer_id].join(".")
      end

      def mcall_subject(service)
        [base_subject, service.name, "mcall"].join(".")
      end

      def mcast_subject(service)
        [base_subject, service.name, "mcast"].join(".")
      end

      class Request

        def self.execute!(server, service, message)
          Request.new(server, service, message).tap do |request|
            request.execute!
          end
        end

        attr_reader :server
        attr_reader :service

        def initialize(server, service, message)
          @server = server
          @service = service
          @message = message
        end

        def message_id
          @message["message_id"]
        end

        def peer_id
          @message["peer_id"]
        end

        def reply_to
          @message["reply_to"]
        end

        def method
          @message["method"]
        end

        def payload
          @message["payload"]
        end

        def execute!
          service.execute!(self)
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
          server.publish(reply_to, message.merge({
            "message_id" => message_id,
            "peer_id" => server.peer_id
          }))
        end
      end
    end
  end # module RPC
end # module NATS
