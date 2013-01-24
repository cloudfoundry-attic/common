require "nats/rpc/service"

module VCAP
  module Locator

    # This service exports the "#heartbeat" method which gets called via
    # multicast by all servers that want to broadcast the services they
    # implement. In turn, instances of this service acquire a list of servers
    # that export a list of services. This information can be used to make
    # direct calls to services on remote peers, without the need to discover
    # them first.

    class LocatorService < ::NATS::RPC::Service

      def initialize
        @services = {}

        # Prune stale remote services every minute
        @prune_timer = ::EM.add_periodic_timer(60) do
          @services.dup.each do |pair, service|
            @services.delete(pair) if service.stale?
          end
        end
      end

      # Code outside this class doesn't need to know about the keys
      def services
        @services.values
      end

      export :heartbeat
      def heartbeat(request)
        now = Time.now

        messages = request.payload || []
        messages.each do |message|
          pair = [message["peer_id"], message["service_name"]]
          next if pair.any?(&:nil?)

          @services[pair] ||= RemoteService.new(*pair)
          @services[pair].heartbeat_health = message["service_health"]
          @services[pair].heartbeat_timestamp = now
        end
      end

      class RemoteService

        attr_reader :peer_id
        attr_reader :name

        # Populated externally
        attr_accessor :heartbeat_health
        attr_accessor :heartbeat_timestamp

        # Default period of time to retain call status information
        CALL_STATUS_RETENTION = 5 * 60

        # Time without heartbeats for a remote service to be considered stale
        TIME_BEFORE_STALE = 5 * 60

        def initialize(peer_id, name)
          @peer_id = peer_id
          @name = name

          @success = []
          @failure = []
        end

        def stale?
          limit = (Time.now - TIME_BEFORE_STALE)
          heartbeat_timestamp && (heartbeat_timestamp < limit)
        end

        def health
          0.5 * service_health + 0.5 * call_health
        end

        def service_health
          1.0
        end

        def call_health
          limit = (Time.now - CALL_STATUS_RETENTION)
          @success.shift while @success.first && @success.first < limit
          @failure.shift while @failure.first && @failure.first < limit

          total = @success.length + @failure.length
          if total == 0
            1.0
          else
            @success.length / total.to_f
          end
        end

        def mark_success
          @success << Time.now
        end

        def mark_failure
          @failure << Time.now
        end
      end
    end
  end # module Locator
end # module VCAP
