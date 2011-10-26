require "nats/rpc/client"
require "vcap/locator/service"

module VCAP
  module Locator
    class Source

      attr_reader :server
      attr_accessor :interval

      def initialize(server)
        @server = server
        @timer = nil
        @interval = 5.0

        # Create private client instance in same namespace as server
        @locator_service = LocatorService.new
        @client = ::NATS::RPC::Client.new(server.nats, server.options)
        @locator_client = @client.service(@locator_service)
      end

      def started?
        !@timer.nil?
      end

      def start
        @timer = ::EM.add_periodic_timer(@interval, method(:emit_heartbeat))
      end

      def stop
        ::EM.cancel_timer(@timer)
        @timer = nil
      end

      def emit_heartbeat
        details = server.services.values.map do |service|
          { "peer_id" => server.peer_id,
            "service_name" => service.name,
            "service_health" => service.respond_to?(:health) ? service.health : 1.0 }
        end

        request = @locator_client.mcast("heartbeat", details)
        request.execute!
      end
    end
  end # module Locator
end # module VCAP
