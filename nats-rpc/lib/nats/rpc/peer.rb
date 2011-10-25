require "json"

module NATS
  module RPC
    class Peer

      def self.generate_peer_id
        @peer_id ||= 0
        @peer_id += 1
      end

      attr_reader :nats
      attr_reader :options
      attr_reader :logger
      attr_reader :namespace

      def initialize(nats, options = {})
        @nats = nats
        @options = options
        @logger = options[:logger]
        @namespace = options[:namespace] || "default"

        post_initialize
      end

      # Placeholder
      def post_initialize; end

      # Return peer identification. This can either be user-provided by means
      # of the options hash, or otherwise defaults to a combination of the
      # hostname and the PID.
      def peer_name
        options[:peer_name] ||= "%s-%d" % [`hostname`.chomp, Process.pid]
      end

      # Return ID specific to this peer and particular object instance.
      def peer_id
        @peer_id ||= [peer_name, Peer.generate_peer_id].join(".")
      end

      # Base subject for all calls.
      def base_subject
        @base_subject ||= "rpc.#{namespace}"
      end

      # Proxy to NATS.
      def publish(subject, message)
        json = JSON.generate(message)
        logger.debug("Publishing to #{subject}: #{json}") if logger
        nats.publish(subject, json)
      end

      # Proxy to NATS.
      def subscribe(subject, *args, &blk)
        logger.debug("Subscribing to #{subject}") if logger
        nats.subscribe(subject, *args) do |json|
          logger.debug("Received message on #{subject}: #{json}") if logger
          blk.call(JSON.parse(json))
        end
      end

      # Proxy to NATS.
      def unsubscribe(subject, *args)
        logger.debug("Unsubscribing from #{subject}") if logger
        nats.unsubscribe(subject, *args)
      end
    end
  end # module RPC
end # module NATS
