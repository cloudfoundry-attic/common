= Overview =

This gem provides a toolkit for interfacing with Netlink in pure ruby.

= Caveat Emptor =

This gem is very much a work-in-progress. It can be used to do useful things in
its current state, but still has some rough edges (see Todo).

= Netlink 101 =

== Overview ==

Netlink provides an efficient mechanism for user-space to kernel-space and
user-space to user-space communication. It supports both unicast and multicast
communication and is implemented as a message oriented protocol using the BSD
sockets api. Sample use cases include updating routing tables, querying for
detailed task information, and receiving notifications when users exceed
disk quotas.

== Message format ==

The Netlink message format is fairly simple. All messages are composed of
a mandatory Netlink header, following by 0 or more family headers, followed by
the message payload. The majority of message payloads consist of a sequence
of attributes encoded using the TLV (Type, Length, Value) format. We attempt
to optimize for this case and provide a convenient DSL for declaring message
structure.

== Error Handling ==

Netlink provides two means of communicating errors back to the user: 1) through
the use of special error messages, and 2) through the BSD sockets api. The first
mechanism is used to signal errors pertaining to the various subsystems (invalid
arguments in requests, for example). The second mechanism is used to signal errors
that occur when transferring data between user-space and kernel-space. For example,
recvmsg() will return ENOBUFS if the kernel fails to transfer data to the user.

= Usage =

See the `example' directory.

= Todo =

== Must Have =

- Nested attribute support
- Multi-part message support

== Nice to Have =

- Pretty printing of messages
