# Constants imported from linux/netlink.h
module Netlink
  PF_NETLINK  = 16
  SOL_NETLINK = 270

  NETLINK_ROUTE           = 0     # Routing/device hook
  NETLINK_UNUSED          = 1     # Unused number
  NETLINK_USERSOCK        = 2     # Reserved for user mode socket protocols
  NETLINK_FIREWALL        = 3     # Firewalling hook
  NETLINK_INET_DIAG       = 4     # INET socket monitoring
  NETLINK_NFLOG           = 5     # netfilter/iptables ULOG
  NETLINK_XFRM            = 6     # ipsec
  NETLINK_SELINUX         = 7     # SELinux event notifications
  NETLINK_ISCSI           = 8     # Open-iSCSI
  NETLINK_AUDIT           = 9     # auditing
  NETLINK_FIB_LOOKUP      = 10
  NETLINK_CONNECTOR       = 11
  NETLINK_NETFILTER       = 12    # netfilter subsystem
  NETLINK_IP6_FW          = 13
  NETLINK_DNRTMSG         = 14    # DECnet routing messages
  NETLINK_KOBJECT_UEVENT  = 15    # Kernel messages to userspace
  NETLINK_GENERIC         = 16
  NETLINK_SCSI_TRANSPORT  = 18
  NETLINK_ECRYPT_FS       = 19

  # Message flags
  NLM_F_REQUEST           = 1     # All requests from userspace to kernelspace must have this set
  NLM_F_MULTI             = 2     # Multipart message, terminated by NLMSG_DONE
  NLM_F_ACK               = 4     # Kernel will ack this message.
  NLM_F_ECHO              = 8     # Kernel will echo this message.

  # Modifiers to GET requests (requesting info from kernel).

  NLM_F_ROOT              = 0x100 # Specify tree root
  NLM_F_MATCH             = 0x200 # Return all matching
  NLM_F_ATOMIC            = 0x400 # Atomic get
  NLM_F_DUMP              = NLM_F_ROOT | NLM_F_MATCH

  # Modifiers to NEW requests (updating info in kernel).

  NLM_F_REPLACE           = 0x100 # Override existing config
  NLM_F_EXCL              = 0x200 # Don't touch if config exists
  NLM_F_CREATE            = 0x400 # Create, if not exist
  NLM_F_APPEND            = 0x800

  NLMSG_ALIGNTO           = 4     # Message MUST be aligned to a 32bit boundary

  # Request types. Anything less than NLMSG_MIN_TYPE is a control message
  NLMSG_MIN_TYPE          = 0x10

  NLMSG_NOOP              = 0x1   # Do nothing. Useful for checking if a bus is available.
  NLMSG_ERROR             = 0x2
  NLMSG_DONE              = 0x3   # End of dump.
  NLMSG_OVERRUN           = 0x4   # Data lost. Supposedly unused.

  NETLINK_ADD_MEMBERSHIP  = 1
  NETLINK_DROP_MEMBERSHIP = 2
  NETLINK_PKTINFO         = 3
  NETLINK_BROADCAST_ERROR = 4
  NETLINK_NO_ENOBUFS      = 5

  # Attributes

  NLA_F_NESTED            = 1 << 15 # Attr contains other attrs
  NLA_F_NET_BYTEORDER     = 1 << 14 # Value in network byteorder
  NLA_TYPE_MASK           = ~(NLA_F_NESTED | NLA_F_NET_BYTEORDER)
end
