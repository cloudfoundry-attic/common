require 'netlink/coding_helpers'
require 'netlink/types'
require 'netlink/util'

module Netlink
  module Attribute

    class Base
      include Netlink::CodingHelpers

      attr_accessor :header
      attr_accessor :value

      def initialize(opts={})
        self.header      = Netlink::NlAttrHdr.new
        self.header.len  = opts[:len] if opts[:len]
        self.header.type = opts[:type] if opts[:type]
        self.value       = opts[:value] || nil
      end

      def write(io)
        encoded_value = encode_value(self.value)
        self.header.len = self.header.num_bytes + encoded_value.length

        self.header.write(io)
        Netlink::Util.write_checked(io, encoded_value)

        padding = Netlink::Util.get_padding_for_size(self.header.len)
        Netlink::Util.write_checked(io, padding)
      end

      def read(io, skip_header=false)
        self.header.read(io) unless skip_header

        raw_value = Netlink::Util.read_checked(io, self.header.payload_len)
        self.value = decode_value(raw_value)

        # Skip padding
        npadding_bytes = Netlink::Util.align(self.header.len) - self.header.len
        Netlink::Util.read_checked(io, npadding_bytes)
      end

      def encode_value(value)
        raise NotImplementedError
      end

      def decode_value(raw_value)
        raise NotImplementedError
      end
    end

    class Packed < Base
      class << self
        attr_accessor :pack_code
      end

      def encode_value(value)
        [value].pack(self.class.pack_code)
      end

      def decode_value(raw_value)
        raw_value.unpack(self.class.pack_code)[0]
      end
    end

    class String  < Packed; self.pack_code = 'a*'; end
    class StringZ < Packed; self.pack_code = 'Z*'; end
    class UInt8   < Packed; self.pack_code = 'C';  end
    class UInt16  < Packed; self.pack_code = 'S';  end
    class UInt32  < Packed; self.pack_code = 'L';  end
    class UInt64  < Packed; self.pack_code = 'Q';  end

  end
end
