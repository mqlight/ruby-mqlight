# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/lib/mqlight/delivery.rb
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
# (C) Copyright IBM Corp. 2014, 2015
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
# </copyright>

require 'uri'

module Mqlight
  # This class represents an attempt to deliver message data to the client.
  class Delivery
    include Mqlight::Logging

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
    # processed the message to its satisfaction.  When the server receives this
    # confirmation it will make no further attempt to deliver this message to
    # the client and discard its copy of the message.
    attr_reader :confirm
    
    # @return [Malformed] only present when the received message has been
    # declared as malformed. The structure contains the information associated
    # with the malformed message.
    attr_reader :malformed

    # @private
    def initialize(message, destination, thread_vars)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[
        'message', Mqlight::Util.truncate(message.to_s),
        'destination', destination.to_s,
        'thread_vars', thread_vars]
      logger.parms(@id, parms) { self.class.to_s + '#' + __method__.to_s }

      fail ArgumentError, 'message must be a Qpid::Proton::Message.' unless
        message.is_a? Qpid::Proton::Message

      fail ArgumentError, 'destination must be an Mqlight::Destination.' unless
        destination.is_a? Mqlight::Destination

      @thread_vars = thread_vars
      @data = message.body
      @topic = message.address
      if @topic.start_with?('amqp://')
        @topic = @topic.partition(%r{amqp://[^/]*/}).last
      end
      @topic_pattern = destination.topic_pattern
      @ttl = message.ttl
      @share = destination.share
      @tracker = @thread_vars.proton.tracker
      @connect_id = @thread_vars.connect_id
      @malformed = Malformed.new(message.instructions).as_hash if message.instructions 
      # Define the manual/deferred confirm method for this message.
      unless destination.auto_confirm
        @confirm = proc do
          fail Mqlight::StoppedError, 'Not started.' unless started?
          fail Mqlight::NetworkError,
               'client has reconnected since this message was received' \
            if @connect_id != @thread_vars.connect_id

          @thread_vars.proton.settle(@tracker)
        end
      end
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    rescue => e
      logger.throw(nil, e) { self.class.to_s + '#' + __method__.to_s }
      raise e
    end

    # @private
    def started?
      @thread_vars.state == :started
    end

    # @return summary of contains
    def to_s
      info = '{'
      info << 'data: ' + @data.to_s.force_encoding('UTF-8') unless @data.nil?
      info << ', topic: ' + @topic.to_s.force_encoding('UTF-8') \
        unless @topic.nil?
      info << ', topic_pattern: ' +
        @topic_pattern.to_s.force_encoding('UTF-8') unless @topic_pattern.nil?
      info << ', ttl: ' + @ttl.to_s unless @ttl.nil?
      info << ', share: ' + @share.to_s.force_encoding('UTF-8') \
        unless @share.nil?
      info << ', confirm: ' + @confirm.to_s unless @confirm.nil?
      info << ', tracker: ' + @tracker.to_s unless @tracker.nil?
      info << ', malformed: ' + @malformed.to_s unless @malformed.nil?
      info << '}'
    end
  end
  
  #
  # Class to contained malformed information
  # relating to a received message
  #
  class Malformed
    include Mqlight::Logging

    # @return [String] contains a symbol of why the message is malformed
    attr_reader :format
    # @return [String] contains a description of why the message is malformed
    attr_reader :description
    # @return [String] MQMD CodedCharSetId field
    attr_reader :mqmd_CodeCharSetId
    # @return [String] MQMD Format field
    attr_reader :mqmd_condition
    
    def initialize (instructions)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      logger.parms(@id, parms) { self.class.to_s + '#' + __method__.to_s }
      @format = instructions["x-opt-message-malformed-MQMD.Format"];
      @description = instructions["x-opt-message-malformed-description"];
      @coded_char_set_id = instructions["x-opt-message-malformed-MQMD.CodedCharSetId"];
      @condition = instructions["x-opt-message-malformed-condition"];

      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end
    
    def as_hash
      mqmd_hash = {
        'CodedCharSetId' => @coded_char_set_id,
        'Format' => @format
      }
      malformed_hash = {
        'condition' => @condition,
        'description' => @description,
        'MQMD' => mqmd_hash
      }
    end

    def to_s
      info = '{'
      info << 'condition: ' + @condition.to_s unless @condition.nil?
      info << ', description: ' + @description.to_s unless @description.nil?
      info << ', CodedCharSetId: ' + @coded_char_set_id.to_s unless @coded_char_set_id.nil?
      info << ', Format: ' + @format.to_s unless @format.nil?
      info << '}'
    end
  end
end
