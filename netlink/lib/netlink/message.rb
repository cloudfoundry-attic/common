require 'bindata'
require 'stringio'

require 'netlink/constants'
require 'netlink/errors'
require 'netlink/types'

module Netlink

  # Raw netlink messages are fairly simple: they consist of a mandatory header
  # (Netlink::NlMsgHdr) follow by an optional payload. The entire message
  # (header + body) is aligned on a 32 bit boundary and necessary padding bytes
  # will be appended when the message is encoded.

  class Message < BinData::Record
    HEADER_SIZE = Netlink::NlMsgHdr.new.num_bytes

    class << self
      def decode(enc_msg)
        # XXX - This is kind of gross, but convenient. Remove?
        if enc_msg.kind_of?(String)
          enc_msg = StringIO.new(enc_msg)
        end
        dec_msg = new
        unless Netlink::Util.could_read?(enc_msg, HEADER_SIZE)
          raise Netlink::IncompleteMessageError
        end
        dec_msg.header = Netlink::NlMsgHdr.read(enc_msg)

        unless Netlink::Util.could_read?(enc_msg, dec_msg.header.payload_len)
          raise Netlink::IncompleteMessageError
        end
        dec_msg.payload = enc_msg.read(dec_msg.header.payload_len)
        dec_msg
      end
    end

    attr_accessor :header
    attr_accessor :payload

    def initialize
      @header = Netlink::NlMsgHdr.new
      @payload = ''
    end

    def append(datum)
      if datum.kind_of?(BinData::Record)
        datum = datum.to_binary_s
      end
      @payload += datum
      @header.len += datum.length
    end

    def encode
      padded_payload = Netlink::Util.pad(@payload)
      hdr = @header
      unless padded_payload.length == @payload.length
        hdr = @header.dup
        hdr.len += (padded_payload.length - @payload.length)
      end
      hdr.to_binary_s + padded_payload
    end

    def to_s
      encode
    end
  end
end
