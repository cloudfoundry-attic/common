module VCAP
  module Logging
    class << self

      def assert_kind_of(name, val, klass)
        raise ArgumentError, "#{name} must be an instance of #{klass}, instace of #{val.class} given." unless val.kind_of?(klass)
      end

    end
  end
end
