# Overview

This gem provides a common logging library to be used for all VCAP projects. It
borrows heavily in its structure from the 'logging' gem.

## Goals

- Minimal dependencies. (Ideally, none.)
- Compatible with both ruby18 and ruby19
- Well tested.

## Usage

This will cover the most common use case: initializing the logging framework once at startup
and using loggers throughout your script.

    # Sample config hash, typically loaded from a config file
    cfg = {
      'level'  => 'debug',
      'file'   => '/tmp/foo.log',
      'syslog' => 'my_logging_example',
    }

    # Initialize the logging framework
    VCAP::Logging.setup_from_config(cfg)

    # Start logging!
    logger = VCAP::Logging.logger('foo.bar.baz')
    logger.debug("Hello world!")

## Core Classes

### Formatter

Formatters take a log record and produce a string that can be written to a
sink.

### Log Sink

Sinks are the final destination for log records. A sink must be configured with
a formatter.  Typically they wrap other objects that perform IO (such as files
and sockets).

### Logger

Loggers are responsible for dispatching messages that need to be logged off to
their appropriate sinks.