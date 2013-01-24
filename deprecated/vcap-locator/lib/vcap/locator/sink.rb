require "nats/rpc/server"
require "vcap/locator/service"

module VCAP
  module Locator
    class Sink

      attr_reader :client
      attr_reader :locator_service

      def initialize(client)
        @client = client

        # Create private server instance under same namespace as client.
        @locator_service = LocatorService.new
        @server = ::NATS::RPC::Server.new(client.nats, client.options)
        @server.start(@locator_service)
      end

      def service(service)
        DynamicServiceClient.new(self, service)
      end

      def remote_services(service)
        @locator_service.services.find_all do |remote_service|
          remote_service.name == service.name
        end
      end

      class DynamicServiceClient

        attr_reader :sink
        attr_reader :service

        def initialize(sink, service)
          @sink = sink
          @service = service
          @service_client = sink.client.service(service)
        end

        def remote_services
          sink.locator_service.services.find_all do |remote_service|
            remote_service.name == service.name
          end
        end

        def call(method, payload = nil, options = {}, &blk)
          remote_service = remote_services.sort_by(&:health).last
          raise "no peer" unless remote_service

          # Fire request with the real service client
          @service_client.call(remote_service.peer_id, method, payload, options).tap do |request|
            request.on("reply") { remote_service.mark_success }
            request.on("timeout") { remote_service.mark_failure }
            request.shortcut!(&blk) if blk
          end
        end
      end
    end
  end # module Locator
end # module VCAP
