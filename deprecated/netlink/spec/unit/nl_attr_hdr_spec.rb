$LOAD_PATH.unshift(File.expand_path('../', __FILE__))
require 'spec_helper'
require 'netlink'

describe Netlink::NlAttrHdr do
  describe '#initialize' do
    it 'should preserve type' do
      attr = Netlink::NlAttrHdr.new(:type => Netlink::NLA_F_NESTED | Netlink::NLA_F_NET_BYTEORDER)
      attr.nested.should be_true
      attr.network_byte_ordered.should be_true
    end
  end

  describe '#nested=' do
    it 'should set the nested flag if passed true' do
      attr = Netlink::NlAttrHdr.new
      attr.nested.should be_false
      attr.nested = true
      attr.nested.should be_true
    end

    it 'should unset the nested flag if passed false' do
      attr = Netlink::NlAttrHdr.new(:type => Netlink::NLA_F_NESTED)
      attr.nested.should be_true
      attr.nested = false
      attr.nested.should be_false
    end
  end

  describe '#network_byte_ordered=' do
    it 'should set the network_byte_ordered flag if passed true' do
      attr = Netlink::NlAttrHdr.new
      attr.network_byte_ordered.should be_false
      attr.network_byte_ordered = true
      attr.network_byte_ordered.should be_true
    end

    it 'should unset the network_byte_ordered flag if passed false' do
      attr = Netlink::NlAttrHdr.new(:type => Netlink::NLA_F_NET_BYTEORDER)
      attr.network_byte_ordered.should be_true
      attr.network_byte_ordered = false
      attr.network_byte_ordered.should be_false
    end
  end

  describe '#type' do
    it 'should mask out the nested and network-byte-order properties' do
      attr = Netlink::NlAttrHdr.new(:type => Netlink::NLA_F_NESTED | Netlink::NLA_F_NET_BYTEORDER)
      attr.type.should == 0
    end
  end

  describe '#type=' do
    it 'should preserve the nested and network_byte_ordered flags' do
      attr = Netlink::NlAttrHdr.new(:type => Netlink::NLA_F_NESTED)
      attr.nested.should be_true
      attr.network_byte_ordered.should be_false
      attr.type = Netlink::NLA_F_NET_BYTEORDER
      attr.nested.should be_true
      attr.network_byte_ordered.should be_false
    end
  end

  describe '#to_binary_s' do
    it 'should preserve all flags in the type field' do
      attr = Netlink::NlAttrHdr.new
      attr.nested = true
      attr.network_byte_ordered = false
      attr.type = 12345
      encoded = attr.to_binary_s
      dec_attr = Netlink::NlAttrHdr.read(encoded)
      dec_attr.should == attr
    end
  end

end
