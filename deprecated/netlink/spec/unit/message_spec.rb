$LOAD_PATH.unshift(File.expand_path('../', __FILE__))
require 'spec_helper'
require 'netlink'

class TestMessage < Netlink::Message
end

describe Netlink::Message do
  describe '#encode' do
    it 'should pad the message on a 32 bit boundary' do
      msg = Netlink::Message.new
      msg.payload = "HI"
      msg.encode.length.should == Netlink::Util.align(msg.nl_header.num_bytes + msg.payload.length)
    end

    it 'should not update the header length of unencoded message' do
      msg = Netlink::Message.new
      msg.payload = "HI"
      old_len = msg.nl_header.len
      msg.encode
      msg.nl_header.len.should == old_len
    end
  end

  describe '#decode' do
    it 'should decode encoded messages' do
      orig_msg = Netlink::Message.new
      orig_msg.payload = "HI"
      encoded = orig_msg.encode
      decoded = Netlink::Message.decode(encoded)
      decoded.payload.should == Netlink::Util.pad(orig_msg.payload)
    end

    it 'should raise IOError if supplied with partial data' do
      # Less than a header's worth
      short_msg = "A"
      expect do
        Netlink::Message.decode(short_msg)
      end.to raise_error(IOError)

      # Partial payload
      msg = Netlink::Message.new
      msg.payload = "HELLO THERE"
      encoded = msg.encode.slice(0, msg.nl_header.len - 4)
      expect do
        Netlink::Message.decode(encoded)
      end.to raise_error(IOError)
    end
  end

  describe '.header' do
    it 'should define accessors for declared headers' do
      TestMessage.header :test, Netlink::NlMsgHdr
      testmsg = TestMessage.new
      testmsg.test.class.should == Netlink::NlMsgHdr
      testmsg.test = 1
      testmsg.test.should == 1
    end

    it 'should raise an error if one attempts to redeclare an existing header' do
      expect do
        HeaderTest.header :test, Netlink::NlMsgHdr
      end.to raise_error
    end
  end

  describe '.attribute' do
    it 'should define accessors for declared attributes' do
      TestMessage.attribute :attr, Netlink::Attribute::String, :type => 1
      testmsg = TestMessage.new
      testmsg.attr.should be_nil
      testmsg.attr = "HI"
      testmsg.attr.should == "HI"
    end
  end

  describe 'when subclassed' do
    class TestMessageParent < Netlink::Message
      header    :parent_header, Netlink::NlMsgHdr
      attribute :parent_attribute, Netlink::Attribute::String, :type => 2
    end

    class TestMessageChild < TestMessageParent
      header :child_header, Netlink::NlMsgHdr
      attribute :child_attribute, Netlink::Attribute::String, :type => 3
    end

    it 'should inherit any previously defined headers or attributes' do
      TestMessageChild.headers.should == [:nl_header, :parent_header, :child_header]
      msg = TestMessageChild.new
      msg.nl_header.class.should == Netlink::NlMsgHdr
      msg.parent_header.class.should == Netlink::NlMsgHdr
      TestMessageChild.attributes.should == [:parent_attribute, :child_attribute]
    end

    it 'should not add any headers or attributes to its parent' do
      TestMessageParent.headers.should == [:nl_header, :parent_header]
      TestMessageParent.attributes.should == [:parent_attribute]
    end
  end
end
