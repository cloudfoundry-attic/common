$LOAD_PATH.unshift(File.expand_path('../', __FILE__))
require 'spec_helper'
require 'netlink'

describe Netlink do
  it 'should be able to send and receive messages' do
    sock = Netlink::Socket.new(Netlink::NETLINK_GENERIC)
    sock.bind

    msg = Netlink::Message.new
    msg.header.type  = Netlink::NLMSG_NOOP
    msg.header.flags = Netlink::NLM_F_REQUEST | Netlink::NLM_F_ACK
    msg.header.seq   = Time.now.to_i
    msg.append("HI")

    msg_encoded = msg.encode
    nbytes_written = sock.sendto(msg_encoded)
    nbytes_written.should == msg_encoded.length

    data = sock.recvmsg
    reply = Netlink::Message.decode(data[0])

    # Yes, this looks wrong. Netlink encodes ACKs in error messages sent
    # back from the kernel. The difference is that the 'error' field in the
    # nlmsgerr struct is set to zero and the original payload is not included.
    reply.header.type.should == Netlink::NLMSG_ERROR
    reply.header.seq.should == msg.header.seq

    # Check that the kernel sent back no error and our original message header
    errhdr = Netlink::NlMsgErr.read(reply.payload)
    errhdr.error.should == 0
    errhdr.msg.should == msg.header
  end
end
