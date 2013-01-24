$LOAD_PATH.unshift(File.expand_path('../', __FILE__))
require 'spec_helper'
require 'netlink'

describe Netlink do
  it 'should be able to send and receive messages' do
    sock = Netlink::Socket.new(Netlink::NETLINK_GENERIC)
    sock.bind

    msg = Netlink::Message.new
    msg.nl_header.type  = Netlink::NLMSG_NOOP
    msg.nl_header.flags = Netlink::NLM_F_REQUEST | Netlink::NLM_F_ACK
    msg.nl_header.seq   = Time.now.to_i
    msg.payload = "HI"

    nbytes_written = sock.send_message(msg)
    nbytes_written.should == msg.encode.length

    reply = sock.receive_message

    # Yes, this looks wrong. Netlink encodes ACKs in error messages sent
    # back from the kernel. The difference is that the 'error' field in the
    # nlmsgerr struct is set to zero and the original payload is not included.
    reply.nl_header.type.should == Netlink::NLMSG_ERROR
    reply.nl_header.seq.should == msg.nl_header.seq

    # Check that the kernel sent back no error and our original message header
    reply.err_header.error.should == 0
    reply.err_header.msg.should == msg.nl_header
  end
end
