require 'stringio'

module Netlink

  module CodingHelpers
    class << self
      def included(base)
        base.extend(ClassMethods)
      end
    end

    module ClassMethods
      def decode(bytes, *args)
        ret = new
        ret.decode(bytes, *args)
        ret
      end

      def read(io, *args)
        ret = new
        ret.read(io, *args)
        ret
      end
    end

    def encode(*args)
      io = StringIO.new
      write(io, *args)
      io.string
    end

    def decode(bytes, *args)
      io = StringIO.new(bytes)
      read(io, *args)
    end
  end

end
