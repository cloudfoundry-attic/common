require 'stringio'

require 'netlink/constants'
require 'netlink/message'
require 'netlink/error_message'

module Netlink

  class MessageDecoder
    class << self
      def for_family(family)
        @decoder_by_family ||= {}
        @decoder_by_family[family] ||= MessageDecoder.new
        @decoder_by_family[family]
      end
    end

    def initialize
      # Control messages are the same across all families
      @message_by_type = {
        Netlink::NLMSG_NOOP    => Netlink::Message,
        Netlink::NLMSG_ERROR   => Netlink::ErrorMessage,
        Netlink::NLMSG_DONE    => Netlink::Message,
        Netlink::NLMSG_OVERRUN => Netlink::Message,
      }
    end

    def register_message(type, klass)
      @message_by_type[type] = klass
    end

    def decode(str)
      io = StringIO.new(str)
      read(io)
    end

    def read(io)
      header = Netlink::NlMsgHdr.read(io)
      klass = @message_by_type[header.type]
      klass ||= Netlink::Message
      ret = klass.new
      ret.nl_header = header
      ret.read(io, true)
      ret
    end
  end

end
