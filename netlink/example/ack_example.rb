ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
require 'bundler'
Bundler.setup

require 'logger'
require 'netlink'

sock = Netlink::Socket.new(Netlink::NETLINK_GENERIC)
sockaddr = Netlink::Sockaddr.new(:pid => Process.pid)
sock.bind(sockaddr)

msg = Netlink::Message.new
msg.nl_header.type  = Netlink::NLMSG_NOOP
msg.nl_header.flags = Netlink::NLM_F_REQUEST | Netlink::NLM_F_ACK
msg.nl_header.seq   = Time.now.to_i
msg.nl_header.pid   = Process.pid

log = Logger.new(STDOUT)
nbytes_written = sock.send_message(msg)
log.info("Wrote #{nbytes_written} bytes")

reply = sock.receive_message

case reply
when Netlink::ErrorMessage
  log.info("Type : #{reply.nl_header.type}")
  log.info("Error: #{reply.err_header.error}")

else
  log.warn("Received unexpected type: #{reply.nl_header.type}")
end
