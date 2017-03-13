# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/spec/mqlight/destination_spec.rb
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

describe Mqlight::Destination do
  let(:service) {Mqlight::Service.new(URI('amqp://localhost:5672'))}
  
  describe '#new' do
    it 'creates a Destination if passed a valid service and topic_pattern' do
      dest = Mqlight::Destination.new(service, 'topic')
      expect(dest).to be_an_instance_of Mqlight::Destination
    end

    it 'sets service to supplied value if passed valid arguments' do
      dest = Mqlight::Destination.new(service, 'topic')
      expect(dest.service.to_s).to eq '[Service] amqp://localhost:5672'
    end

    it 'sets topic_pattern to supplied value if passed valid arguments' do
      dest = Mqlight::Destination.new(service, 'topic')
      expect(dest.topic_pattern).to eq 'topic'
    end

    it 'fails if passed no arguments' do
      expect { Mqlight::Destination.new }.to raise_error(ArgumentError)
    end

    it 'fails if passed a nil service' do
      expect do
        Mqlight::Destination.new(nil, 'topic')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a numeric service' do
      expect do
        Mqlight::Destination.new(1, 'topic')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a boolean service' do
      expect do
        Mqlight::Destination.new(true, 'topic')
      end.to raise_error(ArgumentError)
      expect do
        Mqlight::Destination.new(false, 'topic')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed an array as a service' do
      expect do
        Mqlight::Destination.new([], 'topic')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a hash as a service' do
      expect do
        Mqlight::Destination.new({}, 'topic')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a numeric topic_pattern' do
      expect do
        Mqlight::Destination.new('amqp://localhost:5672', 1)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a boolean topic_pattern' do
      expect do
        Mqlight::Destination.new('amqp://localhost:5672', true)
      end.to raise_error(ArgumentError)
      expect do
        Mqlight::Destination.new('amqp://localhost:5672', false)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a nil topic_pattern' do
      expect do
        Mqlight::Destination.new('amqp://localhost:5672', nil)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed an array as a topic_pattern' do
      expect do
        Mqlight::Destination.new('amqp://localhost:5672', [])
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed an hash as a topic_pattern' do
      expect do
        Mqlight::Destination.new(service, {})
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a numeric share' do
      expect do
        Mqlight::Destination.new(service, 'topic', share: 1)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a boolean share' do
      expect do
        Mqlight::Destination.new(service, 'topic', share: true)
      end.to raise_error(ArgumentError)
      expect do
        Mqlight::Destination.new(service, 'topic', share: false)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed an array as a share' do
      expect do
        Mqlight::Destination.new(service, 'topic', share: [])
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a hash as a share' do
      expect do
        Mqlight::Destination.new(service, 'topic', share: {})
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a share with a colon' do
      expect do
        Mqlight::Destination.new(service,
                                 'topic', share: 'share:')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed numeric options' do
      expect do
        Mqlight::Destination.new(service, 'topic', 1)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed boolean options' do
      expect do
        Mqlight::Destination.new(service, 'topic', true)
      end.to raise_error(ArgumentError)
      expect do
        Mqlight::Destination.new(service, 'topic', false)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed an array of options' do
      expect do
        Mqlight::Destination.new(service, 'topic', [])
      end.to raise_error(ArgumentError)
    end

    it 'uses default value for qos (at-most-once) if not set' do
      dest = Mqlight::Destination.new(service,'topic')
      expect(dest.qos).to be 0
    end

    it 'sets qos to 0 if passed qos 0' do
      dest = Mqlight::Destination.new(service, 'topic', qos: 0)
      expect(dest.qos).to be 0
    end

    it 'sets qos to 1 if passed qos 1' do
      dest = Mqlight::Destination.new(service, 'topic', qos: 1)
      expect(dest.qos).to be 1
    end

    it 'fails if passed an unsupported numeric qos' do
      expect do
        Mqlight::Destination.new(service, 'topic', qos: -1)
      end.to raise_error(ArgumentError)
      expect do
        Mqlight::Destination.new(service, 'topic', qos: 2)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a string qos' do
      expect do
        Mqlight::Destination.new(service,
                                 'topic', qos: 'qos')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a true boolean qos' do
      expect do
        Mqlight::Destination.new(service, 'topic', qos: true)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed an array as a qos' do
      expect do
        Mqlight::Destination.new(service, 'topic', qos: [])
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a hash as a qos' do
      expect do
        Mqlight::Destination.new(service, 'topic', qos: {})
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed an invalid numeric ttl' do
      expect do
        Mqlight::Destination.new(service, 'topic', ttl: -1)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a string as a ttl' do
      expect do
        Mqlight::Destination.new(service,
                                 'topic', ttl: 'ttl')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a true boolean ttl' do
      expect do
        Mqlight::Destination.new(service, 'topic', ttl: true)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a hash as a ttl' do
      expect do
        Mqlight::Destination.new(service, 'topic', ttl: {})
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed an array as a ttl' do
      expect do
        Mqlight::Destination.new(service, 'topic', ttl: [])
      end.to raise_error(ArgumentError)
    end

    it 'sets auto_confirm to true if specified' do
      dest = Mqlight::Destination.new(service, 'topic', auto_confirm: true)
      expect(dest.auto_confirm).to be true
    end

    it 'sets auto_confirm to false if specified' do
      dest = Mqlight::Destination.new(service,
                                      'topic', auto_confirm: false)
      expect(dest.auto_confirm).to be false
    end

    it 'sets auto_confirm to true if no auto_confirm is specified' do
      dest = Mqlight::Destination.new(service, 'topic', {})
      expect(dest.auto_confirm).to be true
    end

    it 'sets auto_confirm to true if no options are specified' do
      dest = Mqlight::Destination.new(service, 'topic')
      expect(dest.auto_confirm).to be true
    end

    it 'fails if passed a string as a auto_confirm value' do
      expect do
        Mqlight::Destination.new(service,
                                 'topic', auto_confirm: 'auto_confirm')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a numeric auto_confirm value' do
      expect do
        Mqlight::Destination.new(service,
                                 'topic', auto_confirm: 0)
      end.to raise_error(ArgumentError)
      expect do
        Mqlight::Destination.new(service,
                                 'topic', auto_confirm: 1)
      end.to raise_error(ArgumentError)
    end

    it "sets share to 'private:' if passed a nil share" do
      dest = Mqlight::Destination.new(service, 'topic', share: nil)
      expect(dest.share).to eq nil
    end

    it "prepends topic with 'private:' if passed a nil share" do
      dest = Mqlight::Destination.new(service, 'topic', share: nil)
      expect(dest.address).to start_with 'amqp://localhost:5672/private:'
    end

    it 'sets share to supplied name if passed a valid share' do
      dest = Mqlight::Destination.new(service, 'topic', share: 'myshare')
      expect(dest.share).to eq 'myshare'
    end

    it 'prepends topic with share if passed a valid share' do
      dest = Mqlight::Destination.new(service, 'topic', share: 'myshare')
      expect(dest.address).to start_with 'amqp://localhost:5672/share:myshare:'
    end

    it 'sets defaults if passed no options' do
      dest = Mqlight::Destination.new(service, 'topic')
      expect(dest.qos).to eq 0
      expect(dest.ttl).to eq 0
    end

    it 'sets defaults if passed empty options' do
      dest = Mqlight::Destination.new(service, 'topic', {})
      expect(dest.qos).to eq 0
      expect(dest.ttl).to eq 0
    end
  end
end
