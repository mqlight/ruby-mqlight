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
  # An instance of this class is passed into the block supplied to the
  # NonBlockingClient subscribe method.  This allows the block supplied to the
  # subscribe method to register an interest in various subscription realted
  # events.
  class SubscribeDescriptor
    # Used to register a block that will be called each time a message is
    # received from the destination that the client has subscribed to.
    # @yield a block that is called each time a message arrives.
    # @yieldparam [Delivery] an object representing the message delivery.
    def message
    end

    # Used to register a block that will be called when the subscribe operation
    # completes.
    # @yield a block that is called when the subscribe operation completes.
    # @yieldparam [nil, Exception] indicates whether the subscribe operation
    #             completed successfully (in which case a value of nil will
    #             be passed to the block) or whether the subscribe operation
    #             failed (in which case an Exception relating to the faliure
    #             will be passed to the block).
    def complete
    end

    # Used to register a block that will be called when the client becomes
    # unsubscribed from the destination.
    # @yield a block that is called when the client becomes unsubscribed from
    #        the destination.
    # @yieldparam [nil, Exception] indicates whether the client became
    #             unsubscribed because of a call to the client unsubscribe
    #             method (in which case the value nil will be supplied as this
    #             parameter) or due to an error (in which case an exception
    #             relating to the problem is supplied as this parameter).
    def unsubscribed
    end
  end
end
