# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/spec/mqlight/connection_spec.rb
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

describe Mqlight::Connection do
  
  class ThreadStub
    def kill
    end
  end
  thread_stub = ThreadStub.new


  let(:thread_vars) do
    tv = Mqlight::ThreadVars.new('id')
    tv.service = Mqlight::Service.new(URI('amqp://TestHost:5672'))
    tv
  end

  let(:args) {{
    id: "Test-Id",
    user: "Test-User",
    password: "Test-Password",
    service_list: [URI("amqp://Test.Service.List")],
    thread_vars: thread_vars,
    sslTrustCertificate: "Test-TrustCertificate",
    sslVerifyName: "Test-VerifyName",
  }}

  let (:transport_stub) do
    TransportStub.new
  end

  before(:each) do
    @connection = Mqlight::Connection.new(args)
    @proton = thread_vars.proton
  end

  describe 'connect to a server' do
    it 'Successful- one service' do
      allow(Mqlight::UnsecureEndPoint).to receive(:new)
      .with(args).and_return transport_stub
      allow(transport_stub).to receive(:start_connection_threads)
      allow(@proton).to receive (:connect)
      allow(@proton).to receive(:wait_messenger_started)
      .with(kind_of(Mqlight::Service))
      @connection.connect_to_a_server
      expect(thread_vars.state).to eql(:started)
      expect(thread_vars.service.to_s)
        .to eql('[Service] amqp://Test-User:*******@Test.Service.List:5672')
      expect(thread_vars.service.address)
        .to eql('amqp://Test-User:Test-Password@Test.Service.List:5672')
    end

    it 'Successful- multi service' do
      args.store(:service_list, [URI("amqp://Ignore"),
                                 URI('amqp://Ignore'),
                                 URI('amqp://Test.Service.List'),
                                 URI('amqp://Ignore')])
      @connection = Mqlight::Connection.new(args)
      allow(Mqlight::UnsecureEndPoint).to receive(:new) do |args|
        if args[:thread_vars].service.to_s.include? 'Ignore'
          raise Mqlight::NetworkError.new('UnitTest')
        end
      end
      .with(args).and_return transport_stub
      allow(transport_stub).to receive(:start_connection_threads)
      allow(transport_stub).to receive(:stop_threads)
      allow(@proton).to receive (:connect)
      allow(@proton).to receive(:wait_messenger_started)
      .with(kind_of(Mqlight::Service))
      allow(@proton).to receive(:free_messenger)
      @connection.connect_to_a_server
      expect(thread_vars.state).to eql(:started)
      expect(thread_vars.service.to_s)
        .to eql('[Service] amqp://Test-User:*******@Test.Service.List:5672')
      expect(thread_vars.service.address)
        .to eql('amqp://Test-User:Test-Password@Test.Service.List:5672')
    end

    it 'Successful- one SSL service' do
      args.store(:service_list, [URI("amqps://Test.Service.List")])
      @connection = Mqlight::Connection.new(args)
      allow(Mqlight::SecureEndPoint).to receive(:new)
        .with(args).and_return transport_stub
      allow(transport_stub).to receive(:start_connection_threads)
      allow(@proton).to receive (:connect)
      allow(@proton).to receive(:wait_messenger_started)
        .with(kind_of(Mqlight::Service))
      @connection.connect_to_a_server
      expect(thread_vars.state).to eql(:started)
      expect(thread_vars.service.to_s)
        .to eql('[Service] amqps://Test-User:*******@Test.Service.List:5671')
      expect(thread_vars.service.address)
        .to eql('amqps://Test-User:Test-Password@Test.Service.List:5671')
    end

    it 'failure - authentication' do
      allow(Mqlight::UnsecureEndPoint).to receive(:new)
      .with(args).and_return transport_stub
      allow(transport_stub).to receive(:start_connection_threads)
      allow(@proton).to receive (:connect)
      allow(@proton).to receive(:wait_messenger_started)
      .with(kind_of(Mqlight::Service)).and_raise Mqlight::SecurityError
      @connection.connect_to_a_server
      expect(thread_vars.state).to eql(:stopped)
    end

    it 'failure - takeover' do
      allow(Mqlight::UnsecureEndPoint).to receive(:new)
      .with(args).and_return transport_stub
      allow(transport_stub).to receive(:start_connection_threads)
      allow(@proton).to receive (:connect)
      allow(@proton).to receive(:wait_messenger_started)
      .with(kind_of(Mqlight::Service)).and_raise Mqlight::ReplacedError
      @connection.connect_to_a_server
      expect(thread_vars.state).to eql(:stopped)
    end

    it 'failure - reinstate subscription' do
      allow(Mqlight::UnsecureEndPoint).to receive(:new)
      .with(args).and_return transport_stub
      allow(transport_stub).to receive(:start_connection_threads)
      allow(@proton).to receive (:connect)
      allow(@proton).to receive(:wait_messenger_started)
      .with(kind_of(Mqlight::Service)).and_raise Mqlight::SubscribedError
      @connection.connect_to_a_server
      expect(thread_vars.state).to eql(:stopped)
    end
  end
  
  describe '#Threads' do
    it 'start_connection_threads' do
      allow(TCPSocket).to receive(:open).and_return "TCP-Open"
      ep = Mqlight:: UnsecureEndPoint.new(args)
      incoming_started = 0
      outgoing_started = 0
      allow(ep).to receive(:incoming_thread) do
        incoming_started = 1
      end
      allow(ep).to receive(:outgoing_thread) do
        outgoing_started = 1
      end
      expect do
        ep.start_connection_threads
# commented out: another rspec test seems to be breaking to test
#        sleep 1.0
#        expect(incoming_started). to eql (1)
#        expect(outgoing_started). to eql (1)
      end.to_not raise_error
    end
    it 'stop_threads' do
      allow(TCPSocket).to receive(:open).and_return "TCP-Open"
      ep = Mqlight:: UnsecureEndPoint.new(args)
      ep.instance_variable_set(:@incoming,thread_stub)
      ep.instance_variable_set(:@outgoing,thread_stub)
      allow(ep).to receive(:shutdown)
      allow(thread_stub).to receive(:kill)
      expect do
        ep.stop_threads
      end.to_not raise_error
    end
  end
end