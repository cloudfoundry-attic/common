require 'socket'

require 'netlink/constants'
require 'netlink/message'
require 'netlink/message_decoder'
require 'netlink/types'

module Netlink
  class Socket < ::Socket
    SENDTO_SOCKADDR = Netlink::Sockaddr.new.to_binary_s.freeze

    attr_reader :netlink_family

    def initialize(netlink_family)
      super(Netlink::PF_NETLINK, Socket::SOCK_RAW, netlink_family)
      @netlink_family = netlink_family
      @decoder = Netlink::MessageDecoder.for_family(netlink_family)
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

    # Subscribes to supplied multicast groups
    def subscribe(*groups)
      for group in groups
        setsockopt(Netlink::SOL_NETLINK, Netlink::NETLINK_ADD_MEMBERSHIP, group)
      end
    end

    # Unsubscribes from supplied multicast groups
    def unsubscribe(*groups)
      for group in groups
        setsockopt(Netlink::SOL_NETLINK, Netlink::NETLINK_DROP_MEMBERSHIP, group)
      end
    end

    def send_message(msg)
      sendmsg(msg.encode, 0, SENDTO_SOCKADDR)
    end

    def receive_message
      loop do
        data = recvmsg
        msg = @decoder.decode(data[0])
        unless msg.nl_header.type == Netlink::NLMSG_NOOP
          return msg
        end
      end
    end
  end
end
