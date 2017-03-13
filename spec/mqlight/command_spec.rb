# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/spec/mqlight/command_spec.rb
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

describe Mqlight::ProtonContainer do
  let(:id) { 'id' }
  let(:address) {'amqp://host1:5672' }
  let(:thread_vars) do
    tv = Mqlight::ThreadVars.new('id')
    tv.destinations.push(destination_qos_0)
    tv.destinations.push(destination_qos_1)
    tv
  end
  let(:args) {{
    id: "Test-Id",
    user: "Test-User",
    password: "Test-Password",
    service_list: "Test-Service-List",
    thread_vars: thread_vars,
    sslTrustCertificate: "Test-TrustCertificate",
    sslVerifyName: "Test-VerifyName"
  }}
  let(:destination_qos_0) do
    Mqlight::Destination.new(service, 'address001', {qos: 0})
  end
  let(:destination_qos_1) do
    Mqlight::Destination.new(service, 'address001', {qos: 1})
  end
  let(:service) {Mqlight::Service.new(URI(address))}
  let(:transport) { 'transport' }
  let(:message) { Qpid::Proton::Message.new }

  before(:each) do
    @command = Mqlight::Command.new(args)
    thread_vars.state=:started
  end

  describe 'check_for_messages' do
    it 'none present' do
      allow(thread_vars.proton).to receive(:open_for_message)
        .with(Mqlight::Destination).and_return SWIG::TYPE_p_pn_link_t
      allow(thread_vars.proton).to receive(:message?)
        .and_return false
      allow(thread_vars.proton).to receive(:drain_message)
        .with(SWIG::TYPE_p_pn_link_t)
        .and_return false
      expect(@command.check_for_messages(destination_qos_0, 1)).nil?
    end

    it 'present-QOS-0' do
      allow(thread_vars.proton).to receive(:open_for_message)
        .with(Mqlight::Destination).and_return SWIG::TYPE_p_pn_link_t
      allow(thread_vars.proton).to receive(:message?).and_return true
      allow(thread_vars.proton).to receive(:drain_message)
        .with(SWIG::TYPE_p_pn_link_t)
        .and_return false
      allow(thread_vars.proton).to receive(:collect_message).and_return message
      allow(message).to receive(:address).and_return address
      allow(thread_vars.proton).to receive(:tracker).and_return "tracker"
      allow(thread_vars.proton).to receive(:accept)
      expect(@command.check_for_messages(destination_qos_0, 1)).nil?
      expect(thread_vars.reply_queue.size).to be 1
    end
    
    it 'present-QOS-1' do
      allow(thread_vars.proton).to receive(:open_for_message)
        .with(Mqlight::Destination).and_return SWIG::TYPE_p_pn_link_t
      allow(thread_vars.proton).to receive(:message?).and_return true
      allow(thread_vars.proton).to receive(:drain_message)
        .with(SWIG::TYPE_p_pn_link_t)
        .and_return false
      allow(thread_vars.proton).to receive(:collect_message).and_return message
      allow(message).to receive(:address).and_return address
      allow(thread_vars.proton).to receive(:tracker).and_return "tracker"
      allow(thread_vars.proton).to receive(:accept)
      allow(thread_vars.proton).to receive(:settle)
        .with(SWIG::TYPE_p_pn_link_t)
      expect(@command.check_for_messages(destination_qos_1, 1)).nil?
      expect(thread_vars.reply_queue.size).to be 1
    end
  end

  describe 'process_queue_send' do
    it 'PN STATUS ACCEPTED' do
      thread_vars.proton.connect(service)
      @command.process_queued_send('message',0)
      message = thread_vars.reply_queue.pop
      expect(message).to eql(nil)
    end

    it 'PN STATUS SETTLE' do
      thread_vars.proton.connect(service)
      @command.process_queued_send('message',0)
      message = thread_vars.reply_queue.pop
      expect(message).to eql(nil)
    end

    it 'PN STATUS REJECTED' do
      allow(thread_vars.proton).to receive(:put_message)
        .with(String, Integer)
      allow(thread_vars.proton).to receive(:tracker_condition_description)
        .and_return 'send failed - message was rejected'
      allow(thread_vars.proton).to receive(:outbound_pending?).and_return false
      allow(thread_vars.proton).to receive(:tracker_status)
        .and_return Cproton::PN_STATUS_REJECTED
      @command.process_queued_send('message',0)
      message = thread_vars.reply_queue.pop
      expect(message).to be_an_instance_of Mqlight::ExceptionContainer
      expect(message.exception).to be_an_instance_of RangeError
    end

    it 'PN STATUS RELEASED' do
      allow(thread_vars.proton).to receive(:put_message)
        .with(String, Integer)
      allow(thread_vars.proton).to receive(:outbound_pending?).and_return false
      allow(thread_vars.proton).to receive(:tracker_status)
        .and_return Cproton::PN_STATUS_RELEASED
      @command.process_queued_send('message',0)
      message = thread_vars.reply_queue.pop
      expect(message).to be_an_instance_of Mqlight::ExceptionContainer
      expect(message.exception).to be_an_instance_of Mqlight::InternalError
    end
    
    it 'PN STATUS MODIFIED' do
      allow(thread_vars.proton).to receive(:put_message)
        .with(String, Integer)
      allow(thread_vars.proton).to receive(:outbound_pending?).and_return false
      allow(thread_vars.proton).to receive(:tracker_status)
        .and_return Cproton::PN_STATUS_MODIFIED
      @command.process_queued_send('message',0)
      message = thread_vars.reply_queue.pop
      expect(message).to be_an_instance_of Mqlight::ExceptionContainer
      expect(message.exception).to be_an_instance_of Mqlight::InternalError
    end

    it 'PN STATUS ABORTED' do
      allow(thread_vars.proton).to receive(:put_message)
        .with(String, Integer)
      allow(thread_vars.proton).to receive(:outbound_pending?).and_return false
      allow(thread_vars.proton).to receive(:tracker_status)
        .and_return Cproton::PN_STATUS_ABORTED
      expect do
        @command.process_queued_send('message',0)
      end.to raise_error(Mqlight::NetworkError)
    end

# Test disabled as a Status of pending now blocks
#    it 'PN STATUS PENDING' do
#      allow(Cproton).to receive(:pn_messenger_status)
#      allow(thread_vars.proton).to receive(:put_message)
#        .with(String, Integer)
#      allow(thread_vars.proton).to receive(:outbound_pending?).and_return false
#      allow(thread_vars.proton).to receive(:tracker_status)
#        .and_return Cproton::PN_STATUS_PENDING
#      @command.process_queued_send('message',0)
#      message = thread_vars.reply_queue.pop
#      expect(message).to be nil
#    end
  end
  
  describe 'process_queued_subscription' do
    it 'successful' do
      allow(thread_vars.proton).to receive(:create_subscription)
        .with(Mqlight::Destination).and_return SWIG::TYPE_p_pn_link_t
      allow(thread_vars.proton).to receive(:link_up?)
        .and_return true
      expect (@command.process_queued_subscription(destination_qos_0)).nil?
      expect (thread_vars.reply_queue.pop).nil?
      expect (thread_vars.destinations.pop).eql? destination_qos_0
    end
    
    it 'raised error' do
      allow(thread_vars.proton).to receive(:create_subscription)
        .with(Mqlight::Destination).and_raise Mqlight::NetworkError
      expect do
        @command.process_queued_subscription(destination_qos_0)
      end.to raise_error Mqlight::NetworkError
      expect (thread_vars.reply_queue.size).eql? 0
      expect (thread_vars.destinations.size).eql? 0
    end
  end
  
  describe 'process_queued_unsubscribe' do
    it 'successful' do
      allow(thread_vars.proton).to receive(:close_link)
        .with(Mqlight::Destination, Integer).and_return nil
      expect (@command.process_queued_unsubscribe(destination_qos_0, 0)).nil?
    end
    
    it 'raised error' do
      allow(thread_vars.proton).to receive(:close_link)
        .with(Mqlight::Destination, Integer).and_raise Mqlight::NetworkError
      expect do
        @command.process_queued_unsubscribe(destination_qos_0, 0)
      end.to raise_error Mqlight::NetworkError
    end
  end
  
  describe 'process_request_queue' do
    it 'successful - process_queued_send' do
      allow(@command).to receive(:check_for_messages)
        .with(String, Integer).and_return nil
      Thread.new do
        @command.push_request({action: 'receive', destination: 'destination', timeout: 0})
      end
      sleep(0.5)
      expect(@command.process_request_queue).to be nil
    end
    
    it 'successful - process_queued_send' do
      allow(@command).to receive(:process_queued_send)
        .with(String, Integer).and_return nil
      Thread.new do
        @command.push_request({action: 'send', params: 'params', qos: 0})
      end
      sleep(0.5)
      expect(@command.process_request_queue).to be nil
    end
    
    it 'successful - process_queued_subscription' do
      allow(@command).to receive(:process_queued_subscription)
        .with(String).and_return nil
      Thread.new do
        @command.push_request({action: 'subscribe', params: 'params'})
      end
      sleep(0.5)
      expect(@command.process_request_queue).to be nil
    end
    
    it 'successful - process_queued_unsubscribe' do
      allow(@command).to receive(:process_queued_unsubscribe)
        .with(String, Integer).and_return nil
      Thread.new do
        @command.push_request({action: 'unsubscribe', params: 'params', ttl: 0})
      end
      sleep(0.5)
      expect(@command.process_request_queue).to be nil
    end
    
#    it 'failed - Network(send) forcing a timeout' do
#      allow(@command).to receive(:process_queued_send)
#        .with(String, Integer)  do
#          fail Mqlight::NetworkError, "UnitTest"
#        end
#      allow(thread_vars).to receive(:change_state)
#        .with(:retrying).and_return nil
#      Thread.new do
#        @command.push_request({action: 'send', params: 'params', qos: 0, timeout: 0.5})
#      end
#      sleep(0.5)
#      @command.process_request_queue
#      message = thread_vars.reply_queue.pop
#      expect(message).to be_an_instance_of Mqlight::ExceptionContainer
#      expect(message.exception).to be_an_instance_of Mqlight::TimeoutError
#    end
    
  end
end
