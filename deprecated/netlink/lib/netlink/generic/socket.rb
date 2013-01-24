require 'netlink/generic/constants'
require 'netlink/socket'

module Netlink
  module Generic

    class Socket < Netlink::Socket
      def initialize
        super(Netlink::NETLINK_GENERIC)
      end
    end

  end
end
