$LOAD_PATH.unshift(File.expand_path('../', __FILE__))
require 'spec_helper'
require 'netlink'

describe Netlink::Util do
  describe '.align' do
    it 'should not round up lengths that are multiples of the alignment' do
      Netlink::Util.align(0, 4).should == 0
      Netlink::Util.align(4, 4).should == 4
      Netlink::Util.align(8, 4).should == 8
    end

    it 'should round up lengths that are not multiples of the alignment' do
      (5...8).each do |len|
        Netlink::Util.align(len, 4).should == 8
      end
    end
  end

  describe '.pad' do
    it 'should append the correct number of padding bytes' do
      (5..8).each do |len|
        to_pad = "a" * len
        Netlink::Util.pad(to_pad, 4).length.should == 8
      end
    end
  end

  describe '.write_checked' do
    it 'should raise an instance of IOError on a partial write' do
      io = mock()
      io.should_receive(:write).with(any_args()).and_return(1)
      expect do
        Netlink::Util.write_checked(io, 'test')
      end.to raise_error(IOError)
    end
  end

  describe '.read_checked' do
    it 'should raise an instance of IOError on a partial read' do
      io = mock()
      io.should_receive(:read).with(any_args()).and_return("x")
      expect do
        Netlink::Util.read_checked(io, 4)
      end.to raise_error(IOError)
    end

    it 'should raise an instance of EOFError if read returns nil' do
      io = mock()
      io.should_receive(:read).with(any_args()).and_return(nil)
      expect do
        Netlink::Util.read_checked(io, 4)
      end.to raise_error(EOFError)
    end
  end
end
