ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
require 'bundler'
Bundler.setup

require 'netlink/generic'

unless ARGV.length == 1
  puts "Usage: ruby genl_get_family.rb [family name]"
  exit 1
end

sock = Netlink::Generic::Socket.new
sock.bind(Netlink::Sockaddr.new(:pid => Process.pid))

msg = Netlink::Generic::ControlMessage.new do |msg|
  msg.family_id   = Netlink::Generic::GENL_ID_CTRL
  msg.family_name = ARGV[0]
end

sock.send_message(msg)
reply = sock.receive_message
case reply
when Netlink::ErrorMessage
  if reply.err_header.error == -Errno::ENOENT::Errno
    puts "Unknown family"
  else
    puts "Received error reply, error: #{reply.err_header.error}"
  end

when Netlink::Generic::ControlMessage
  [:family_name, :family_id, :version, :max_attributes, :header_size].each do |name|
    val = reply.send(name)
    puts "%-14s = %s" % [name, val] if val
  end

else
  puts "Received unknown message, type: #{reply.nl_header.type}"

end


