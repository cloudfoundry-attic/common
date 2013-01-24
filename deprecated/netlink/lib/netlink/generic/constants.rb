require 'netlink/constants'

# Imported from linux/genetlink.h
module Netlink
  module Generic
    GENL_NAMSIZ      = 16

    GENL_MIN_ID      = Netlink::NLMSG_MIN_TYPE
    GENL_MAX_ID      = 1023

    GENL_ID_GENERATE = 0
    GENL_ID_CTRL     = Netlink::NLMSG_MIN_TYPE

    # Constants for generic netlink controller

    CTRL_CMD_UNSPEC       = 0
    CTRL_CMD_NEWFAMILY    = 1
    CTRL_CMD_DELFAMILY    = 2
    CTRL_CMD_GETFAMILY    = 3
    CTRL_CMD_NEWOPS       = 4
    CTRL_CMD_DELOPS       = 5
    CTRL_CMD_GETOPS       = 6
    CTRL_CMD_NEWMCAST_GRP = 7
    CTRL_CMD_DELMCAST_GRP = 8
    CTRL_CMD_GETMCAST_GRP = 9
    CTRL_CMD_MAX          = CTRL_CMD_GETMCAST_GRP

    CTRL_ATTR_UNSPEC       = 0
    CTRL_ATTR_FAMILY_ID    = 1
    CTRL_ATTR_FAMILY_NAME  = 2
    CTRL_ATTR_VERSION      = 3
    CTRL_ATTR_HDRSIZE      = 4
    CTRL_ATTR_MAXATTR      = 5
    CTRL_ATTR_OPS          = 6
    CTRL_ATTR_MCAST_GROUPS = 7
    CTRL_ATTR_MAX          = CTRL_ATTR_MCAST_GROUPS

    CTRL_ATTR_OP_UNSPEC = 0
    CTRL_ATTR_OP_ID     = 1
    CTRL_ATTR_OP_FLAGS  = 2
    CTRL_ATTR_OP_MAX    = CTRL_ATTR_OP_FLAGS

    CTRL_ATTR_MCAST_GRP_UNSPEC = 0
    CTRL_ATTR_MCAST_GRP_NAME   = 1
    CTRL_ATTR_MCAST_GRP_ID     = 2
    CTRL_ATTR_MCAST_GRP_MAX    = CTRL_ATTR_MCAST_GRP_ID
  end
end
