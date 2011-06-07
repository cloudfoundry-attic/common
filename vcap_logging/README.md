# Overview

This gem provides a common logging library to be used for all VCAP projects. It
borrows heavily in its structure from the 'logging' gem.

## Goals

- Minimal dependencies. (Ideally, none.)
- Compatible with both ruby18 and ruby19
- Well tested.

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
their appropriate sinks. They are arranged in a tree structure by name, such
that log records flow from the leaves of the tree towards the root. The log
record stops traversing the tree when it arrives at a logger that has been
configured with a sink.

### Trie

Internally, a trie is used to manage the logger hierarchy.