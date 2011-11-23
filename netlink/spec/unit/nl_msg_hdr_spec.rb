$LOAD_PATH.unshift(File.expand_path('../', __FILE__))
require 'spec_helper'
require 'netlink'

describe Netlink::NlMsgHdr do
  describe '#payload_len' do
    it 'should return the length of the message minus header length' do
      hdr = Netlink::NlMsgHdr.new
      hdr.len += 10
      hdr.payload_len.should == 10
    end
  end
end
