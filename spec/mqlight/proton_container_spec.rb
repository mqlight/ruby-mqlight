# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/spec/mqlight/proton_container_spec.rb
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
# (C) Copyright IBM Corp. 2013, 2016
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
# </copyright>

require 'spec_helper'
require 'spec_unsecure_helper'


describe Mqlight::ProtonContainer do

  let(:id) { 'id' }
  let(:thread_vars) do
    tv = Mqlight::ThreadVars.new('id')
    tv.destinations.push(Mqlight::Destination.new(Mqlight::Service.new(URI('amqp://host1:5672')),'address001'))
    tv.destinations.push(Mqlight::Destination.new(Mqlight::Service.new(URI('amqp://host1:5672')),'address002'))
    tv.destinations.push(Mqlight::Destination.new(Mqlight::Service.new(URI('amqp://host1:5672')),'address003'))
    tv
  end
  let(:service) {Mqlight::Service.new(URI('amqp://host1:5672'))}
  let(:transport) { 'transport' }

  before(:each) do
    @proton = Mqlight::ProtonContainer.new(thread_vars, id)
    @proton.instance_variable_set(:@messenger_impl,'messenger_impl')
    @proton.instance_variable_set(:@connection,'connection')
  end

  it 'connect failed' do
    allow(Cproton).to receive(:pn_messenger_started)
      .with(kind_of(SWIG::TYPE_p_pn_messenger_t)) do
          fail Qpid::Proton::ProtonError, "General failure "
        end

    expect do
      @proton.connect(service)
      @proton.wait_messenger_started(service)
    end.to raise_error(Mqlight::NetworkError)
  end

  it 'connect security' do
    allow(Cproton).to receive(:pn_messenger_started)
      .with(kind_of(SWIG::TYPE_p_pn_messenger_t)) do
          fail Qpid::Proton::ProtonError, "sasl "
        end

    expect do
      @proton.connect(service)
      @proton.wait_messenger_started(service)
    end.to raise_error(Mqlight::SecurityError)
  end

  it 'connect success' do
    allow(Cproton).to receive(:pn_messenger_started)
      .with(kind_of(SWIG::TYPE_p_pn_messenger_t)).and_return true
    @proton.connect(service)
    expect (@proton.wait_messenger_started(service))
  end

  it 'reinstate missing subscribe' do
    call_count = 0
    allow(Cproton).to receive(:pn_link_state) do
      call_count += 1
      call_count > 1 ? 0 : Cproton::PN_REMOTE_ACTIVE
    end
    allow(Cproton).to receive(:pn_messenger_errno) do
      call_count > 2 ? 2 : 0
    end
    expect do
      @proton.connect(service)
      @proton.reinstate_links
    end.to raise_error(Mqlight::SubscribedError)
  end

  it 'check for out of sequence message TakeOver' do
    allow(Cproton).to receive(:pn_messenger_errno).and_return(1)
    allow(Cproton).to receive(:pn_error_text).and_return('_Takeover')
    allow(Cproton).to receive(:pn_messenger_error).and_return('some text')
    allow(Cproton).to receive(:pn_error_clear).and_return(nil)

    thread_vars.state = :started
    @proton.connect(service)
    @proton.check_for_out_of_sequence_messages
    expect(thread_vars.state).to eql(:stopped)
  end

  it 'check for out of sequence message Connection Aborted' do
    allow(Cproton).to receive(:pn_messenger_errno).and_return(1)
    allow(Cproton).to receive(:pn_error_text).and_return('connection aborted')
    allow(Cproton).to receive(:pn_messenger_error).and_return('some text')
    allow(Cproton).to receive(:pn_error_clear).and_return(nil)

    thread_vars.state = :started
    @proton.connect(service)
    @proton.check_for_out_of_sequence_messages
    expect(thread_vars.state).to eql(:retrying)
  end

  it 'check for out of sequence message Other' do
    allow(Cproton).to receive(:pn_messenger_errno).and_return(1)
    allow(Cproton).to receive(:pn_error_text).and_return('other')
    allow(Cproton).to receive(:pn_messenger_error).and_return('some text')
    allow(Cproton).to receive(:pn_error_clear).and_return(nil)

    thread_vars.state = :started
    @proton.connect(service)
    @proton.check_for_out_of_sequence_messages
    expect(thread_vars.state).to eql(:retrying)
  end

  it 'tracker condition description' do
    allow(Cproton).to receive(:pn_messenger_outgoing_tracker)
      .with(kind_of(SWIG::TYPE_p_pn_messenger_t))
      .and_return 'tracker'
    allow(Cproton).to receive(:pn_messenger_delivery)
      .with(kind_of(SWIG::TYPE_p_pn_messenger_t), 'tracker')
      .and_return 'delivery'
    allow(Cproton).to receive(:pn_delivery_remote)
      .with('delivery').and_return 'remote'
    allow(Cproton).to receive(:pn_disposition_condition)
      .with('remote').and_return 'disposition'
    allow(Cproton).to receive(:pn_condition_get_description)
      .with('disposition').and_return 'description'

    @proton.connect(service)
    expect(@proton.tracker_condition_description('default'))
      .to eql('description')
  end

  #
  # Proton_container:open_for_message
  #
  describe '#open_for_message' do
    before :each do
      allow(Cproton).to receive(:pn_link_credit)
      allow(Cproton).to receive(:pn_messenger_set_timeout)
    end

    it 'with no link' do
      allow(Cproton).to receive(:pn_messenger_get_link)
        .and_return nil
      destination = Mqlight::Destination.new(service,"")
      expect(@proton.open_for_message(destination)).to be nil
    end

    it 'with qpid timeout' do
      allow(Cproton).to receive(:pn_messenger_recv) do
        fail Qpid::Proton::TimeoutError, "UnitTest"
      end
      destination = Mqlight::Destination.new(service,"")
      expect(@proton.open_for_message(destination))
        .to eq (SWIG::TYPE_p_pn_link_t)
    end

    it 'with qpid state' do
      allow(Cproton).to receive(:pn_messenger_recv) do
        fail Qpid::Proton::StateError, "UnitTest"
      end
      destination = Mqlight::Destination.new(service,"")
      expect do
        @proton.open_for_message(destination)
      end.to raise_error(Qpid::Proton::StateError)
    end
  end

  #
  # Proton_container:settle
  #
  describe '#settle' do
    before :each do
      allow(Cproton).to receive(:pn_messenger_incoming_tracker)
       .and_return 'tracker'
      allow(Cproton).to receive(:pn_messenger_settle)
       .and_return 0
    end

    it 'golden path' do
      allow(Cproton).to receive(:pn_messenger_errno)
       .and_return 0
      expect(@proton.settle('link'))
    end

    it 'messenger error' do
      allow(Cproton).to receive(:pn_messenger_errno)
       .and_return 2
      allow(Cproton).to receive(:pn_messenger_error)
       .and_return 'settle-error'
      allow(Cproton).to receive(:pn_error_text)
       .with('settle-error')
       .and_return 'Some error'
      allow(Cproton).to receive(:pn_error_clear)
      expect do
        @proton.settle('link')
      end.to_not raise_error
    end
  end

  #
  # Proton_container:DeliveryMessage
  # 
  describe '#DeliveryMessage-class' do
    before :each do
      allow(Cproton).to receive(:pn_connection_transport).and_return 'transport'
    end

    it 'initialise-failure' do
      allow(Cproton).to receive(:pn_messenger_resolve)
        .with('messenger_impl','amqp://host1:5672').and_return nil
      expect do
        Mqlight::ProtonContainer::DeliveryMessage.new('messenger_impl', service, Mutex.new)
      end.to raise_error(Mqlight::InternalError)
    end
    it 'initialise-get-message' do
      allow(Cproton).to receive(:pn_messenger_resolve)
        .with('messenger_impl','amqp://host1:5672').and_return 'connection'
      allow(Cproton).to receive(:pn_transport_pending).with('transport').and_return 9
      allow(Cproton).to receive(:pn_transport_peek).with('transport',9).and_return [9, 'A message']
      allow(Cproton).to receive(:pn_connection_pop).with('connection',9)
      dm = Mqlight::ProtonContainer::DeliveryMessage.new('messenger_impl', service, Mutex.new)
      expect(dm.get).to eql('A message')
    end
    it 'initialise-get-no-message' do
      allow(Cproton).to receive(:pn_messenger_resolve)
        .with('messenger_impl','amqp://host1:5672').and_return 'connection'
      allow(Cproton).to receive(:pn_transport_pending)
        .with('transport').and_return 0
      dm = Mqlight::ProtonContainer::DeliveryMessage.new(
        'messenger_impl', service, Mutex.new)
      expect(dm.get).to eql(nil)
    end
    it 'initialise-pop' do
      allow(Cproton).to receive(:pn_messenger_resolve)
        .with('messenger_impl','amqp://host1:5672').and_return 'connection'
      allow(Cproton).to receive(:pn_connection_pop).with('connection',0)
      allow(Cproton).to receive(:pn_connection_state)
        .with('connection').and_return 0
      dm = Mqlight::ProtonContainer::DeliveryMessage.new(
        'messenger_impl', service, Mutex.new)
      expect(dm.empty_pop)
    end
    it 'create-delivery-message' do
      allow(Cproton).to receive(:pn_messenger_resolve)
        .with('messenger_impl','amqp://host1:5672').and_return 'connection'
      expect(@proton.create_delivery_message(service))
        .to be_kind_of(Mqlight::ProtonContainer::DeliveryMessage)
    end
  end
  
  #
  # proton_container:interpret_message
  #
  describe '#interpret-message' do
    before :each do
      allow(Cproton).to receive(:pn_error_clear)
      allow(Cproton).to receive(:pn_messenger_error).and_return nil
      thread_vars.state = :started
    end
    
    it 'no-message' do
      allow(Cproton).to receive(:pn_error_text).and_return nil
      @proton.interpret_message
      expect(thread_vars.state).to eql(:started)
    end
    it 'takeover' do
      allow(Cproton).to receive(:pn_error_text)
        .and_return 'TEXT_TakeoverTEXT'
      @proton.interpret_message
      expect(thread_vars.state).to eql(:stopped)
    end
    it 'connection-aborted' do
      allow(Cproton).to receive(:pn_error_text)
        .and_return 'TEXTconnection abortedTEXT'
      @proton.interpret_message
      expect(thread_vars.state).to eql(:retrying)
    end
    it 'general' do
      allow(Cproton).to receive(:pn_error_text)
        .and_return 'TEXTSomethtng_elseTEXT'
      @proton.interpret_message
      expect(thread_vars.state).to eql(:retrying)
    end
  end
  
  #
  # Accept
  #
  describe '#accept' do
    it 'success' do
      allow(Cproton).to receive(:pn_messenger_incoming_tracker)
        .and_return 'tracker'
      allow(Cproton).to receive(:pn_messenger_accept)
        .with('messenger_impl','tracker',0)
      allow(Cproton).to receive(:pn_messenger_errno).and_return 0
      expect do
        @proton.accept(service)
      end.to_not raise_error
    end
    it 'network-error' do
      allow(Cproton).to receive(:pn_messenger_incoming_tracker)
        .and_return 'tracker'
      allow(Cproton).to receive(:pn_messenger_accept)
        .with('messenger_impl','tracker',0)
      allow(Cproton).to receive(:pn_messenger_errno).and_return 1
      allow(Cproton).to receive(:pn_messenger_error).and_return "some_error"
      allow(Cproton).to receive(:pn_error_text).and_return "error message"
      expect do
        @proton.accept(service)
      end.to raise_error(Mqlight::NetworkError)
    end
  end

  #
  #
  #
  describe '#remote_idle_timeout' do
    it 'success' do
      allow(Cproton).to receive(:pn_messenger_get_remote_idle_timeout)
        .and_return 99
      expect(@proton.remote_idle_timeout(service)).to eql(99)
    end
  end

  #
  #
  #
  describe '#proton_push' do
    it 'success' do
      message = 'Push_message'
      connection = 'connection'
      allow(Cproton).to receive(:pn_connection_push)
        .with(connection, "Push_message", message.size)
        .and_return message.size
      allow(Cproton).to receive(:pn_connection_pop)
        .with(connection,0)
      expect(@proton.proton_push(message)).to eql(message.size)
    end
  end
  
  describe '#collect_message' do
    it 'success' do
      allow(Cproton).to receive(:pn_messenger_work)
        .with('messenger_impl', 1000)
      allow(Cproton).to receive(:pn_messenger_get)
        .with('messenger_impl', kind_of(SWIG::TYPE_p_pn_message_t)).and_return 0
      expect(@proton.collect_message().impl).to be_a_kind_of(SWIG::TYPE_p_pn_message_t)
    end
    it 'failed' do
      allow(Cproton).to receive(:pn_messenger_work)
        .with('messenger_impl', 1000)
      allow(Cproton).to receive(:pn_messenger_get)
        .with('messenger_impl', kind_of(SWIG::TYPE_p_pn_message_t)).and_return Qpid::Proton::Error::ARGUMENT
      allow(Cproton).to receive(:pn_messenger_error).and_return('some text')
      allow(Cproton).to receive(:pn_error_text).and_return('some text')
      expect do
        @proton.collect_message()
      end.to raise_error(Qpid::Proton::ArgumentError)
    end
  end
  

end
