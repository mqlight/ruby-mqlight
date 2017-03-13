# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/spec/mqlight/logging_spec.rb
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
# (C) Copyright IBM Corp. 2015
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
# </copyright>

require 'spec_helper'
require 'spec_unsecure_helper'

describe Mqlight::Logging do
  describe 'ffdc' do
    subject do
      buffer = StringIO.new
      begin
        client = Mqlight::BlockingClient.new('amqp://localhost:5672',
                                             id: 'unit_test_client')
        logger = Mqlight::Logging::MqlightLogger.new(buffer)
        fail Mqlight::InternalError, 'unit test exception'
      rescue Mqlight::InternalError => ffdc_exception
        logger.ffdc('unittest', 1, client, 'unit test data', ffdc_exception)
      end
      buffer.string
    end

    it { should include 'unit test data' }
    it { should include 'unit_test_client' }
    it { should include '#<Mqlight::InternalError: unit test exception>' }
  end
end
