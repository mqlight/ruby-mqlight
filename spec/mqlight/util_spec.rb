# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/spec/mqlight/util_spec.rb
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

describe Mqlight::Util do
  describe '.get_service_urls' do
    it 'fails if passed a non uri string' do
      expect do
        Mqlight::Util.get_service_urls('not a uri')
      end.to raise_error(URI::InvalidURIError)
    end

    it 'fails if passed a unsupported uri string' do
      expect do
        Mqlight::Util.get_service_urls('ftp://example.com')
      end.to raise_error(ArgumentError)
    end

    it 'makes an http request if passed an http uri string' do
      stub = stub_request(:get, 'http://example.com/blah')
             .to_return(body: "{\"service\":[\"amqp:\/\/example.com:5672\","\
                              "\"amqp:\/\/example.com:5673\"]}", status: 200)
      Mqlight::Util.get_service_urls('http://example.com/blah')
      expect(stub).to have_been_requested
    end

    it 'makes an https request if passed an https uri string' do
      stub = stub_request(:get, 'https://example.com/blah')
             .to_return(body: "{\"service\":[\"amqp:\/\/example.com:5672\","\
                              "\"amqp:\/\/example.com:5673\"]}", status: 200)
      Mqlight::Util.get_service_urls('https://example.com/blah')
      expect(stub).to have_been_requested
    end

    it 'makes an http request include GET params if passed' do
      stub = stub_request(:get, 'http://example.com/blah?serviceId=foo')
             .to_return(body: "{\"service\":[\"amqp:\/\/example.com:5672\","\
                              "\"amqp:\/\/example.com:5673\"]}", status: 200)
      Mqlight::Util.get_service_urls('http://example.com/blah?serviceId=foo')
      expect(stub).to have_been_requested
    end

    it 'makes an https request include GET params if passed' do
      stub = stub_request(:get, 'https://example.com/blah?serviceId=foo')
             .to_return(body: "{\"service\":[\"amqp:\/\/example.com:5672\","\
                              "\"amqp:\/\/example.com:5673\"]}", status: 200)
      Mqlight::Util.get_service_urls('https://example.com/blah?serviceId=foo')
      expect(stub).to have_been_requested
    end

    it 'fails if a http request returns a non-200 response' do
      stub = stub_request(:get, 'http://example.com/blah')
             .to_return(body: "{\"service\":[\"amqp:\/\/example.com:5672\","\
                              "\"amqp:\/\/example.com:5673\"]}", status: 400)
      expect do
        Mqlight::Util.get_service_urls('http://example.com/blah')
      end.to raise_error(Mqlight::NetworkError)
      expect(stub).to have_been_requested
    end

    it 'fails if a http request returns a non-json response' do
      stub = stub_request(:get, 'http://example.com/blah')
             .to_return(body: 'not json', status: 200)
      expect do
        Mqlight::Util.get_service_urls('http://example.com/blah')
      end.to raise_error(JSON::ParserError)
      expect(stub).to have_been_requested
    end
  end

  # Validate and combination the new SSL arguments.
  describe '.SecureSocket' do
    before(:each) do
      allow(File).to receive(:exist?) do |filePath|
        fail ArgumentError, "INTERNAL-ERROR: missing or null exist? argument" if filePath.nil?
        filePath.include? 'ispresent'
      end
      allow(File).to receive(:file?) do |filePath|
        fail ArgumentError, "INTERNAL-ERROR: missing or null file? argument" if filePath.nil?
        filePath.include? 'isfile'
      end
      allow(File).to receive(:binread) do |filePath|
        fail ArgumentError, "INTERNAL-ERROR: missing or null exist? argument" if filePath.nil?
         fail IOError, '<Errno::ENOENT: No such file or directory @ rb_sysopen - ' +filePath +'>' unless filePath.include? 'ispresent'
        "PKCS12TextAsString"
      end
      allow(OpenSSL::PKCS12).to receive(:new) do |data, passphrase|
        "PKCS12Object"
      end
    end

    describe '.option_type' do
      context '.ssl_client_certificate' do
        it 'success if type is String' do
          expect do
            Mqlight::SecureSocket.new({
              ssl_client_certificate: '/ispresent/isfile',
              ssl_client_key: '/ispresent/isfile',
              ssl_client_key_passphrase: 'passphrase'})
          end.not_to raise_error
        end
        it 'failed if type is integer' do
          expect do
            Mqlight::SecureSocket.new({ssl_client_certificate: 12})
          end.to raise_error ArgumentError
        end
      end
      context '.ssl_trust_certificate' do
        it 'success if type is String' do
          expect do
            Mqlight::SecureSocket.new({
              ssl_trust_certificate:  '/ispresent/isfile'})
          end.not_to raise_error
        end
        it 'failed if type is integer' do
          expect do
            Mqlight::SecureSocket.new({ssl_trust_certificate: 12})
          end.to raise_error ArgumentError
        end
      end
      context '.ssl_client_key' do
        it 'success if type is String' do
          expect do
            Mqlight::SecureSocket.new({
              ssl_client_certificate: '/ispresent/isfile',
              ssl_client_key: '/ispresent/isfile',
              ssl_client_key_passphrase: 'passphrase'})
          end.not_to raise_error
        end
        it 'failed if type is integer' do
          expect do
            ssl_client_certificate   Mqlight::SecureSocket.new(ssl_client_key: 12)
          end.to raise_error ArgumentError
        end
      end
      context '.ssl_client_key_passphrase' do
        it 'success if type is String' do
          expect do
            Mqlight::SecureSocket.new({
              ssl_client_certificate: '/ispresent/isfile',
              ssl_client_key: '/ispresent/isfile',
              ssl_client_key_passphrase: 'passphrase'})
          end.not_to raise_error
        end
        it 'failed if type is integer' do
          expect do
            Mqlight::SecureSocket.new({
              ssl_client_key: '/ispresent/isfile',
              ssl_client_key_passphrase: 12})
          end.to raise_error ArgumentError
        end
      end
      
      context '.ssl_keystore' do
        it 'success if type is String' do
          expect do
            Mqlight::SecureSocket.new({
              ssl_keystore: '/ispresent/isfile',
              ssl_keystore_passphrase: 'passphrase'
            })
          end.not_to raise_error
        end
        it 'failed if type is integer' do
          expect do
            Mqlight::SecureSocket.new({
              ssl_keystore: 23,
              ssl_keystore_passphrase: 'passphrase'
            })
          end.to raise_error ArgumentError
        end
      end
      context '.ssl_keystore_passphrase' do
        it 'success if type is String' do
          expect do
            Mqlight::SecureSocket.new({
              ssl_keystore: '/ispresent/isfile',
              ssl_keystore_passphrase: 'passphrase'})
          end.not_to raise_error
        end
        it 'failed if type is integer' do
          expect do
            Mqlight::SecureSocket.new({
              ssl_keystore: '/ispresent/isfile',
              ssl_keystore_passphrase: 12})
          end.to raise_error ArgumentError
        end
      end
    end
    context '.combination' do
      it '.ssl_keystore with ssl_client_certificate' do
        expect do
          Mqlight::SecureSocket.new({
            ssl_keystore: '/ispresent/isfile',
            ssl_client_certificate: '/ispresent/isfile'})
        end.to raise_error ArgumentError
      end
      it '.ssl_keystore with ssl_trust_certificate' do
        expect do
          Mqlight::SecureSocket.new({
            ssl_keystore: '/ispresent/isfile',
            ssl_trust_certificate: '/ispresent/isfile'})
        end.to raise_error ArgumentError
      end
      it '.ssl_keystore with ssl_client_key' do
        expect do
          Mqlight::SecureSocket.new({
            ssl_keystore: '/ispresent/isfile',
            ssl_client_key: '/ispresent/isfile'})
        end.to raise_error ArgumentError
      end
      it '.ssl_keystore with ssl_client_key_passphrase' do
        expect do
          Mqlight::SecureSocket.new({
            ssl_keystore: '/ispresent/isfile',
            ssl_client_key_passphrase: 'passphrase'})
        end.to raise_error ArgumentError
      end
    end
    it '.ssl_keystore with ssl_client_certificate' do
      expect do
        Mqlight::SecureSocket.new({
          ssl_keystore_passphrase: 'passphrase',
          ssl_client_certificate: '/ispresent/isfile'})
      end.to raise_error ArgumentError
    end
    it '.ssl_keystore with ssl_trust_certificate' do
      expect do
        Mqlight::SecureSocket.new({
          ssl_keystore_passphrase: 'passphrase',
          ssl_trust_certificate: '/ispresent/isfile'})
      end.to raise_error ArgumentError
    end
    it '.ssl_keystore with ssl_client_key' do
      expect do
        Mqlight::SecureSocket.new({
          ssl_keystore_passphrase: 'passphrase',
          ssl_client_key: '/ispresent/isfile'})
      end.to raise_error ArgumentError
    end
    it '.ssl_keystore with ssl_client_key_passphrase' do
      expect do
        Mqlight::SecureSocket.new({
          ssl_keystore_passphrase: 'passphrase',
          ssl_client_key_passphrase: 'passphrase'})
      end.to raise_error ArgumentError
    end
    context '.missing file' do
      it '.ssl_client_certificate' do
        expect do
          Mqlight::SecureSocket.new({ssl_client_certificate: '/missing/isfile'})
        end.to raise_error ArgumentError
      end
      it '.ssl_trust_certificate' do
        expect do
          Mqlight::SecureSocket.new({ssl_trust_certificate: '/missing/isfile'})
        end.to raise_error ArgumentError
      end
      it '.ssl_client_key' do
        expect do
          Mqlight::SecureSocket.new({ssl_client_key: '/missing/isfile'})
        end.to raise_error ArgumentError
      end
      it '.ssl_keystore' do
        expect do
          Mqlight::SecureSocket.new({ssl_keystore: '/missing/isfile'})
        end.to raise_error ArgumentError
      end
    end
    context '.invalid file' do
      it '.ssl_client_certificate' do
        expect do
          Mqlight::SecureSocket.new({ssl_client_certificate: '/ispresent/isNotfile'})
        end.to raise_error ArgumentError
      end
      it '.ssl_trust_certificate' do
        expect do
          Mqlight::SecureSocket.new({ssl_trust_certificate: '/ispresent/isNotfile'})
        end.to raise_error ArgumentError
      end
      it '.ssl_client_key' do
        expect do
          Mqlight::SecureSocket.new({ssl_client_key: '/ispresent/isNotfile'})
        end.to raise_error ArgumentError
      end
      it '.ssl_keystore' do
        expect do
          Mqlight::SecureSocket.new({ssl_keystore: '/ispresent/isNotfile'})
        end.to raise_error ArgumentError
      end
    end
    context '.ssl_combinations' do
      it 'fail - ssk_keystore with ssl_client_certificate' do
        expect do
          Mqlight::SecureSocket.new({
            ssl_keystore: '/ispresent/isfile',
            ssl_keystore_passphrase: 'passphrase',
            ssl_client_certificate: '/ispresent/isfile'
          })
        end.to raise_error ArgumentError
      end
      it 'fail - ssl_keystore with ssl_trust_certificate' do
        expect do
          Mqlight::SecureSocket.new({
            ssl_keystore: '/ispresent/isfile',
            ssl_keystore_passphrase: 'passphrase',
            ssl_trust_certificate: '/ispresent/isfile'
          })
        end.to raise_error ArgumentError
      end
      it 'fail - ssl_keystore with ssl_client_key' do
        expect do
          Mqlight::SecureSocket.new({
            ssl_keystore: '/ispresent/isfile',
            ssl_keystore_passphrase: 'passphrase',
            ssl_client_key: '/ispresent/isfile'
          })
        end.to raise_error ArgumentError
      end
      # No check for not_keystore with only ssl_keystore_passphrase
      # as it will be ignore as 
      it 'fail - ssl_not_keystore with ssl_keystore' do
        expect do
          Mqlight::SecureSocket.new({
            ssl_client_certificate: '/ispresent/isfile',
            ssl_trust_certificate: '/ispresent/isfile',
            ssl_client_key: '/ispresent/isfile',
            ssl_client_key_pass_phrase: 'passphrase',
            ssl_keystore: '/ispresent/isfile',
          })
        end.to raise_error ArgumentError
      end
      it 'fail - ssl_not_keystore with ssl_keystore_passphrase' do
        expect do
          Mqlight::SecureSocket.new({
            ssl_client_certificate: '/ispresent/isfile',
            ssl_trust_certificate: '/ispresent/isfile',
            ssl_client_key: '/ispresent/isfile',
            ssl_client_key_pass_phrase: 'passphrase',
            ssl_keystore_passphrase: 'passphrase',
          })
        end.to raise_error ArgumentError
      end
      it 'success - ssl_not_keystore only' do
        expect do
          Mqlight::SecureSocket.new({
            ssl_client_certificate: '/ispresent/isfile',
            ssl_trust_certificate: '/ispresent/isfile',
            ssl_client_key: '/ispresent/isfile',
            ssl_client_key_passphrase: 'passphrase'
          })
        end.not_to raise_error
      end
      it 'success - ssk_keystore only' do
        expect do
          Mqlight::SecureSocket.new({
            ssl_client_certificate: '/ispresent/isfile',
            ssl_trust_certificate: '/ispresent/isfile',
            ssl_client_key: '/ispresent/isfile',
            ssl_client_key_passphrase: 'passphrase'
          })
        end.not_to raise_error
      end
    end
    context 'ssl_verify_name' do
      it 'success - valid option' do
        expect do
          Mqlight::SecureSocket.new({
            ssl_trust_certificate: '/ispresent/isfile',
            ssl_verify_name: true
          })
        end.not_to raise_error
      end
      it 'fail -- invalid type' do
        expect do
          Mqlight::SecureSocket.new({
            ssl_trust_certificate: '/ispresent/isfile',
            ssl_verify_name: 12
          })
        end.to raise_error ArgumentError
      end
    end
  end
end
