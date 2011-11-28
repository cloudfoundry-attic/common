require 'netlink/message'
require 'netlink/types'

module Netlink

  class ErrorMessage < Netlink::Message
    header :err_header, Netlink::NlMsgErr
  end

end
