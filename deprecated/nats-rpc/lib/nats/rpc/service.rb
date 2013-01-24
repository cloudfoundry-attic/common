module NATS
  module RPC
    class Service

      class << self
        def methods
          @methods ||= {}
        end

        def export(name, options = {})
          methods[name.to_s] = Method.new(name.to_s, options)
        end

        class Method

          attr_reader :name
          attr_reader :options

          def initialize(name, options)
            @name = name
            @options = options
          end
        end
      end

      # Proxy to class
      def name
        self.class.name
      end

      # Dispatch a request to this service to the right method, if it exists
      def execute!(request)
        if self.class.methods.has_key?(request.method.to_s)
          send(request.method.to_sym, request)
        else
          raise Error.new("undefined service method `#{request.method}' on #{self.name}")
        end
      end

      class Error < StandardError

        attr_reader :message

        def initialize(message = nil)
          super(message)
        end

        def self.string_to_class(str)
          str.split("::").inject(Kernel) do |parent, const|
            parent.const_get(const)
          end
        end

        def self.from_hash(hash)
          string_to_class(hash["class"]).new(hash["message"])
        end

        def self.to_hash(error)
          { "class" => error.class.name,
            "message" => error.message }
        end
      end
    end
  end # module RPC
end # module NATS
