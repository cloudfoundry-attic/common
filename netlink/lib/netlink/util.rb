require 'netlink/constants'

module Netlink
  module Util
    PAD_BYTE  = [0].pack('C')

    class << self
      def align(length, alignto=Netlink::NLMSG_ALIGNTO)
        (length + alignto - 1) & ~(alignto - 1)
      end

      def pad(str, alignto=Netlink::NLMSG_ALIGNTO)
        nbytes_needed = align(str.length, alignto) - str.length
        if nbytes_needed
          str += PAD_BYTE * nbytes_needed
        end
        str
      end

      def could_read?(strio, nbytes)
        strio.size - strio.pos >= nbytes
      end
    end
  end
end
