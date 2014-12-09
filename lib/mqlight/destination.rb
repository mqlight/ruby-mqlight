# @(#) MQMBID sn=mqkoa-L141209.14 su=_mOo3sH-nEeSyB8hgsFbOhg pn=appmsging/ruby/mqlight/lib/mqlight/destination.rb
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
  #
  class Destination
    attr_reader :address
    attr_reader :service
    attr_reader :topic_pattern
    attr_reader :share
    attr_reader :qos
    attr_reader :ttl
    attr_reader :auto_confirm
    attr_reader :credit

    #
    def initialize(service,
                   topic_pattern,
                   options = {})
      fail ArgumentError,
           'service must be a String.' unless service.is_a? String
      @service = service

      fail ArgumentError,
           'topic_pattern must be a String.' unless topic_pattern.is_a? String
      @topic_pattern = topic_pattern

      if options.is_a? Hash
        @share = options.fetch(:share, nil)
        @qos = options.fetch(:qos, nil)
        @ttl = options.fetch(:ttl, nil)
        @auto_confirm = options.fetch(:auto_confirm, nil)
        @credit = options.fetch(:credit, nil)
      else
        fail ArgumentError,
             'options must be a Hash or nil.' unless options.nil?
      end
      fail Mqlight::UnsupportedError,
           "ttl is not yet supported by this client \"#{@ttl}\"" unless @ttl.nil?
               
      @qos ||= QOS_AT_MOST_ONCE
      fail Mqlight::UnsupportedError,
           "qos=#{QOS_AT_LEAST_ONCE} is not yet supported by this "\
           'client' if qos == QOS_AT_LEAST_ONCE
      @ttl ||= 0
      @auto_confirm = true if @auto_confirm.nil?
      @credit = 1024 if @credit.nil?

      fail ArgumentError,
           'credit must be an unsigned Integer less then 2^32.' unless
        @credit.is_a?(Integer) && @credit < 4_294_967_296
      fail ArgumentError, 'auto_confirm must be a boolean.' unless
        @auto_confirm.class == TrueClass || @auto_confirm.class == FalseClass
      fail ArgumentError, 'Unsupported qos.' unless
        @qos == QOS_AT_MOST_ONCE || @qos == QOS_AT_LEAST_ONCE

      @ttl = (ttl / 1000).round

      # Validate share
      fail ArgumentError, 'share must be a String or nil.' unless
        @share.is_a?(String) || @share.nil?
      if @share.is_a? String
        fail ArgumentError,
             'share is invalid because it contains a colon (:) character' if
          @share.include? ':'
        @share = 'share:' + @share + ':'
      else
        @share = 'private:'
      end

      @address = @service + '/' + @share + @topic_pattern

      # Set defaults
      @unconfirmed = 0
      @confirmed = 0
    end
  end
end
