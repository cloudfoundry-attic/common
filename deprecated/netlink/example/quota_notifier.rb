ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
require 'bundler'
Bundler.setup

require 'hexdump'
require 'logger'
require 'netlink/generic'

trap('INT') { exit }

sock = Netlink::Generic::Socket.new
sock.bind(Netlink::Sockaddr.new(:pid => Process.pid))

msg = Netlink::Generic::ControlMessage.new do |msg|
  msg.family_id   = Netlink::Generic::GENL_ID_CTRL
  msg.family_name = "VFS_DQUOT"
end

sock.send_message(msg)
reply = sock.receive_message

log = Logger.new(STDOUT)
log.info("Quota family id: #{reply.family_id}")
sock.subscribe(reply.family_id)

log.info("Waiting for notifications")

# This should be moved to its own gem

QUOTA_NL_A_UNSPEC     = 0
QUOTA_NL_A_QTYPE      = 1
QUOTA_NL_A_EXCESS_ID  = 2
QUOTA_NL_A_WARNING    = 3
QUOTA_NL_A_DEV_MAJOR  = 4
QUOTA_NL_A_DEV_MINOR  = 5
QUOTA_NL_A_CAUSED_ID  = 6

class QuotaNotification < Netlink::Generic::Message
  attribute :qtype,     Netlink::Attribute::UInt32, :type => QUOTA_NL_A_QTYPE
  attribute :excess_id, Netlink::Attribute::UInt64, :type => QUOTA_NL_A_EXCESS_ID
  attribute :warn_type, Netlink::Attribute::UInt32, :type => QUOTA_NL_A_WARNING
  attribute :dev_major, Netlink::Attribute::UInt32, :type => QUOTA_NL_A_DEV_MAJOR
  attribute :dev_minor, Netlink::Attribute::UInt32, :type => QUOTA_NL_A_DEV_MINOR
  attribute :caused_id, Netlink::Attribute::UInt64, :type => QUOTA_NL_A_CAUSED_ID
end
decoder = Netlink::MessageDecoder.for_family(Netlink::NETLINK_GENERIC)
decoder.register_message(reply.family_id, QuotaNotification)

loop do
  note = sock.receive_message
  case note
  when Netlink::ErrorMessage
    unless note.err_header.error == 0
      log.error("Received unexpected error message from kernel: #{note.err_header.error}")
      exit 1
    end
  when QuotaNotification
    log.info("Quota Notification: qtype=#{note.qtype} excess_id=#{note.excess_id} warn_type=#{note.warn_type} dev_major=#{note.dev_major} dev_minor=#{note.dev_minor} caused_id=#{note.caused_id}")
  else
    log.warn("Unknown message, type=#{note.nl_header.type}")
  end
end
