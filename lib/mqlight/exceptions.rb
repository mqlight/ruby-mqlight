# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/lib/mqlight/exceptions.rb
#
# <copyright
# notice="lm-source-program"
# pids="5725-P60"
# years="2013,2014"
# crc="3568777996" >
# Licensed Materials - Property of IBM
#
# 5725-P60
#
# (C) Copyright IBM Corp. 2014
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
# </copyright>

module Mqlight
  # The operation failed because of a network error
  class NetworkError < StandardError
  end

  # Raised to indicate that a requested operation has been rejected because
  # the remote end does not permit it
  class NotPermittedError < StandardError
  end

  # The operation failed due to a security related problem
  class SecurityError < StandardError
  end

  # The operation failed because the client transitioned into stopped state
  class StoppedError < StandardError
  end

  # This exception is thrown if an operation times out
  class TimeoutError < StandardError
  end

  # Thrown if the client is already subscribed to a destination.
  class SubscribedError < StandardError
  end

  # Thrown if an operation requires the client to be subscribed to a destination
  # but the client is not currently subscribed to the destination.
  class UnsubscribedError < StandardError
  end

  # The operation failed because the client doesn't yet support the options
  # that were passed to the method
  class UnsupportedError < StandardError
  end

  # The client has been disconnected as another has taken over.
  class ReplacedError < StandardError
  end

  # Not strictly an error but indicates to the outer level to
  # retry the command later.  
  class RetryError < StandardError
  end

  # The operation failed due to an internal condition.
  class InternalError < StandardError
    attr_reader :cause

    def initialize(cause)
      if cause.is_a? String
        super(cause)
      else
        super(cause.message)
      end
      @cause = cause
    end
  end

  # A container for any exception
  class ExceptionContainer
    attr_reader :exception

    def initialize(exception)
      @exception = exception
    end
  end
end
