$LOAD_PATH.unshift(File.expand_path('../', __FILE__))
require 'spec_helper'
require 'netlink'

describe Netlink::Message do
  describe '#append' do
    it 'should add data to the payload' do
      msg = Netlink::Message.new
      msg.append("HI")
      msg.payload.should == "HI"
      msg.append("THERE")
      msg.payload.should == "HITHERE"
    end

    it 'should encode bindata records' do
      sockaddr = Netlink::Sockaddr.new
      msg = Netlink::Message.new
      msg.append(sockaddr)
      msg.payload.should == sockaddr.to_binary_s
    end
  end

  describe '#encode' do
    it 'should pad the message on a 32 bit boundary' do
      msg = Netlink::Message.new
      payload = "HI"
      msg.append(payload)
      msg.encode.length.should == Netlink::Util.align(msg.header.num_bytes + payload.length)
    end

    it 'should not update the header length of unencoded message' do
      msg = Netlink::Message.new
      payload = "HI"
      msg.append(payload)
      old_len = msg.header.len
      msg.encode
      msg.header.len.should == old_len
    end
  end

  describe '#decode' do
    it 'should decode encoded messages' do
      orig_msg = Netlink::Message.new
      payload = "HI"
      orig_msg.append(payload)
      encoded = orig_msg.encode
      decoded = Netlink::Message.decode(encoded)
      decoded.payload.should == Netlink::Util.pad(payload)
    end

    it 'should raise Netlink::IncompleteMessageError if supplied with partial data' do
      # Less than a header's worth
      short_msg = "A"
      expect do
        Netlink::Message.decode(short_msg)
      end.to raise_error(Netlink::IncompleteMessageError)

      # Partial payload
      msg = Netlink::Message.new
      msg.append("HELLO THERE")
      encoded = msg.encode.slice(0, msg.header.len - 4)
      expect do
        Netlink::Message.decode(encoded)
      end.to raise_error(Netlink::IncompleteMessageError)
    end
  end
end
