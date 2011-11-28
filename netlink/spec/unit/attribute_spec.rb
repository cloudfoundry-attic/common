$LOAD_PATH.unshift(File.expand_path('../', __FILE__))
require 'spec_helper'
require 'netlink'

class TestAttribute < Netlink::Attribute::Base
  def encode_value(value)
    value
  end

  def decode_value(raw_value)
    raw_value
  end
end

describe Netlink::Attribute::Base do
  describe '#initialize' do
    it 'should allow users to specify any of {:type, :len, :value}' do
      attr = TestAttribute.new(:type => 2, :len => 8, :value => "HI")
      attr.header.type.should == 2
      attr.header.len.should == 8
      attr.value.should  == "HI"
    end
  end

  describe '#write' do
    it 'should update the len header field to reflect the encoded value' do
      attr = TestAttribute.new(:value => "HI")
      attr.header.len.should == 4
      # Calls into write w/ StringIO
      attr.encode
      attr.header.len.should == attr.header.num_bytes + attr.value.length
    end

    it 'should pad the output on a 32bit boundary' do
      attr = TestAttribute.new(:value => "HI")
      encoded = attr.encode
      encoded.length.should == 8
    end
  end

  describe '#read' do
    it 'should decode encoded attributes' do
      attr = TestAttribute.new(:value => "HI", :type => 5)
      encoded = attr.encode
      # Calls into read w/ StringIO
      dec_attr = TestAttribute.decode(encoded)
      dec_attr.header.type == attr.header.type
      dec_attr.header.len == attr.header.type
      dec_attr.value == attr.value
    end

    it 'should skip padding bytes' do
      attr = TestAttribute.new(:value => "HI", :type => 5)
      io = StringIO.new(attr.encode)
      attr.header.len.should == 6
      TestAttribute.read(io)
      io.pos.should == 8
    end
  end
end

describe Netlink::Attribute::String do
  describe '#encode_value' do
    it 'should encode the value as a binary string' do
      encoded = Netlink::Attribute::String.new.encode_value("HI")
      encoded.should == "HI"
    end
  end

  describe '#decode_value' do
    it 'should decode the value as a binary string' do
      decoded = Netlink::Attribute::String.new.decode_value("HI\x00")
      decoded.should == "HI\x00"
    end
  end
end

describe Netlink::Attribute::StringZ do
  describe '#encode_value' do
    it 'should encode the value as a binary string with a null terminator' do
      encoded = Netlink::Attribute::StringZ.new.encode_value("HI\x00")
      encoded.should == "HI\x00\x00"
    end
  end

  describe '#decode_value' do
    it 'should decode the value as a binary string' do
      decoded = Netlink::Attribute::String.new.decode_value("HI\x00")
      decoded.should == "HI\x00"
    end
  end
end

describe Netlink::Attribute::UInt8 do
  describe '#encode_value' do
    it 'should encode the value as a single byte' do
      encoded = Netlink::Attribute::UInt8.new.encode_value(10)
      encoded.should == 10.chr
    end
  end

  describe '#decode_value' do
    it 'should decode the value from a single byte' do
      decoded = Netlink::Attribute::UInt8.new.decode_value(10.chr)
      decoded.should == 10
    end
  end
end

describe Netlink::Attribute::UInt16 do
  describe '#encode_value' do
    it 'should encode the value as a uint16' do
      encoded = Netlink::Attribute::UInt16.new.encode_value(10)
      encoded.should == [10].pack('S')
    end
  end

  describe '#decode_value' do
    it 'should decode the value from a uint16' do
      packed = [10].pack('S')
      decoded = Netlink::Attribute::UInt16.new.decode_value(packed)
      decoded.should == 10
    end
  end
end

describe Netlink::Attribute::UInt32 do
  describe '#encode_value' do
    it 'should encode the value as a uint32' do
      encoded = Netlink::Attribute::UInt32.new.encode_value(200_000)
      encoded.should == [200_000].pack('L')
    end
  end

  describe '#decode_value' do
    it 'should decode the value from a uint32' do
      packed = [200_000].pack('L')
      decoded = Netlink::Attribute::UInt32.new.decode_value(packed)
      decoded.should == 200_000
    end
  end
end

describe Netlink::Attribute::UInt64 do
  describe '#encode_value' do
    it 'should encode the value as a uint64' do
      encoded = Netlink::Attribute::UInt64.new.encode_value(10_000_000_000)
      encoded.should == [10_000_000_000].pack('Q')
    end
  end

  describe '#decode_value' do
    it 'should decode the value from a uint64' do
      packed = [10_000_000_000].pack('Q')
      decoded = Netlink::Attribute::UInt64.new.decode_value(packed)
      decoded.should == 10_000_000_000
    end
  end
end
