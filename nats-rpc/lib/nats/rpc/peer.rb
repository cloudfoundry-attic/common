require "json"

module NATS
  module RPC
    class Peer

      attr_reader :nats
      attr_reader :service
      attr_reader :options

      def initialize(nats, service, options = {})
        service_base_class = NATS::RPC::Service
        unless service.kind_of?(service_base_class)
          raise ArgumentError.new("Expected subclass of " + service_base_class.name)
        end

        @nats = nats
        @service = service
        @options = options

        post_initialize
      end

      # Placeholder
      def post_initialize; end

      # TODO: use something that scales better...
      #
      # This approach has problems when the process forks after setting up RPC
      # code. However, since forking in the reactor loop is a bad practice,
      # this shouldn't be a problem.
      def peername
        options[:peername] ||= "%s-%d" % [`hostname`.chomp, $?.pid]
      end

      # Base subject for all calls.
      def base_subject
        @base_subject ||= "rpc.#{service.name}"
      end

      # Proxy to NATS.
      def publish(subject, message)
        #puts "Publishing to #{subject}: #{message.inspect}"
        nats.publish(subject, JSON.generate(message))
      end

      # Proxy to NATS.
      def subscribe(subject, &blk)
        #puts "Subscribing to #{subject}"
        nats.subscribe(subject) do |message|
          #puts "Received message on #{subject}: #{message}"
          blk.call(JSON.parse(message))
        end
      end
    end
  end # module RPC
end # module NATS
