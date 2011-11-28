require 'bindata'
require 'set'
require 'stringio'

require 'netlink/attribute'
require 'netlink/coding_helpers'
require 'netlink/constants'
require 'netlink/types'

module Netlink

  # Raw netlink messages are fairly simple: they consist of a mandatory header
  # (Netlink::NlMsgHdr) followed by an optional payload. The entire message
  # (header + body) is aligned on a 32 bit boundary and necessary padding bytes
  # will be appended when the message is encoded.

  class Message
    include Netlink::CodingHelpers

    AttributeSpec = Struct.new(:name, :klass, :type)

    class << self
      # Injects the already defined headers and attributes into
      # the class that is inheriting from us
      def inherited(klass)
        copy_headers(klass)
        copy_attributes(klass)
      end

      def headers
        @headers ||= []
        @headers
      end

      def header(name, klass)
        name = name.to_sym
        raise "#{name} already defined" if method_defined?(name)

        self.headers << name

        # Define getter (autovivifies header)
        define_method(name) do
          header = instance_variable_get("@#{name}")
          unless header
            header = klass.new
            instance_variable_set("@#{name}", header)
          end
          header
        end

        # Define setter
        define_method("#{name}=") do |val|
          instance_variable_set("@#{name}", val)
        end
      end

      def attributes_by_type
        @attributes_by_type ||= {}
        @attributes_by_type
      end

      def attributes
        self.attributes_by_type.values.map {|attr| attr.name }
      end

      def attribute(name, klass, ctor_args={})
        name = name.to_sym
        raise "#{name} already defined" if method_defined?(name)
        raise "You must supply :type" unless ctor_args.has_key?(:type)

        self.attributes_by_type[ctor_args[:type]] = AttributeSpec.new(name, klass, ctor_args[:type])

        # Define getter
        define_method(name) do
          attr = instance_variable_get("@#{name}")
          if attr
            attr.value
          else
            nil
          end
        end

        # Define setter. Materializes raw attribute on first assignment.
        define_method("#{name}=".to_sym) do |val|
          attr = instance_variable_get("@#{name}")
          unless attr
            attr = klass.new(ctor_args)
            instance_variable_set("@#{name}", attr)
          end
          attr.value = val
        end
      end

      private

      def copy_headers(klass)
        dup_headers = self.headers.dup
        klass.instance_eval { instance_variable_set("@headers", dup_headers) }
      end

      def copy_attributes(klass)
        dup_attrs = self.attributes_by_type.dup
        klass.instance_eval { instance_variable_set("@attributes_by_type", dup_attrs) }
      end
    end

    header :nl_header, Netlink::NlMsgHdr
    attr_reader :headers_size
    attr_accessor :payload

    def initialize(opts={})
      initialize_headers(opts)
      initialize_attributes(opts)
      @headers_size = self.class.headers.inject(0) {|accum, name| accum + send(name).num_bytes }
      self.payload = opts[:payload] || ''
      yield self if block_given?
      self
    end

    def write(io)
      unless self.class.attributes_by_type.empty?
        self.payload = encode_attributes
      end
      padded_payload = Netlink::Util.pad(self.payload)
      self.nl_header.len = self.headers_size + padded_payload.length

      for header in self.class.headers
        send(header).write(io)
      end

      Netlink::Util.write_checked(io, padded_payload)
    end

    def read(io, skip_nl_header=false)
      for header in self.class.headers
        next if header == :nl_header && skip_nl_header
        send(header).read(io)
      end

      self.payload = Netlink::Util.read_checked(io, self.nl_header.len - self.headers_size)

      unless self.class.attributes_by_type.empty?
        decode_attributes(self.payload)
      end
    end

    private

    def initialize_headers(opts={})
      for header in self.class.headers
        if opts.has_key?(header)
          send("#{header}=".to_sym, opts[header])
        end
      end
    end

    def initialize_attributes(opts={})
      for attr_spec in self.class.attributes_by_type.values
        if opts.has_key?(attr_spec.name)
          send("#{attr_spec.name}=".to_sym, opts[attr_spec.name])
        end
      end
    end

    def encode_attributes
      io = StringIO.new
      for attr_spec in self.class.attributes_by_type.values
        attr = instance_variable_get("@#{attr_spec.name}")
        if attr
          attr.write(io)
        end
      end
      io.string
    end

    def decode_attributes(payload)
      io = StringIO.new(payload)
      begin
        loop do
          attr_hdr  = Netlink::NlAttrHdr.read(io)
          attr_spec = self.class.attributes_by_type[attr_hdr.type]
          if attr_spec
            attr = attr_spec.klass.new
            attr.header = attr_hdr
            attr.read(io, true)
            send("#{attr_spec.name}=".to_sym, attr.value)
          else
            # Don't know how to decode; discard attribute. We may be talking
            # to newer code in the kernel.
            attr = Netlink::Attribute::String.new(:header => attr_hdr)
            attr.read(io, true)
          end
        end
      rescue EOFError
      end
    end
  end

end
