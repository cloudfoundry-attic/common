require "nats/rpc/peer"
require "nats/rpc/util/event_emitter"

module NATS
  module RPC
    class Client < Peer

      def generate_message_id
        @message_id ||= 0
        @message_id += 1
      end

      def service(service)
        ServiceClient.new(self, service)
      end

      class ServiceClient

        attr_reader :client
        attr_reader :service

        def initialize(client, service)
          @client = client
          @service = service
        end

        def call(remote_peer_id, method, payload = nil, options = {}, &blk)
          Call.new(@client, @service, method, payload).tap do |request|
            request.remote_peer_id = remote_peer_id
            request.timeout = options[:timeout] if options.has_key?(:timeout)
            request.shortcut!(&blk) if blk
          end
        end

        def mcall(method, payload = nil, options = {}, &blk)
          Mcall.new(@client, @service, method, payload).tap do |request|
            request.timeout = options[:timeout] if options.has_key?(:timeout)
            request.shortcut!(&blk) if blk
          end
        end

        def mcast(method, payload = nil, options = {})
          Mcast.new(@client, @service, method, payload)
        end
      end

      class Request

        include Util::EventEmitter

        attr_reader :client
        attr_reader :service
        attr_reader :message_id

        attr_reader :method
        attr_reader :payload

        def initialize(client, service, method, payload)
          @client = client
          @service = service
          @message_id = client.generate_message_id
          @method = service.class.methods[method.to_s]
          @payload = payload

          # The service should export the specified method
          if @method.nil?
            raise ArgumentError.new("non-exisiting method specified")
          end

          # This is toggled when the request is executed
          @in_progress = false

          post_initialize
        end

        # Placeholder.
        def post_initialize; end

        # Construct minimal message for this request.
        def message
          { "message_id" => message_id,
            "peer_id" => client.peer_id,
            "method" => method.name,
            "payload" => payload }
        end

        # Verify if the call is valid. For a call to be valid, the method
        # should exist. Other properties that determine if a call is valid may
        # be added in the future.
        def valid?
          true
        end

        protected

        def start
          raise "invalid request" unless valid?
          raise "already in progress or finished" if @in_progress
          @in_progress = true
        end

        def stop
        end
      end

      class ExpectReplyRequest < Request

        # When the required number of replies is not received, the timeout
        # fires and pending subscriptions are cancelled.
        DEFAULT_TIMEOUT = 30

        attr_reader :inbox

        attr_accessor :timeout
        attr_accessor :max_replies

        def post_initialize
          super

          # Generate inbox that recipients of this request can reply to
          @inbox = [client.base_subject, service.name, "inbox", client.peer_id, message_id].join(".")
          @subscription = nil

          # Setup default timeout, user can override
          @timeout = method.options[:timeout] || DEFAULT_TIMEOUT
          @timer = nil

          # Maximum number of replies (is handled by the NATS server)
          @max_replies = nil
          @received_replies = 0

          # Stop request when enough replies have been received
          on("reply") {
            @received_replies += 1
            stop if max_replies_received?
          }

          # Stop request on timeout
          on("timeout") {
            stop
          }
        end

        # Have the maximum number of replies already been received?
        def max_replies_received?
          @max_replies && @received_replies >= @max_replies
        end

        # Merge this request's inbox into the minimal message.
        def message
          super.merge(:reply_to => inbox)
        end

        # Shortcut: use a single block for both replies and timeouts.
        def shortcut!(&blk)
          on("reply") { |reply|
            blk.call(self, reply)
          }

          on("timeout") {
            blk.call(self, nil)
          }

          execute!
        end

        def stop!
          stop
        end

        protected

        def start
          super

          start_timer

          # Subscribe to own inbox, optionally with max number of replies
          options = {}
          options[:max] = max_replies if max_replies
          @subscription = client.subscribe(inbox, options) do |message|
            reply = Reply.new(self, message)
            emit("reply", reply)
          end
        end

        def stop
          super

          stop_timer

          # Unsubscribe from own inbox if not auto-unsubscribed
          unless max_replies_received?
            client.unsubscribe(@subscription)
          end
        end

        def start_timer
          raise "invalid timeout" unless timeout.kind_of?(Numeric)

          # Unregister for new replies and emit event after timing out
          @timer = ::EM.add_timer(@timeout) {
            emit("timeout")
          }
        end

        def stop_timer
          ::EM.cancel_timer(@timer) if @timer
        end
      end

      class Call < ExpectReplyRequest

        attr_accessor :remote_peer_id

        def post_initialize
          super
          @max_replies = 1
        end

        def execute!
          start
          client.publish([client.base_subject, service.name, "call", remote_peer_id].join("."), message)
        end
      end

      class Mcall < ExpectReplyRequest
        def execute!
          start
          client.publish([client.base_subject, service.name, "mcall"].join("."), message)
        end
      end

      class Mcast < Request
        def execute!
          start
          client.publish([client.base_subject, service.name, "mcast"].join("."), message)
        end
      end

      class Reply

        # Base
        attr_reader :request
        attr_reader :message_id

        # Meta
        attr_reader :peer_id

        def initialize(request, message)
          @request = request
          @message = message
        end

        def message_id
          @message["message_id"]
        end

        def peer_id
          @message["peer_id"]
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
