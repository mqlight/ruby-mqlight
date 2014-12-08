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

require 'bundler/setup'
Bundler.setup

require 'mqlight'
require 'webmock/rspec'
require 'timeout'

RSpec.configure do |config|
  # add a default 2s timeout around every spec (just incase)
  config.around(:each) do |spec|
    Timeout.timeout(2) do
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
  end

  # verify any doubled classes names actually exist
  config.mock_with :rspec do |mocks|
    mocks.verify_doubled_constant_names = true
  end
end
