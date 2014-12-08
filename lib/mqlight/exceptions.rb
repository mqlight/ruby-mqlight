# %Z% %W% %I% %E% %U%
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
end
