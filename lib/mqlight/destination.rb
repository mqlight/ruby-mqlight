# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/lib/mqlight/destination.rb
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
  # Internal class used to store a record of a destination a client is
  # client is subscribed to. Should not be used externally.
  #
  # @private
  class Destination
    include Mqlight::Logging

    attr_reader :address
    attr_reader :service
    attr_reader :topic_pattern
    attr_reader :share
    attr_reader :qos
    attr_reader :ttl
    attr_reader :auto_confirm

    #
    # @param service [Service]
    # @param topic_pattern [String]
    # @param options [Map]
    #
    def initialize(service, topic_pattern, options = {})
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      logger.parms(@id, parms) { self.class.to_s + '#' + __method__.to_s }

      fail ArgumentError,
           'service must be a Service object.' unless service.is_a? Service
      @service = service

      fail ArgumentError,
           'topic_pattern must be a String.' unless topic_pattern.is_a? String
      @topic_pattern = topic_pattern

      if options.is_a? Hash
        @share = options.fetch(:share, nil)
        @qos = options.fetch(:qos, nil)
        @ttl = options.fetch(:ttl, nil)
        @auto_confirm = options.fetch(:auto_confirm, nil)
      else
        fail ArgumentError,
             'options must be a Hash or nil.' unless options.nil?
      end

      unless @ttl.nil?
        fail ArgumentError, 'ttl must be an unsigned Integer.' unless
          @ttl.is_a?(Integer) && @ttl >= 0
        @ttl = 4_294_967_295 if @ttl > 4_294_967_295
      end

      # Defaults
      @qos ||= QOS_AT_MOST_ONCE
      @ttl ||= 0
      @auto_confirm = true if @auto_confirm.nil?

      fail ArgumentError, 'auto_confirm must be a boolean.' unless
        @auto_confirm.class == TrueClass || @auto_confirm.class == FalseClass

      fail ArgumentError, "qos value #{@qos} " \
        ' is invalid must evaluate to 0 or 1.' unless
             @qos == QOS_AT_MOST_ONCE || @qos == QOS_AT_LEAST_ONCE

      @ttl = (@ttl / 1000).round

      # Validate share
      fail ArgumentError, 'share must be a String or nil.' unless
        @share.is_a?(String) || @share.nil?
      if @share.is_a? String
        fail ArgumentError,
             'share is invalid because it contains a colon (:) character' if
          @share.include? ':'
        uri_share = 'share:' + @share + ':'
      else
        uri_share = 'private:'
      end
      @address = @service.address + '/' + uri_share + @topic_pattern

      # Set defaults
      @unconfirmed = 0
      @confirmed = 0
    rescue => e
      logger.throw(nil, e) { self.class.to_s + '#' + __method__.to_s }
      raise e
    end

    # @return true if the topic pattern and share match.
    #
    def match?(topic_pattern, share)
      (@topic_pattern.eql? topic_pattern) && (@share.eql? share)
    end

    def to_s
      info = '{'
      info << 'address: ' +
        @address.to_s.force_encoding('UTF-8') unless @address.nil?
      info << ', service: ' +
        @service.to_s.force_encoding('UTF-8') unless @service.nil?
      info << ', topic_pattern: ' +
        @topic_pattern.to_s.force_encoding('UTF-8') unless @topic_pattern.nil?
      info << ', share: ' + @share.to_s unless @share.nil?
      info << ', qos: ' + @qos.to_s unless @qos.nil?
      info << ', ttl: ' + @ttl.to_s unless @ttl.nil?
      info << ', auto_confirm: ' + @auto_confirm.to_s unless @auto_confirm.nil?
      info << '}'
    end
  end
end
