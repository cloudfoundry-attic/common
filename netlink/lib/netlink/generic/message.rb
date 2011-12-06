require 'netlink/generic/types'
require 'netlink/message'
require 'netlink/message_decoder'
require 'netlink/types'

module Netlink
  module Generic

    class Message < Netlink::Message
      header :genl_header, Netlink::Generic::GeNlMsgHdr
    end

    class ControlMessage < Netlink::Generic::Message
      attribute :family_id,      Netlink::Attribute::UInt16,  :type => Netlink::Generic::CTRL_ATTR_FAMILY_ID
      attribute :family_name,    Netlink::Attribute::StringZ, :type => Netlink::Generic::CTRL_ATTR_FAMILY_NAME
      attribute :version,        Netlink::Attribute::UInt32,  :type => Netlink::Generic::CTRL_ATTR_VERSION
      attribute :max_attributes, Netlink::Attribute::UInt32,  :type => Netlink::Generic::CTRL_ATTR_MAXATTR
      attribute :header_size,    Netlink::Attribute::UInt32,  :type => Netlink::Generic::CTRL_ATTR_HDRSIZE

      def initialize(opts={})
        super(opts)
        self.nl_header.type      = Netlink::Generic::GENL_ID_CTRL
        self.nl_header.flags     = Netlink::NLM_F_REQUEST | Netlink::NLM_F_ACK
        self.genl_header.version = 1
        self.genl_header.cmd     = Netlink::Generic::CTRL_CMD_GETFAMILY
      end
    end
    Netlink::MessageDecoder.for_family(Netlink::NETLINK_GENERIC) \
                           .register_message(Netlink::Generic::GENL_ID_CTRL, Netlink::Generic::ControlMessage)
  end
end


