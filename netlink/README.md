= Overview =

This provides a toolkit for interfacing with Netlink in pure ruby. It
is very much a work in progress, but you should be able to do useful
things with it in its current state.It introduces a new socket type,
`Netlink::Socket`, for communicating with the various netlink
subsystems as well as abstractions for creating and parsing netlink
messages. Currently, message creation is somewhat tedious, however, it
is expected that this will become less so as the library evolves.

= Sample usage =

The following sample shows how to check if the generic netlink family
is available for use.

    require 'netlink'
    sock = Netlink::Socket.new(Netlink::NETLINK_GENERIC)
    sock.bind

    msg = Netlink::Message.new
    msg.header.type  = Netlink::NLMSG_NOOP
    msg.header.flags = Netlink::NLM_F_REQUEST | Netlink::NLM_F_ACK
    msg.header.seq   = Time.now.to_i

    sock.sendto(msg.encode)
    data = sock.recvmsg

    reply = Netlink::Message.decode(data[0])
    errmsg = Netlink::NlMsgErr.read(reply.payload)
    if errmsg.error > 0
      puts "Unavailable"
    else
      puts "Available"
    end

More examples will be added to the `example` directory over time.