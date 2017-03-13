# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/spec/mqlight/endpoints_spec.rb
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

supress_endpoints_mocking=true
require 'spec_helper'

class DeliveryStub
end
delivery_stub = DeliveryStub.new

class TCPSocketStub
end
tcp_socket_stub = TCPSocketStub.new

class SSLSocketStub
end
ssl_socket_stub = SSLSocketStub.new

#
#
#
describe 'EndPoints' do
  let(:thread_vars) do
    tv = Mqlight::ThreadVars.new('id')
    tv.service = Mqlight::Service.new(URI('amqp://hostname:1234'))
    tv.state = :stopped
    tv
  end
  
  let(:args) {{
    id: "Test-Id",
    user: "Test-User",
    password: "Test-Password",
    service_list: ["amqp://Test.Service.List"],
    thread_vars: thread_vars,
    sslTrustCertificate: "Test-TrustCertificate",
    sslVerifyName: "Test-VerifyName"
  }}
  
  
  describe '#IO-Threads' do
    before(:each) do
      allow(TCPSocket).to receive(:open)
        .with('hostname',1234).and_return tcp_socket_stub
      allow(Mqlight::UnsecureEndPoint).to receive(:new).and_call_original
      allow(Mqlight::SecureEndPoint).to receive(:new).and_call_original
      allow(OpenSSL::SSL::SSLSocket).to receive(:new).and_return ssl_socket_stub
    end

    describe 'Unsecure' do
#      it 'initialiation-success' do
#        transport = Mqlight::UnsecureEndPoint.new(thread_vars: thread_vars)
#        expect(transport.stopped?).to be true
#      end
      
      it 'initialisation-failed' do
        transport = Mqlight::UnsecureEndPoint.new(thread_vars: thread_vars)
        allow(tcp_socket_stub).to receive(:recv)
          .with(1024).and_raise Errno::ECONNRESET
        thread_vars.state = :started
        expect do 
          transport.incoming_thread
        end.not_to raise_error
        expect(transport.retrying?).to be true
      end

      it 'process-and-close' do
        transport = Mqlight::UnsecureEndPoint.new(thread_vars: thread_vars)
        thread_vars.state = :started
        lc = 0
        rx_count = 0
         allow(thread_vars.proton).to receive(:proton_push) do
          rx_count += 1
          100
        end
        allow(tcp_socket_stub).to receive(:recv).with(1024) do
          lc += 1
          msg = nil
          msg = "A message"   if lc <= 5
          msg
        end

        transport.incoming_thread
        expect(rx_count).to eql 5
        expect(transport.stopped?).to be false
      end

      describe '#Outgoing thread' do
        it 'process-and-close' do
          transport = Mqlight::UnsecureEndPoint.new(thread_vars: thread_vars)
          tcp_socket = transport.instance_variable_get('@transport')
          thread_vars.state = :started
          lc = 0
          tx_count = 0
          allow(thread_vars.proton).to receive(:create_delivery_message) do
            delivery_stub
          end
          allow(delivery_stub).to receive(:get) do
            lc += 1
            thread_vars.state = :stopped if lc >= 5
            "A message"
          end
          allow(tcp_socket).to receive(:write) do
            tx_count += 1
          end
          allow(tcp_socket).to receive(:flush)
          transport.outgoing_thread
          expect(tx_count).to eql 5
          expect(transport.stopped?).to be true
        end
        
        it 'process-with-pop-check' do
          transport = Mqlight::UnsecureEndPoint.new(thread_vars: thread_vars)
          tcp_socket = transport.instance_variable_get('@transport')
          thread_vars.state = :started
          lc = 0
          tx_count = 0
          pop_count = 0
          allow(thread_vars.proton).to receive(:create_delivery_message)
            .and_return delivery_stub
          allow(delivery_stub).to receive(:get) do
            lc += 1
            thread_vars.state = :stopped if lc >= 5
            nil
          end
          allow(delivery_stub).to receive(:empty_pop) do
            pop_count += 1
          end
          allow(tcp_socket).to receive(:write) do
            tx_count += 1
          end
          transport.outgoing_thread
          expect(pop_count).to eql 5
          expect(tx_count).to eql 0
          expect(transport.stopped?).to be true
        end
      end
    end

## A stub object for tests below.
    class SecureSocketStub
      def context(args)
      end
      def verify_server_host_name_failed?
        false
      end
    end

    describe "Secure" do
      it 'initialisation-success' do
        allow(ssl_socket_stub).to receive(:connect)
        args = {
          thread_vars: thread_vars,
          ssl: SecureSocketStub.new
        }
        transport = Mqlight::SecureEndPoint.new(args)
        expect(transport.stopped?).to be true
      end
      
      it 'initialisation-failed-network' do
        allow(ssl_socket_stub).to receive(:connect).and_raise Errno::ECONNRESET, 'General network error'
        expect do
          args = {
            thread_vars: thread_vars,
            ssl: SecureSocketStub.new
          }
          transport = Mqlight::SecureEndPoint.new(args)
        end.to raise_error(Mqlight::NetworkError)
      end
      
      it 'initialisation-failed-security' do
        allow(ssl_socket_stub).to receive(:connect).and_raise Errno::ECONNRESET, 'certificate verify failed'
        expect do
          args = {
            thread_vars: thread_vars,
            ssl: SecureSocketStub.new
          }
          transport = Mqlight::SecureEndPoint.new(args)
        end.to raise_error(Mqlight::SecurityError)
      end
    end

  end
end