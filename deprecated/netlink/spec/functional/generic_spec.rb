$LOAD_PATH.unshift(File.expand_path('../', __FILE__))
require 'spec_helper'
require 'netlink'
require 'netlink/generic'

describe Netlink::Generic::ControlMessage do
  # Try to query the generic netlink interface for an unknown family
  it 'should be able to send and receive control messages' do
    sock = Netlink::Socket.new(Netlink::NETLINK_GENERIC)
    sock.bind

    msg = Netlink::Generic::ControlMessage.new
    msg = Netlink::Generic::ControlMessage.new do |msg|
      msg.family_id   = Netlink::Generic::GENL_ID_CTRL
      msg.family_name = 'does-not-exist'
    end

    sock.send_message(msg)
    reply = sock.receive_message

    reply.class.should == Netlink::ErrorMessage
    reply.err_header.error.should == -Errno::ENOENT::Errno
  end
end
