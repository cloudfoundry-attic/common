require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe VCAP::Logging::SinkMap do
  before :all do
    @level_map = {
      :fatal  => 0,
      :info   => 1,
      :debug  => 2,
      :debug2 => 3,
    }
  end

  describe '#add_sink' do
    before :each do
      @sink_map = VCAP::Logging::SinkMap.new(@level_map)
    end

    it 'raises an error for an unknown level' do
      lambda { @sink_map.add_sink(:zazzle, :info, 'foo') }.should raise_error(ArgumentError)
      lambda { @sink_map.add_sink(:info, :zazzle, 'foo') }.should raise_error(ArgumentError)
    end

    it 'handles a single level range' do
      @sink_map.add_sink(:info, :info, 'foo')
      @sink_map.get_sinks(:info).should == ['foo']
      [:fatal, :debug, :debug2].each {|l| @sink_map.get_sinks(l).should == [] }
    end

    it 'handles a range with both start and end set' do
      @sink_map.add_sink(:debug, :info, 'foo')
      [:info, :debug].each {|l| @sink_map.get_sinks(l).should == ['foo'] }
      [:fatal, :debug2].each {|l| @sink_map.get_sinks(l).should == [] }
    end

    it 'handles a range with only an end set' do
      @sink_map.add_sink(nil, :info, 'foo')
      [:info, :debug, :debug2].each {|l| @sink_map.get_sinks(l).should == ['foo'] }
      @sink_map.get_sinks(:fatal).should == []
    end

    it 'handles a range with only a start set' do
      @sink_map.add_sink(:info, nil, 'foo')
      [:info, :fatal].each {|l| @sink_map.get_sinks(l).should == ['foo'] }
      [:debug, :debug2].each {|l| @sink_map.get_sinks(l).should == [] }
    end

    it 'handles a range with no start or end' do
      @sink_map.add_sink(nil, nil, 'foo')
      [:fatal, :info, :debug, :debug2].each {|l| @sink_map.get_sinks(l).should == ['foo'] }
    end

  end

  describe '#each_sink' do
    it 'maps over each sink only once' do
      sink_map = VCAP::Logging::SinkMap.new(@level_map)
      sink_map.add_sink(nil, nil, 'foo')
      sink_map.add_sink(:info, :info, 'bar')
      sinks = []
      sink_map.each_sink {|s| sinks << s }
      sinks.should == ['foo', 'bar']
    end
  end
end
