require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe VCAP::Logging::LogRecord do
  describe '#initialize' do
    it "raises an exception if tags isn't an array" do
      lambda { VCAP::Logging::LogRecord.new(0, nil, 'zazzle') }.should raise_error(ArgumentError)
    end
  end
end
