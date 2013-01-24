require 'bindata'

# Imported from linux/genetlink.h
module Netlink
  module Generic
    class GeNlMsgHdr < BinData::Record
      endian :little

      uint8 :cmd,      :initial_value => 0
      uint8 :version,  :initial_value => 1
      uint16 :reserved, :initial_value => 0
    end
  end
end
