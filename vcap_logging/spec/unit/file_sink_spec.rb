require File.join(File.dirname(__FILE__), '..', 'spec_helper')

require 'fileutils'
require 'tmpdir'

describe VCAP::Logging::Sink::FileSink do
  before :each do
    @tmp_dir = Dir.mktmpdir
    @logfile = File.join(@tmp_dir, 'test.log')
    @test_line = "testing 123\n"
  end

  after :each do
    FileUtils.rm_rf(@tmp_dir)
    File.directory?(@tmp_dir).should be_false
  end

  it 'creates a file if it does not exist' do
    File.exist?(@logfile).should be_false
    sink = VCAP::Logging::Sink::FileSink.new(@logfile)
    File.exist?(@logfile).should be_true
  end

  it 'writes immediately to the file if buffering is disabled' do
    fmt = mock(:formatter)
    fmt.should_receive(:format_record).with(anything()).and_return(@test_line)
    sink = VCAP::Logging::Sink::FileSink.new(@logfile, fmt)
    sink.add_record('foo')
    read_file(@log_file).should == @test_line
  end

  it 'does not write immediately to the file if buffering is enabled' do
    buffer_size = @test_line.length * 4 + 1
    fmt = mock(:formatter)
    fmt.should_receive(:format_record).exactly(6).times.with(anything()).and_return(@test_line)
    sink = VCAP::Logging::Sink::FileSink.new(@logfile, fmt, :buffer_size => buffer_size)
    for x in 0..3
      sink.add_record('foo')
      read_file(@logfile).should == ""
    end

    expected = @test_line * 5
    # Should flush the buffer
    sink.add_record('foo')
    read_file(@log_file).should == expected

    # Should be buffered
    sink.add_record('foo')
    read_file(@log_file).should == expected
  end

  it 'flushes internal buffers when asked' do
    buffer_size = @test_line.length * 2
    fmt = mock(:formatter)
    fmt.should_receive(:format_record).with(anything()).and_return(@test_line)
    sink = VCAP::Logging::Sink::FileSink.new(@logfile, fmt, :buffer_size => buffer_size)
    sink.add_record('foo')
    read_file(@logfile).should == ""
    sink.flush
    read_file(@logfile).should == @test_line
  end

  it 'flushes internal buffers on close' do
    buffer_size = @test_line.length * 2
    fmt = mock(:formatter)
    fmt.should_receive(:format_record).with(anything()).and_return(@test_line)
    sink = VCAP::Logging::Sink::FileSink.new(@logfile, fmt, :buffer_size => buffer_size)
    sink.add_record('foo')
    read_file(@logfile).should == ""
    sink.close
    read_file(@logfile).should == @test_line
  end

  def read_file(file)
    data = nil
    File.open(@logfile, 'r') {|f| data = f.read }
    data
  end
end
