# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/spec/mqlight/delivery_spec.rb
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

require 'spec_helper'

describe Mqlight::Delivery do
  let(:msg) { Qpid::Proton::Message.new }
  let(:service) {Mqlight::Service.new(URI('amqp://localhost:5672'))}
  let(:dest) do
    Mqlight::Destination.new(service, 'public', share: 'myshare')
  end
  let(:client)  { Mqlight::BlockingClient.new('amqp://localhost:5672/public') }
  let(:tracker) { double(Qpid::Proton) }
  let(:thread_vars) { Mqlight::ThreadVars.new('MyId') }

  let(:transport) { 'transport' }

  before(:each) do
    msg.address = 'amqp://localhost:5672/public'
    thread_vars.proton.connect(service)
  end

  describe '#new' do
    it 'creates a Delivery if passed valid arguments' do
      delivery = Mqlight::Delivery.new(msg, dest, thread_vars)
      expect(delivery).to be_an_instance_of Mqlight::Delivery
    end

    it 'sets its data to be the body of the supplied message' do
      msg.body = 'Hello, World!'
      delivery = Mqlight::Delivery.new(msg, dest, thread_vars)
      expect(delivery.data).to eql 'Hello, World!'
    end

    it 'sets its topic to the topic of the supplied message' do
      delivery = Mqlight::Delivery.new(msg, dest, thread_vars)
      expect(delivery.topic).to eql 'public'
    end

    it 'sets its topic_pattern to the topic_pattern of the destination' do
      delivery = Mqlight::Delivery.new(msg, dest, thread_vars)
      expect(delivery.topic_pattern).to eql 'public'
    end

    it 'sets its ttl to the ttl of the supplied message' do
      msg.ttl = 100
      delivery = Mqlight::Delivery.new(msg, dest, thread_vars)
      expect(delivery.ttl).to be 100
    end

    it 'sets its share to the share of the supplied destination' do
      delivery = Mqlight::Delivery.new(msg, dest, thread_vars)
      expect(delivery.share).to eql 'myshare'
    end

    it 'sets its share to empty string if the destination is private' do
      d = Mqlight::Destination.new(service, 'public')
      delivery = Mqlight::Delivery.new(msg, d, thread_vars)
      expect(delivery.share).to eql nil
    end

    it 'confirm is not set when auto_confirm is not set' do
      d = Mqlight::Destination.new(service, 'public')
      delivery = Mqlight::Delivery.new(msg, d, thread_vars)
      expect(delivery.confirm).to eql nil
    end

    it 'confirm is  set when auto_confirm is set' do
      d = Mqlight::Destination.new(service,
                                   'public', auto_confirm: false)
      delivery = Mqlight::Delivery.new(msg, d, thread_vars)
      expect(delivery.confirm).not_to eql nil
    end
  end

  describe '#to_s' do
    it 'returns a String' do
      delivery = Mqlight::Delivery.new(msg, dest, thread_vars)
      expect(delivery.to_s).to be_kind_of String
    end
  end
end
