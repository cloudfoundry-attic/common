# nats-rpc

`nats-rpc` is a thin wrapper around NATS its publish/subscribe mechanism to
provide 1-to-1 calls, 1-to-N multicalls and 1-to-N multicast.

# Concepts

* **CLIENT**: process that initiates the remote call.

* **SERVER**: process that receives calls from the client, processes them, and
  optionally sends back replies.

* **SERVICE**: subclass of `NATS::RPC::Service` that defines a series of
  methods that can be called from a remote. Both the client and the server
  must share the definition of a service, but its methods are only executed on
  the server.

# Different Calls

The three types of calls where `nats-rpc` can help out are as follows:

1. **CALL**: 1-to-1 request-reply. The caller sends out a request to a specific
   remote peer, and can only get a reply from that specific peer. Errors that
   are raised on the remote and are **not** programming errors are propagated
   to the caller. A timeout can occur when the remote does not reply in time.

   * The request can receive one and only one reply.
   * After receiving a reply, the request can **no longer** time out.
   * After the request has timed out, subsequent reply is discarded.

2. **MULTICALL**: 1-to-N request-reply. The caller sends out a request to all
   active remote peers, and can get a reply from any of them. As with the
   regular **CALL**, errors may be propagated, and a timeout may occur if
   **none** of the remotes replied in time.

   * The request can receive one or more replies.
   * After receiving a reply, the request can **still** time out. The rationale
     behind this semantic is that a **MULTICALL** may expect 5 replies to be
     returned, thus time out if only 4 have arrived.
   * After the request has timed out, all subsequent replies are discarded.

3. **MULTICAST**: 1-to-N request. The caller sends out a request to all active
   remote peers, without expecting replies. If a remote decides to send a reply
   for a multicast request, it will be ignored by the caller.

   * The request can not receive replies.

# Examples

## Service implementation

Service code should be shared between the client and server processes. It acts
as a contract between the client and server as to what methods can be
called, and how these requests are routed through NATS.

```ruby
class MyService < NATS::RPC::Service

  # Override the default timeout (30s) for callers by passing the :timeout option.
  export :my_method, :timeout => 5

  # Exported methods take a request object. To send back a reply for this
  # request, the #reply method on the request object should be used.
  #
  # The arguments for the request as passed by the caller can be accessed
  # using the #payload method on the request object. The return value of this
  # method is deserialized JSON, where the argument that is sent by the client
  # is serialized using JSON.

  def my_method(request)
    request.reply(request.payload)
  end

  export :my_error_method

  def my_error_method(request)
    # Reply with an error by raising it...
    raise MyServiceError.new("Something went wrong...")

    # ...or by explicitly using the #reply_error method.
    request.reply_error(MyServiceError.new("Something went wrong...")
  end

  class MyServiceError < NATS::RPC::Service::Error
  end
end
```

## Starting a server

To start a `nats-rpc` server, an instance of `NATS::RPC::Server` should be
created for every service the server implements. The constructor to this class
takes a connected NATS client object, and the instance of the service that is
implemented. The server object will not modify the service instance in any way;
it merely calls the implemented methods when it receives requests to do so.

```ruby
EM.run do
  nats = NATS.connect
  server = NATS::RPC::Server.new(nats, MyService.new, :peer_name => "my_unique_name")
end
```

The peer name that is used by default is equal to the combination of the
hostname of the server and the PID of the Ruby process. When multiple services
are exported by creating multiple `NATS::RPC::Server` instances, it is
generally a good idea to have them use the same peer name. This allows a
caller of *ServiceA* to use that peer name to call a remote method on
*ServiceB*.

## Using the client

Like the server, the client takes a connected NATS client object, and an
instance of the service that it intends to call.

```ruby
EM.run do
  nats = NATS.connect
  client = NATS::RPC::Client.new(nats, MyService.new, :peer_name => "my_unique_name")
end
```

### **CALL**

To perform a 1-to-1 remote call, the client needs the exact peer name of the
remote that is supposed to receive the request. Other arguments are the name of
the method that should be called, optional arguments, and optional options for
the request. Using the option hash, it is possible to override the default
request timeout.

The object that is returned from this call represents the request, and one can
register blocks of code to be registered to execute whenever a reply is
received, or the request times out.  Typical usage looks like the following
snippet:

```ruby
request = client.call("remote_peer_id", "my_method", "hello!", :timeout => 1)
request.execute!

request.on("reply") do |reply|
  puts "Got reply: #{reply.result}"
end

request.on("timeout") do
  puts "We didn't get a reply within 1s"
end
```

### **MULTICALL**

The 1-to-N request-response looks very similar to the regular **CALL**.
Obviously, **MULTICALL** doesn't take a peer name argument. The primary
behavioral differences are that the reply callback may be execute more than
once, and that the timeout callback may fire even after receiving replies.

```ruby
request = client.mcall("my_method", "hello!", :timeout => 1)
request.execute!

replies = []
request.on("reply") do |reply|
  replies << reply
end

request.on("timeout") do
  puts "Got #{replies.size} replies"
end
```

### **MULTICAST**

The 1-to-N request without reply is very simple. It takes the same arguments
as the **MULTICALL**, but can never receive replies or time out.

```ruby
request = client.mcast("my_method", "hello!")
request.execute!
```

### Errors

When an error occurs in a remote **CALL** or **MULTICALL**, that error is sent
back to the caller. It is raised when the `#result` method on the reply object
is called. This can be avoided using a standard `begin`/`rescue` block.

```ruby
request = client.call("remote_peer_id", "my_error_method")
request.execute!

request.on("reply") do |reply|
  begin
    puts "Got reply: #{reply.result}"
  rescue NATS::RPC::Service::Error => error
    puts "Oops: #{error.message}" 
  end
end
```

# Tests

To run the tests, use:

```
rake spec
```
