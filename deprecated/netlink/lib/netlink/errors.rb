module Netlink
  class Error < StandardError; end

  class DecodeError            < StandardError; end # Base error class during decoding
  class IncompleteMessageError < DecodeError;   end # Need more data to continue decoding
end
