require File.join(File.dirname(__FILE__), '..', 'spec_helper')

require 'vcap/logging'

describe VCAP::Logging do
  before :each do
    VCAP::Logging.setup
  end

  describe '.setup' do
    it 'should create a root logger' do
      VCAP::Logging.setup
      VCAP::Logging.root_logger.should_not be_nil
    end

    it 'should pick a default log level for the root logger' do
      VCAP::Logging.setup
      VCAP::Logging.root_logger.log_level.should_not be_nil
    end
  end

  describe '.logger' do
    it 'should raise an exception if given a non string name' do
      lambda { VCAP::Logging.logger(5) }.should raise_error(ArgumentError)
    end

    it 'should create a new logger if one does not exist' do
      logger = VCAP::Logging.logger('foo.bar')
      logger.should_not be_nil
    end

    it 'should return the same logger for multiple calls' do
      logger = VCAP::Logging.logger('foo.bar')
      logger.should_not be_nil

      VCAP::Logging.logger('foo.bar').should == logger
    end

    it 'should set the parent logger to the root logger for loggers with no parents' do
      logger = VCAP::Logging.logger('foo.bar')
      logger.should_not be_nil
      logger.parent.should == VCAP::Logging.root_logger
    end

    it 'should set the parent logger to the correct parent if one exists' do
      parent = VCAP::Logging.logger('foo')
      parent.should_not be_nil

      child = VCAP::Logging.logger('foo.bar.baz')
      child.parent.should == parent
    end

    it 'should set the log level to that of its parent' do
      VCAP::Logging.root_logger.log_level = :warn
      VCAP::Logging.logger('foo').log_level.should == :warn
      VCAP::Logging.logger('foo').log_level = :info
      VCAP::Logging.logger('foo.bar').log_level.should == :info
    end

    it 'should correctly update the parent of children if inserted at an interior node' do
      VCAP::Logging.logger('foo.bar.baz').should_not be_nil
      VCAP::Logging.logger('foo.bar.jaz').should_not be_nil
      foo_bar_logger = VCAP::Logging.logger('foo.bar')
      foo_bar_logger.should_not be_nil
      VCAP::Logging.logger('foo.bar.baz').parent.should == foo_bar_logger
      VCAP::Logging.logger('foo.bar.jaz').parent.should == foo_bar_logger
      VCAP::Logging.logger('foo.jaz.zaz').should_not be_nil
      VCAP::Logging.logger('foo.jaz.caz').should_not be_nil
      VCAP::Logging.logger('foo.zaz').should_not be_nil

      foo_logger = VCAP::Logging.logger('foo')

      # Parent logger is foo.bar, shouldn't get touched
      VCAP::Logging.logger('foo.bar.baz').parent.should == foo_bar_logger
      VCAP::Logging.logger('foo.bar.jaz').parent.should == foo_bar_logger

      # Parents were previously the root, will now be 'foo'
      for name in %w[foo.bar foo.jaz.zaz foo.jaz.caz foo.zaz]
        VCAP::Logging.logger(name).parent.should == foo_logger
      end
    end
  end

  describe '.set_log_level' do
    it 'should raise an error if supplied with a non-string path' do
      lambda { VCAP::Logging.set_log_level(5, :error) }.should raise_error(ArgumentError)
    end

    it 'should raise an error if supplied with a level that is not a string or symbol' do
      lambda { VCAP::Logging.set_log_level('foo', 5) }.should raise_error(ArgumentError)
    end

    it 'should raise an error if supplied with an unknown level' do
      lambda { VCAP::Logging.set_log_level('foo', :zazzle) }.should raise_error(ArgumentError)
    end

    it 'should set the log level on all loggers that match the supplied regex' do
      level_map = {
        'foo.bar.baz' => [:debug, :error],
        'foo.bar.jaz' => [:debug, :error],
        'foo.bar'     => [:info,  :info],
        'foo'         => [:warn,  :warn],
      }

      for name, levels in level_map
        VCAP::Logging.logger(name).log_level = levels[0]
      end

      VCAP::Logging.set_log_level('foo\.bar\..*', :error)

      for name, levels in level_map
        VCAP::Logging.logger(name).log_level.should == levels[1]
      end
    end
  end

end
