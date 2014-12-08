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

require 'uri'

module Mqlight
  # This class represents an attempt to deliver message data to the client.
  class Delivery
    # @return [String] the message data associated with this delivery
    attr_reader :data

    # @return [String] the topic that the message, delivered by this
    #         deliver, was originally sent to.
    attr_reader :topic

    # @return [String] the topic pattern that the client subscribed to in order
    #         to receive this message delivery
    attr_reader :topic_pattern

    # @return [Integer] the remaining time to live period for this message in
    #         milliseconds.
    attr_reader :ttl

    # @return [String] the share name specified when the client subscribed to
    #         the destination from which the message was received. This
    #         property will not be nil if the client subscribed to a
    #         private destination.
    attr_reader :share

    # Called to confirm that the code that has received this message has
    # processed the message to its staisfaction.  When the server receives this
    # confirmation it will make no further attempt to deliver this message to
    # the client and discard its copy of the message.
    #
    # @note TODO: need to specify how this interacts with no longer being
    #       connected or stopping the client.
    attr_reader :confirm

    #
    def initialize(message, destination)
      fail ArgumentError, 'message must be a Qpid::Proton::Message.' unless
        message.is_a? Qpid::Proton::Message

      fail ArgumentError, 'destination must be an Mqlight::Destination.' unless
        destination.is_a? Mqlight::Destination

      @data = message.body
      @topic = URI.decode(URI(message.address).path.partition('/').last)
      @topic_pattern = destination.topic_pattern
      @ttl = message.ttl
      @share = destination.share.split(':')[1..-1].join('')
    end

    #
    def to_s
      "{ data: '#{@data.to_s.force_encoding("UTF-8")}', "\
        "topic: '#{@topic.force_encoding("UTF-8")}', "\
        "topic_pattern: '#{@topic_pattern.force_encoding("UTF-8")}', "\
        "ttl: '#{@ttl}', "\
        "share: '#{@share.force_encoding("UTF-8")}' }"\
    end
  end
end
