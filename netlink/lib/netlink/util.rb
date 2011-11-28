require 'netlink/constants'

module Netlink
  module Util
    PAD_BYTE  = [0].pack('C')

    class << self
      def align(length, alignto=Netlink::NLMSG_ALIGNTO)
        # Round to the nearest multiple of alignto
        (length + alignto - 1) & ~(alignto - 1)
      end

      # Pads the supplied string until aligned
      def pad(str, alignto=Netlink::NLMSG_ALIGNTO)
        nbytes_needed = align(str.length, alignto) - str.length
        if nbytes_needed
          str += PAD_BYTE * nbytes_needed
        end
        str
      end

      def get_padding_for_size(size, alignto=Netlink::NLMSG_ALIGNTO)
        nbytes_needed = align(size, alignto) - size
        PAD_BYTE * nbytes_needed
      end

      # Writes +bytes+ to +io+ and raises an error if the data is partially
      # written.
      def write_checked(io, bytes)
        nbytes_written = io.write(bytes)
        unless nbytes_written == bytes.length
          raise IOError, "Failed to write #{bytes.length} bytes"
        end
        nbytes_written
      end

      # Reads +nbytes+ bytes from +io+ and raises an error if fewer than
      # +nbytes+ bytes were read.
      def read_checked(io, nbytes)
        bytes = io.read(nbytes)
        raise EOFError if bytes == nil
        raise IOError, "Failed to read #{nbytes}" if bytes.length < nbytes
        bytes
      end

    end
  end
end
