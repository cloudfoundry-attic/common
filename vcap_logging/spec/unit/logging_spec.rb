require File.join(File.dirname(__FILE__), '..', 'spec_helper')

require 'fileutils'
require 'tmpdir'

require 'vcap/logging'

describe VCAP::Logging do
  before :each do
    VCAP::Logging.reset
  end

  describe '.init' do
    it 'should pick a default log level' do
      VCAP::Logging.default_log_level.should_not be_nil
    end
  end

  describe '.logger' do
    it 'should create a new logger if one does not exist' do
      logger = VCAP::Logging.logger('foo.bar')
      logger.should_not be_nil
    end

    it 'should return the same logger for multiple calls' do
      logger = VCAP::Logging.logger('foo.bar')
      logger.should_not be_nil

      VCAP::Logging.logger('foo.bar').should == logger
    end

    it 'should set log level to the default if no masks are present' do
      logger = VCAP::Logging.logger('foo.bar')
      logger.should_not be_nil
      logger.log_level.should == VCAP::Logging.default_log_level
    end

    it 'should set log level to the most restrictive mask that matches' do
      VCAP::Logging.set_log_level('.*', :debug)
      VCAP::Logging.set_log_level('foo\..*', :fatal)
      logger = VCAP::Logging.logger('foo.bar')
      logger.log_level.should == :fatal
    end
  end

  describe '.set_log_level' do
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

    it 'should reset loggers at a given level that no longer match to the default level' do
      logger = VCAP::Logging.logger('foo.bar')
      VCAP::Logging.set_log_level('foo.bar', :warn)
      logger.log_level.should == :warn
      VCAP::Logging.set_log_level('zazzle', :warn)
      logger.log_level.should == VCAP::Logging.default_log_level
    end
  end

  describe '.setup_from_config' do
    it 'should set the default log level if supplied with a level key' do
      # Should handle both string/symbol keys
      VCAP::Logging.setup_from_config(:level => 'debug')
      VCAP::Logging.default_log_level.should == :debug

      VCAP::Logging.setup_from_config('level' => 'warn')
      VCAP::Logging.default_log_level.should == :warn
    end

    it 'should raise an exception if given an invalid level' do
      lambda { VCAP::Logging.setup_from_config(:level => 'zazzle') }.should raise_error(ArgumentError)
    end

    it 'should add a stdio sink if no other sinks are configured' do
      VCAP::Logging.should_receive(:add_sink).with(nil, nil, an_instance_of(VCAP::Logging::Sink::StdioSink)).once
      VCAP::Logging.setup_from_config(:level => 'debug')
    end

    it 'should add a file sink if given a file key' do
      tmpdir = Dir.mktmpdir
      File.directory?(tmpdir).should be_true

      VCAP::Logging.should_receive(:add_sink).with(nil, nil, an_instance_of(VCAP::Logging::Sink::FileSink)).once
      VCAP::Logging.setup_from_config('file' => File.join(tmpdir, 'test_file1'))

      FileUtils.rm_rf(tmpdir)
      File.directory?(tmpdir).should be_false
    end

    it 'should add a syslog sink if given a syslog key' do
      VCAP::Logging.should_receive(:add_sink).with(nil, nil, an_instance_of(VCAP::Logging::Sink::SyslogSink)).once
      VCAP::Logging.setup_from_config('syslog' => 'test1')
    end
  end
end
