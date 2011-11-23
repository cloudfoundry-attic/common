ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
require 'bundler'
Bundler.setup

require 'hexdump'
require 'logger'
require 'netlink'

def log_hexdump(logger, level, data)
  dump = StringIO.new
  data.hexdump(:output => dump)
  dump.rewind
  dump.lines.each do |line|
    logger.send(level, line.chomp)
  end
end

log = Logger.new(STDOUT)
sock = Netlink::Socket.new(Netlink::NETLINK_GENERIC)
sockaddr = Netlink::Sockaddr.new(:pid => Process.pid)
sock.bind(sockaddr)

msg = Netlink::Message.new
msg.header.type  = Netlink::NLMSG_NOOP
msg.header.flags = Netlink::NLM_F_REQUEST | Netlink::NLM_F_ACK
msg.header.seq   = Time.now.to_i
msg.header.pid   = Process.pid

enc_msg = msg.encode
nbytes_written = sock.sendto(enc_msg)
log.info("Wrote #{nbytes_written} bytes")
log_hexdump(log, :info, enc_msg)

data = sock.recvmsg
log.info("Received #{data[0].length} bytes")
log_hexdump(log, :info, data[0])

reply = Netlink::Message.decode(data[0])
log.info("Type: #{reply.header.type}")
error = Netlink::NlMsgErr.read(reply.payload)
log.info("Error: #{error.error}")

