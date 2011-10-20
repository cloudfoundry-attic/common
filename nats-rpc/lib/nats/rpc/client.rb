require "nats/rpc/peer"
require "nats/rpc/util/event_emitter"

module NATS
  module RPC
    class Client < Peer

      def post_initialize
        subscribe("rpc.inbox.#{peername}") do |message|
          request = @registry[message["message_id"]]

          if request
            reply = Reply.new(request, message)
            request.emit("reply", reply)
          end
        end

        # Initialize registry mapping message IDs to calls with a pending reply.
        # Request objects are responsible for removing themselves from the registry
        # once they time out, or are otherwise cancelled.
        @registry = {}
      end

      def register(request)
        @registry[request.message_id] = request
      end

      def unregister(request)
        @registry.delete(request.message_id)
      end

      def registered?(request)
        @registry.has_key?(request.message_id)
      end

      def call(peer, method, payload = nil, options = {}, &blk)
        request = Call.new(self, method, payload, options)
        request.peer = peer
        request.shortcut!(&blk) if blk
        request
      end

      def mcall(method, payload = nil, options = {}, &blk)
        request = Mcall.new(self, method, payload, options)
        request.shortcut!(&blk) if blk
        request
      end

      def mcast(method, payload = nil, options = {})
        Mcast.new(self, method, payload, options)
      end

      def generate_message_id
        @message_id ||= 0
        @message_id += 1
      end

      class Request

        include Util::EventEmitter

        attr_reader :client
        attr_reader :message_id
        attr_reader :method
        attr_reader :options

        def initialize(client, method, payload, options = {})
          @client = client
          @method = client.service.class.methods[method.to_s]
          @payload = payload

          # The service should export the specified method
          if @method.nil?
            raise ArgumentError.new("non-exisiting method specified")
          end

          # This is toggled when the request is executed
          @in_progress = false

          # Override the method's default options with the passed options
          @options = @method.options.merge(options)

          post_initialize
        end

        # Placeholder.
        def post_initialize; end

        # Generate message ID on-demand.
        def message_id
          @message_id ||= client.generate_message_id
        end

        # Construct minimal message for this request.
        def message
          { "message_id" => message_id,
            "peername" => client.peername,
            "method" => @method.name,
            "payload" => @payload }
        end

        def generate_subject(*parts)
          [client.base_subject, parts].flatten.join(".")
        end

        # Register this request with the client, so it can dispatch
        # corresponding replies to this request object.
        def register
          client.register(self)
        end

        # Unregister this request with the client. Replys that arrive after
        # doing this are no longer dispatched to this request object.
        def unregister
          client.unregister(self)
        end

        # Is this request registered to receive more replies?
        def registered?
          client.registered?(self)
        end

        # Verify if the call is valid. For a call to be valid, the method
        # should exist. Other properties that determine if a call is valid may
        # be added in the future.
        def valid?
          true
        end

        protected

        def prepare_execute
          raise "invalid request" unless valid?
          raise "already in progress or finished" if @in_progress
          @in_progress = true
        end
      end

      class ExpectReplyRequest < Request

        # All requests should finish sometime... Requests without a timeout
        # otherwise hang around in the client's registry forever, unless
        # explicitly unregistered by the user.
        DEFAULT_TIMEOUT = 30

        attr_accessor :timeout

        def initialize(*args)
          super

          @timeout = options[:timeout] || method.options[:timeout] || DEFAULT_TIMEOUT
          @timer = nil
        end

        def shortcut!(&blk)
          on("reply") { |reply|
            blk.call(self, reply)
          }

          on("timeout") {
            blk.call(self, nil)
          }

          execute!
        end

        def register
          super
          start_timer
        end

        def unregister
          super
          stop_timer
        end

        protected

        def prepare_execute
          super
          register
        end

        def start_timer
          if @timeout
            # Unregister for new replies and emit event after timing out
            @timer = ::EM::Timer.new(@timeout) {
              emit("timeout")
              unregister
            }
          end
        end

        def stop_timer
          if @timer
            @timer.cancel
            @timer = nil
          end
        end
      end

      class Call < ExpectReplyRequest

        attr_accessor :peer

        def execute!
          prepare_execute
          client.publish(generate_subject("call", peer), message)

          # Unregister after receiving the first reply.
          on("reply") {
            unregister
          }
        end
      end

      class Mcall < ExpectReplyRequest
        def execute!
          prepare_execute
          client.publish(generate_subject("mcall"), message)
        end
      end

      class Mcast < Request
        def execute!
          prepare_execute
          client.publish(generate_subject("mcast"), message)
        end
      end

      class Reply

        # Base
        attr_reader :request
        attr_reader :message_id

        # Meta
        attr_reader :peername

        def initialize(request, message)
          @request = request
          @message = message
        end

        def message_id
          @message["message_id"]
        end

        def peername
          @message["peername"]
        end

        def result
          if @message["error"]
            raise Service::Error.from_hash(@message["error"])
          else
            @message["payload"]
          end
        end
      end
    end
  end # module RPC
end # module NATS
