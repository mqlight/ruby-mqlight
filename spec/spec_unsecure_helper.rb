# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/spec/spec_unsecure_helper.rb
#
# <copyright
# notice="lm-source-program"
# pids="5725-P60"
# years="2013,2015"
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

class TransportStub
  def stop_threads
  end
end
transport_stub = TransportStub.new

RSpec.configure do |config|
  config.before(:each) do
    allow(Mqlight::UnsecureEndPoint).to receive(:new) do |args|
      @thread_vars = args[:thread_vars]
      @thread_vars.proton.sockets_open=true
    end.and_return transport_stub
    allow(transport_stub).to receive(:start_connection_threads)
    allow(transport_stub).to receive(:stop_threads)
  end
end