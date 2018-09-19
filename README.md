# ruby-mqlight

MQ Light is designed to allow applications to exchange discrete pieces of
information in the form of messages. This might sound a lot like TCP/IP
networking, and MQ Light does use TCP/IP under the covers, but MQ Light takes
away much of the complexity and provides a higher level set of abstractions to
build your applications with.

This Ruby gem provides the high-level API by which you can interact with the MQ
Light runtime.

See https://developer.ibm.com/messaging/mq-light/ for more details.

## Getting Started

### Prerequisites

Ruby, as a language, has a few different implementations. Currently, the MQ
Light gem only supports the reference implementation, often referred to as Ruby
MRI ("Matz's Ruby Interpreter").

You will need a Ruby 1.9.x runtime environment or newer to use the MQ Light API
module. This can be installed from https://www.ruby-lang.org/, or by using your
operating system's package manager.

The following are the currently supported platform architectures:

* 64-bit runtime on Linux (x64)
* 64-bit runtime on Mac OS X (x64)

You will receive an error if you attempt to use any other combination.

## Limitations

This Ruby gem is subject to the follow limitations:

* Requires an 1.0.2 release of the MQ Light server
* No TLS/SSL support for secure encrypted connections for platform Mac
  (Mac OpenSSL 0.9.8 does not support TLS 1.2)


### Usage

Install using gem:

```
gem install mqlight
```

Alternatively, add 'mqlight' as a runtime dependency in your gemspec / Gemfile.

## API

The API has been documented using Yardoc tag formatting within the Ruby code
and can either be viewed online from the Documentation link at
https://rubygems.org/gems/mqlight, or locally by running the YARD tooling.

## Samples

To run the samples, install the module via gem and navigate to the
`<install path>/samples` folder, where the `<install path>` can be determined
from the output of `gem list --details mqlight`.

## Feedback

You can help shape the product we release by trying out the beta code and
leaving your [feedback](https://ibm.biz/mqlight-forum).

### Reporting bugs

If you think you've found a bug, please leave us
[feedback](https://ibm.biz/mqlight-forum).

## Release notes

### 1.0.2018091900

* Experimental support for Ruby 2.4

### 1.0.2017051700

* Bugfix for file handle leak on client stop

### 1.0.2016020809

* Support for sending and receiving
* Support for 'at-most-once' and 'at-least-once' messaging.
* Support for wildcard subscriptions.
* Support for shared subscriptions.
* Support for multiple services
* Support for round-tripping binary or JSON messages
* Support for dealing with malformed messages
* Support for SASL
* Support for SSL on Linux

### 1.0.2015020300.beta

* Initial beta release.
* Support for sending and receiving 'at-most-once' messages.
* Support for wildcard subscriptions.
* Support for shared subscriptions.
