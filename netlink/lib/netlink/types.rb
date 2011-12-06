require 'bindata'

require 'netlink/constants'
require 'netlink/util'

# Structs imported from linux/netlink.h
module Netlink
  class SockaddrNl < BinData::Record
    endian :little

    uint16 :family,  :initial_value => Netlink::PF_NETLINK
    uint16 :padding, :initial_value => 0
    uint32 :pid,     :initial_value => 0
    uint32 :groups,  :initial_value => 0
  end
  Sockaddr = SockaddrNl

  # Netlink message header. Precedes all netlink messages.
  class NlMsgHdr < BinData::Record
    endian :little

    uint32 :len,   :initial_value => 16         # Message length, padding included
    uint16 :type,  :initial_value => 0
    uint16 :flags, :initial_value => 0
    uint32 :seq,   :initial_value => 0          # Sequence number. Useful in conjunction w/ ACK.
    uint32 :pid,   :initial_value => 0          # PortID. Leave as is to have kernel fill in.

    def payload_len
      self.len - self.num_bytes
    end
  end

  # Netlink attribute header. Precedes all netlink attributes.
  class NlAttrHdrRaw < BinData::Record
    endian :little

    uint16 :len,  :initial_value => 4
    uint16 :type, :initial_value => 0
  end

  # BinData::Record defines accessors the first time an *instance* of
  # a class is instantiated. We have to play this nasty trick in order to be
  # able to override accessors for type.
  NlAttrHdrRaw.new

  class NlAttrHdr < NlAttrHdrRaw
    alias :get_type_raw :type
    alias :set_type_raw :type=

    def type
      typeval = get_type_raw
      typeval & Netlink::NLA_TYPE_MASK
    end

    def type=(newval)
      curflags = get_type_raw & (NLA_F_NESTED | NLA_F_NET_BYTEORDER)
      newval   = newval & Netlink::NLA_TYPE_MASK
      set_type_raw(curflags | newval)
    end

    def nested
      (get_type_raw & Netlink::NLA_F_NESTED) != 0
    end

    def nested?
      nested
    end

    def nested=(is_nested)
      if is_nested
        newval = get_type_raw | Netlink::NLA_F_NESTED
      else
        newval = get_type_raw & (~Netlink::NLA_F_NESTED)
      end
      set_type_raw(newval)
    end

    def network_byte_ordered
      (get_type_raw & Netlink::NLA_F_NET_BYTEORDER) != 0
    end

    def network_byte_ordered?
      network_byte_ordered
    end

    def network_byte_ordered=(is_nbo)
      if is_nbo
        newval = get_type_raw | Netlink::NLA_F_NET_BYTEORDER
      else
        newval = get_type_raw & (~Netlink::NLA_F_NET_BYTEORDER)
      end
      set_type_raw(newval)
    end

    def payload_len
      self.len - self.num_bytes
    end
  end
  NLA_HDRLEN = NlAttrHdr.new.num_bytes

  class NlMsgErr < BinData::Record
    endian :little

    int32      :error, :initial_value => 0
    nl_msg_hdr :msg
  end
end
