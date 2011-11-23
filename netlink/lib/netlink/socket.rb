require 'socket'

require 'netlink/constants'
require 'netlink/types'

module Netlink
  class Socket < ::Socket
    SENDTO_SOCKADDR = Netlink::Sockaddr.new.to_binary_s.freeze

    def initialize(netlink_family)
      super(Netlink::PF_NETLINK, Socket::SOCK_RAW, netlink_family)
    end

    def bind(sockaddr=nil)
      case sockaddr
      when nil
        sockaddr = Netlink::Sockaddr.new.to_binary_s
      when Netlink::Sockaddr
        sockaddr = sockaddr.to_binary_s
      end
      super(sockaddr)
    end

    def sendto(msg)
      sendmsg(msg, 0, SENDTO_SOCKADDR)
    end
  end
end
