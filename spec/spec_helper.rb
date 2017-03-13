# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/spec/spec_helper.rb
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
# (C) Copyright IBM Corp. 2013, 2015
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
# </copyright>

require 'bundler/setup'
Bundler.setup
require 'webmock/rspec'
require 'timeout'

require 'simplecov'
SimpleCov.minimum_coverage 70
SimpleCov.start do
  add_filter '/qpid_proton/'
  add_filter '/spec/'
  add_filter '/types/' 
  add_filter '/codec/'
  add_filter '/core/'
  add_filter '/util/'
end

require 'mqlight'

class TransportStub
  def stop_threads
  end
end
transport_stub = TransportStub.new

RSpec.configure do |config|
  # add a default 10s timeout around every spec (just incase)
  config.around(:each) do |spec|
    Timeout.timeout(10) do
      spec.run
    end
  end

  # ensure the proton_thread hasn't been left around
  config.after(:each) do
    Thread.list.each do |t|
      t.kill if t[:name] == 'proton_loop'
      t.kill if t[:name] == 'callback_thread'
    end
  end

  # globally stub out some messenger methods
  config.before(:each) do
    [:pn_messenger_start,
     :pn_messenger_stop,
     :pn_messenger_free,
     :pn_messenger_route,
     :pn_messenger_put,
     :pn_message_encode,
     :pn_messenger_send,
     :pn_messenger_subscribe,
     :pn_messenger_recv].each do |arg|
       allow(Cproton).to receive(arg)
         .and_return 0
     end
    allow(Cproton).to receive(:pn_messenger_get_link)
      .and_return(SWIG::TYPE_p_pn_link_t) # TODO: Proper return type
    allow(Cproton).to receive(:pn_link_close)
      .with(anything)
    allow(Cproton).to receive(:pn_link_flow)
      .with(anything, anything)
    allow(Cproton).to receive(:pn_link_state)
      .with(anything)
    allow(Cproton).to receive(:pn_link_target)
      .with(anything)
    allow(Cproton).to receive(:pn_messenger_set_snd_settle_mode)
      .with(kind_of(SWIG::TYPE_p_pn_messenger_t), kind_of(Integer))
      .and_return Qpid::Proton::Error::NONE
    allow(Cproton).to receive(:pn_messenger_set_rcv_settle_mode)
      .with(kind_of(SWIG::TYPE_p_pn_messenger_t), kind_of(Integer))
      .and_return Qpid::Proton::Error::NONE
    allow(Cproton).to receive(:pn_messenger_recv)
      .with(kind_of(SWIG::TYPE_p_pn_messenger_t), kind_of(Integer))
      .and_return Qpid::Proton::Error::NONE
    allow(Cproton).to receive(:pn_messenger_incoming)
      .with(kind_of(SWIG::TYPE_p_pn_messenger_t)).and_return 0
    allow(Cproton).to receive(:pn_messenger_work)
      .with(kind_of(SWIG::TYPE_p_pn_messenger_t), kind_of(Integer))
    allow(Cproton).to receive(:pn_messenger_incoming_tracker)
      .with(kind_of(SWIG::TYPE_p_pn_messenger_t))
    allow(Cproton).to receive(:pn_messenger_subscribe_ttl)
      .with(kind_of(SWIG::TYPE_p_pn_messenger_t),
        kind_of(String), kind_of(Integer))
      .and_return 0
    allow(Cproton).to receive(:pn_messenger_started).and_return true
  end

  # verify any doubled classes names actually exist
  config.mock_with :rspec do |mocks|
    mocks.verify_doubled_constant_names = true
  end
end
