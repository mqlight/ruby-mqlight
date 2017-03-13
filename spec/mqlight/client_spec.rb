# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/spec/mqlight/client_spec.rb
#
# <copyright
# notice="lm-source-program"
# pids="5725-P60"
# years="2014,2015"
# crc="3568777996" >
# Licensed Materials - Property of IBM
#
# 5725-P60
#
# (C) Copyright IBM Corp. 2014, 2015
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
# </copyright>

require 'spec_helper'
require 'spec_unsecure_helper'

test_service_uri = 'amqp://localhost:5672'

describe Mqlight::BlockingClient do

  describe '#new' do
    it 'creates a client' do
      client = Mqlight::BlockingClient.new(test_service_uri)
      expect(client).to be_an_instance_of Mqlight::BlockingClient
    end

    it 'sets id to the supplied id' do
      client = Mqlight::BlockingClient.new(test_service_uri, id: 'blah')
      expect(client.id).to eq('blah')
    end

    it 'generates a random 12 character client id if none is supplied' do
      client = Mqlight::BlockingClient.new(test_service_uri)
      expect(client.id.length).to eq(12)
    end

    it 'should accept a client id containing supported characters' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri, id: 'abcDEF._/%')
      end.to_not raise_error
    end

    it 'should reject a client id containing unsupported characters' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri, id: '12:34')
      end.to raise_error(ArgumentError, /:/)
    end

    it 'fails if passed an oversized id' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri, id: 'a' * 260)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a numeric id' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri, id: 1)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a boolean id' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri, id: true)
      end.to raise_error(ArgumentError)
      expect do
        Mqlight::BlockingClient.new(test_service_uri, id: false)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed an array as an id' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri, id: [])
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a symbol as an id' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri, id: :symbol)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a hash as an id' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri, id: {})
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed only a username' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri, user: 'name')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed only a password' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri, password: 'pw')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a number as a password' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri,
                                    user: 'name', password: 1)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a boolean as a password' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri,
                                    user: 'name', password: true)
      end.to raise_error(ArgumentError)
      expect do
        Mqlight::BlockingClient.new(test_service_uri,
                                    user: 'name', password: false)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed an array as a password' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri,
                                    user: 'name', password: [])
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a hash as a password' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri,
                                    user: 'name', password: {})
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a symbol as a password' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri,
                                    user: 'name', password: :symbol)
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a number as a username' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri,
                                    user: 1, password: 'pw')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a boolean as a username' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri,
                                    user: true, password: 'pw')
      end.to raise_error(ArgumentError)
      expect do
        Mqlight::BlockingClient.new(test_service_uri,
                                    user: false, password: 'pw')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed an array as a username' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri,
                                    user: [], password: 'pw')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a hash as a username' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri,
                                    user: {}, password: 'pw')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed a symbol as a password' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri,
                                    user: :symbol, password: 'pw')
      end.to raise_error(ArgumentError)
    end

    it 'sets the username if a username and password together' do
      client = Mqlight::BlockingClient.new(test_service_uri,
                                           user: 'name', password: 'pw')
      expect(client.instance_variable_get(:@user)).to eq 'name'
    end

    it 'sets the password if a username and password together' do
      client = Mqlight::BlockingClient.new(test_service_uri,
                                           user: 'name', password: 'pw')
      expect(client.instance_variable_get(:@password)).to eq 'pw'
    end

    it 'succeeds if a username and password are used containing reserved '\
       'characters' do
      expect do
        Mqlight::BlockingClient.new(test_service_uri,
                                    user: '[username',
                                    password: '[password')
      end.to_not raise_error
    end

    it 'adds a valid amqp service url string to its service list' do
      client = Mqlight::BlockingClient.new(test_service_uri)
      expect(client.instance_variable_get(:@service_list))
        .to include(URI(test_service_uri))
    end

    it 'adds a valid amqp service url containing auth to its service list' do
      client = Mqlight::BlockingClient.new('amqp://name:pw@localhost')
      expect(client.instance_variable_get(:@service_list))
        .to include(URI('amqp://name:pw@localhost:5672'))
    end

    it 'adds a service url containing auth if given matching user and pw' do
      client = Mqlight::BlockingClient.new('amqp://name:pw@localhost',
                                           user: 'name', password: 'pw')
      expect(client.instance_variable_get(:@service_list))
        .to include(URI('amqp://name:pw@localhost:5672'))
    end

    it 'fails if service url auth and supplied user and pw do not match' do
      expect do
        Mqlight::BlockingClient.new('amqp://name:pw@localhost',
                                    user: 'foo', password: 'bar')
      end.to raise_error(ArgumentError)
    end

    # TODO: test timeout too short
    # it 'sets service_lookup_uri to a valid http url if one is supplied' do
    #  expect(Mqlight::Util).to receive(:get_service_urls)
    #    .with('http://example.com')
    #    .and_return ['amqp://example.com:5672', 'amqp://example.com:5673']
    #  client = Mqlight::BlockingClient.new('http://example.com')
    #  expect(client.instance_variable_get(:@service_lookup_uri))
    #    .to eq('http://example.com')
    # end

    # TODO: test timeout too short
    # it 'sets service_lookup_uri to a valid https url if one is supplied' do
    #  expect(Mqlight::Util).to receive(:get_service_urls)
    #    .with('https://example.com')
    #    .and_return ['amqp://example.com:5672', 'amqp://example.com:5673']
    #  client = Mqlight::BlockingClient.new('https://example.com')
    #  expect(client.instance_variable_get(:@service_lookup_uri))
    #    .to eq('https://example.com')
    # end

    it 'fails if passed a non amqp service url' do
      expect do
        Mqlight::BlockingClient.new('notaurl')
      end.to raise_error(ArgumentError)
      expect do
        Mqlight::BlockingClient.new('ftp://localhost:5672')
      end.to raise_error(ArgumentError)
    end

    it 'fails if passed an invalid amqp service url' do
      expect do
        Mqlight::BlockingClient.new('amqp://here:34:34')
      end.to raise_error(ArgumentError)
    end

    it 'adds an array of amqp urls to its service list' do
      client = Mqlight::BlockingClient.new([test_service_uri,
                                            'amqp://localhost:5673'])
      expect(client.instance_variable_get(:@service_list))
        .to match_array([URI(test_service_uri), URI('amqp://localhost:5673')])
    end

    it 'fails if passed no service url' do
      expect { Mqlight::BlockingClient.new }.to raise_error(ArgumentError)
    end
  end

  describe '#start' do
    before(:each) do
      @client = Mqlight::BlockingClient.new(test_service_uri)
    end

    after(:each) do
      @client.stop if @client
    end

    context 'when stopped' do
      it 'client transitions to started' do
        @client.stop
        @client.start
        expect(@client.state).to be :started
        expect(@client.started?).to be true
        expect(@client.stopped?).to be false
      end

      it 'attempts each entry in the list of service uris until successful' do
        @client.stop
        service_list = ['amqp://host1:5672',
                        'amqp://host2:5672',
                        'amqp://host3:5672']

        call_count = 0
        allow(Cproton).to receive(:pn_messenger_started) do
          call_count += 1
          unless call_count == service_list.length
            fail Qpid::Proton::ProtonError, 'error'
          end
          0
        end
        service_list.each do |service|
          expect(Cproton).to receive(:pn_messenger_route)
            .with(kind_of(SWIG::TYPE_p_pn_messenger_t),
                  service + '/*',
                  kind_of(String))
        end
        expect(@client.state).to be :stopped
        @client = Mqlight::BlockingClient.new(service_list)
        @client.start
        expect(@client.state).to be :started
        expect(@client.started?).to be true
        expect(@client.stopped?).to be false
      end
    end

    context 'when started' do
      it 'client remains started' do
        @client.start
        expect(@client.state).to be :started
        expect(@client.started?).to be true
        expect(@client.stopped?).to be false
      end
    end
  end

  describe '#stop' do
    before(:each) do
      @client = Mqlight::BlockingClient.new(test_service_uri)
    end

    after(:each) do
      @client.stop if @client
    end

    context 'when stopped' do
      it 'client remains stopped' do
        @client.stop
        @client.stop
        expect(@client.state).to be :stopped
        expect(@client.started?).to be false
        expect(@client.stopped?).to be true
      end
    end

    context 'when started' do
      it 'client transitions to stopped' do
        @client.stop
        expect(@client.state).to be :stopped
        expect(@client.started?).to be false
        expect(@client.stopped?).to be true
      end
    end
  end

  describe '#send' do
    before(:each) do
      @client = Mqlight::BlockingClient.new(test_service_uri)
    end

    after(:each) do
      @client.stop if @client
    end

    context 'when stopped' do
      it 'raises a StoppedError' do
        @client.stop
        expect do
          @client.send('topic', 'message')
        end.to raise_error(Mqlight::StoppedError)
      end
    end

    context 'when started' do
      it 'fails if passed no arguments' do
        expect { @client.send }.to raise_error(ArgumentError)
      end

      it 'fails if only passed one argument' do
        expect { @client.send('topic') }.to raise_error(ArgumentError)
      end

      it 'fails if passed a number as a topic' do
        expect { @client.send(1, 'data') }.to raise_error(ArgumentError)
      end

      it 'fails if passed a boolean as a topic' do
        expect { @client.send(true, 'data') }.to raise_error(ArgumentError)
        expect { @client.send(false, 'data') }.to raise_error(ArgumentError)
      end

      it 'fails if passed an array as a topic' do
        expect { @client.send([], 'data') }.to raise_error(ArgumentError)
      end

      it 'fails if passed a symbol as a topic' do
        expect { @client.send(:symbol, 'data') }.to raise_error(ArgumentError)
      end

      it 'fails if passed a hash as a topic' do
        expect { @client.send({}, 'data') }.to raise_error(ArgumentError)
      end

      it 'fails if passed a string as options' do
        expect do
          @client.send('topic', 'data', 'options')
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed a number as options' do
        expect do
          @client.send('topic', 'data', 1)
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed a boolean as options' do
        expect do
          @client.send('topic', 'data', true)
        end.to raise_error(ArgumentError)
        expect do
          @client.send('topic', 'data', false)
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed an array as options' do
        expect do
          @client.send('topic', 'data', [])
        end.to raise_error(ArgumentError)
      end

      # TODO: disabled as @reply_queue has moved.
      # it 'completes if passed nil options' do
      #  expect(@client.instance_variable_get(:@reply_queue)).to receive(:pop)
      #    .and_return nil
      #  @client.send('topic', 'data', nil)
      # end

      it 'fails if passed a string as ttl' do
        expect do
          @client.send('topic', 'data', ttl: 'qos')
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed a boolean ttl' do
        expect do
          @client.send('topic', 'data', ttl: true)
        end.to raise_error(ArgumentError)
        expect do
          @client.send('topic', 'data', ttl: false)
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed an array as a ttl' do
        expect do
          @client.send('topic', 'data', ttl: [])
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed a hash as a ttl' do
        expect do
          @client.send('topic', 'data', ttl: {})
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed a symbol as a ttl' do
        expect do
          @client.send('topic', 'data', ttl: :symbol)
        end.to raise_error(ArgumentError)
      end

      # TODO: disabled as @reply_queue has moved.
      # it 'completes if passed an integer ttl' do
      #  expect(@client.instance_variable_get(:@reply_queue)).to receive(:pop)
      #    .and_return nil
      #  @client.send('topic', 'data', ttl: 1)
      # end

      it 'fails if passed a string as a timeout' do
        expect do
          @client.send('topic', 'data', timeout: 'timeout')
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed a negative timeout' do
        expect do
          @client.send('topic', 'data', timeout: -1)
        end.to raise_error(ArgumentError)
      end

      it 'completes if passed a positive timeout' do
        expect do
          @client.send('topic', 'data', timeout: 5000)
        end.not_to raise_error
      end

      it 'completes if passed a nil timeout' do
        expect do
          @client.send('topic', 'data', timeout: nil)
        end.not_to raise_error
      end

      it 'treats message addresses as immutable strings not URIs' do
        expect(Cproton).to receive(:pn_message_set_address)
          .with(kind_of(SWIG::TYPE_p_pn_message_t),
                "#{test_service_uri}/test/a topic")
          .and_return Qpid::Proton::Error::NONE
        @client.send('test/a topic', 'data')
      end
    end
  end

  describe '#subscribe' do
    before(:each) do
      @client = Mqlight::BlockingClient.new(test_service_uri)

      calls = 0
      allow(Cproton).to receive(:pn_messenger_get_link) do
        calls += 1
        calls <= 1 ? nil : (SWIG::TYPE_p_pn_link_t)
      end
    end

    after(:each) do
      @client.stop if @client
    end

    context 'when stopped' do
      it 'raises a StoppedError' do
        @client.stop
        expect do
          @client.subscribe('topic')
        end.to raise_error(Mqlight::StoppedError)
      end
    end

    context 'when started' do
      it 'fails if passed no arguments' do
        expect { @client.subscribe }.to raise_error(ArgumentError)
      end

      it 'fails if passed a numeric topic_pattern' do
        expect { @client.subscribe(1) }.to raise_error(ArgumentError)
      end

      it 'fails if passed a boolean topic_pattern' do
        expect { @client.subscribe(true) }.to raise_error(ArgumentError)
        expect { @client.subscribe(false) }.to raise_error(ArgumentError)
      end

      it 'fails if passed a nil topic_pattern' do
        expect { @client.subscribe(nil) }.to raise_error(ArgumentError)
      end

      it 'fails if passed an array as a topic_pattern' do
        expect { @client.subscribe([]) }.to raise_error(ArgumentError)
      end

      it 'fails if passed an hash as a topic_pattern' do
        expect { @client.subscribe({}) }.to raise_error(ArgumentError)
      end

      it 'completes if passed a valid topic_pattern' do
        expect(Cproton).to receive(:pn_messenger_subscribe_ttl)
          .with(kind_of(SWIG::TYPE_p_pn_messenger_t),
                "#{test_service_uri}/private:topic",
                0)
          .and_return Qpid::Proton::Error::NONE
        @client.subscribe('topic')
      end

      it 'fails if passed a numeric share' do
        expect { @client.subscribe('topic', share: 1) }
          .to raise_error(ArgumentError)
      end

      it 'fails if passed a boolean share' do
        expect do
          @client.subscribe('topic', share: true)
        end.to raise_error(ArgumentError)
        expect do
          @client.subscribe('topic', share: false)
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed an array as a share' do
        expect { @client.subscribe('topic', share: []) }
          .to raise_error(ArgumentError)
      end

      it 'fails if passed a hash as a share' do
        expect { @client.subscribe('topic', share: {}) }
          .to raise_error(ArgumentError)
      end

      it 'fails if passed a share with a colon' do
        expect do
          @client.subscribe('topic', share: 'share:')
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed numeric options' do
        expect do
          @client.subscribe('topic', 1)
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed boolean options' do
        expect do
          @client.subscribe('topic', true)
        end.to raise_error(ArgumentError)
        expect do
          @client.subscribe('topic', false)
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed an array of options' do
        expect do
          @client.subscribe('topic', [])
        end.to raise_error(ArgumentError)
      end

      it 'completes if passed qos 0' do
        expect(Cproton).to receive(:pn_messenger_subscribe_ttl)
          .with(kind_of(SWIG::TYPE_p_pn_messenger_t),
                "#{test_service_uri}/private:topic",
                0)
          .and_return Qpid::Proton::Error::NONE
        @client.subscribe('topic', qos: 0)
      end

      it 'completes if passed qos 1' do
        expect(Cproton).to receive(:pn_messenger_subscribe_ttl)
          .with(kind_of(SWIG::TYPE_p_pn_messenger_t),
                "#{test_service_uri}/private:topic",
                0)
          .and_return Qpid::Proton::Error::NONE
        @client.subscribe('topic', qos: 1)
      end

      it 'fails if passed an unsupported numeric qos' do
        expect do
          @client.subscribe('topic', qos: -1)
        end.to raise_error(ArgumentError)
        expect do
          @client.subscribe('topic', qos: 2)
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed a string qos' do
        expect do
          @client.subscribe('topic', qos: 'qos')
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed a true boolean qos' do
        expect do
          @client.subscribe('topic', qos: true)
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed an array as a qos' do
        expect do
          @client.subscribe('topic', qos: [])
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed a hash as a qos' do
        expect do
          @client.subscribe('topic', qos: {})
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed an invalid numeric ttl' do
        expect do
          @client.subscribe('topic', ttl: -1)
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed a string as a ttl' do
        expect do
          @client.subscribe('topic', ttl: 'ttl')
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed a true boolean ttl' do
        expect do
          @client.subscribe('topic', ttl: true)
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed a hash as a ttl' do
        expect do
          @client.subscribe('topic', ttl: {})
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed an array as a ttl' do
        expect do
          @client.subscribe('topic', ttl: [])
        end.to raise_error(ArgumentError)
      end

      it 'completes if passed a nil share' do
        expect(Cproton).to receive(:pn_messenger_subscribe_ttl)
          .with(kind_of(SWIG::TYPE_p_pn_messenger_t),
                "#{test_service_uri}/private:topic",
                0)
          .and_return Qpid::Proton::Error::NONE
        @client.subscribe('topic', share: nil)
      end

      it 'completes if passed nil options' do
        expect(Cproton).to receive(:pn_messenger_subscribe_ttl)
          .with(kind_of(SWIG::TYPE_p_pn_messenger_t),
                "#{test_service_uri}/private:topic",
                0)
          .and_return Qpid::Proton::Error::NONE
        @client.subscribe('topic', nil)
      end

      it 'completes if passed empty options' do
        expect(Cproton).to receive(:pn_messenger_subscribe_ttl)
          .with(kind_of(SWIG::TYPE_p_pn_messenger_t),
                "#{test_service_uri}/private:topic",
                0)
          .and_return Qpid::Proton::Error::NONE
        @client.subscribe('topic', {})
      end

      it 'uses default value for qos (at-most-once) if not set' do
        expect(Mqlight::Destination).to receive(:new)
          .with(kind_of(Mqlight::Service), 'topic', {})
          .and_call_original
        @client.subscribe('topic')
      end

      it 'uses supplied value for qos (at-most-once) if set to 0' do
        expect(Mqlight::Destination).to receive(:new)
          .with(kind_of(Mqlight::Service), 'topic', hash_including(qos: 0))
          .and_call_original
        @client.subscribe('topic', qos: 0)
      end

      it 'uses supplied value for qos (at-least-once) if set to 1' do
        expect(Mqlight::Destination).to receive(:new)
          .with(kind_of(Mqlight::Service), 'topic', hash_including(qos: 1))
          .and_call_original
        @client.subscribe('topic', qos: 1)
      end

      it 'passes supplied options directly to the destination' do
        expect(Mqlight::Destination).to receive(:new)
          .with(kind_of(Mqlight::Service), 'topic', hash_including(credit: 100))
          .and_call_original
        @client.subscribe('topic', credit: 100)
      end

      it 'reacts appropriately if auto_confirm is set to true and QoS = 1' do
        expect(Mqlight::Destination).to receive(:new)
          .with(kind_of(Mqlight::Service), 'topic', hash_including(auto_confirm: true,
                                                          qos: 1))
          .and_call_original
        @client.subscribe('topic', auto_confirm: true, qos: 1)
      end

      it 'reacts appropriately if auto_confirm is set to false and QoS = 1' do
        expect(Mqlight::Destination).to receive(:new)
          .with(kind_of(Mqlight::Service), 'topic', hash_including(auto_confirm: false,
                                                          qos: 1))
          .and_call_original
        @client.subscribe('topic', auto_confirm: false, qos: 1)
      end

      it 'reacts appropriately if not auto_confirm is present but QoS = 1' do
        expect(Mqlight::Destination).to receive(:new)
          .with(kind_of(Mqlight::Service), 'topic', hash_including(qos: 1))
          .and_call_original
        @client.subscribe('topic', qos: 1)
      end
    end
  end

  describe '#receive' do
    before(:each) do
      @client = Mqlight::BlockingClient.new(test_service_uri)
      calls = 0
      allow(Cproton).to receive(:pn_messenger_get_link) do
        calls += 1
        calls <= 1 ? nil : (SWIG::TYPE_p_pn_link_t)
      end
    end

    after(:each) do
      @client.stop if @client
    end

    context 'when stopped' do
      it 'raises a StoppedError' do
        @client.stop
        expect do
          @client.receive('topic')
        end.to raise_error(Mqlight::StoppedError)
      end
    end

    context 'when started' do
      it 'fails if passed no arguments' do
        expect { @client.receive }.to raise_error(ArgumentError)
      end

      it 'fails if passed a numeric topic_pattern' do
        expect { @client.receive(1) }.to raise_error(ArgumentError)
      end

      it 'fails if passed a boolean topic_pattern' do
        expect { @client.receive(true) }.to raise_error(ArgumentError)
        expect { @client.receive(false) }.to raise_error(ArgumentError)
      end

      it 'fails if passed a nil topic_pattern' do
        expect { @client.receive(nil) }.to raise_error(ArgumentError)
      end

      it 'fails if passed an array as a topic_pattern' do
        expect { @client.receive([]) }.to raise_error(ArgumentError)
      end

      it 'fails if passed an hash as a topic_pattern' do
        expect { @client.receive({}) }.to raise_error(ArgumentError)
      end

      it 'completes if passed a valid topic_pattern' do
        expect(Cproton).to receive(:pn_messenger_subscribe_ttl)
          .with(kind_of(SWIG::TYPE_p_pn_messenger_t),
                "#{test_service_uri}/private:topic",
                0)
          .and_return Qpid::Proton::Error::NONE
        @client.subscribe('topic')
      end

      it 'fails if options is boolean' do
        expect do
          @client.receive('topic', true)
        end.to raise_error(ArgumentError)
        expect do
          @client.receive('topic', false)
        end.to raise_error(ArgumentError)
      end

      it 'fails if options is an array' do
        expect do
          @client.receive('topic', [])
        end.to raise_error(ArgumentError)
      end

      it 'fails if options is an string' do
        expect do
          @client.receive('topic', 'string')
        end.to raise_error(ArgumentError)
      end

      it 'fails if options is an integer' do
        expect do
          @client.receive('topic', 1)
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed a boolean timeout' do
        expect do
          @client.receive('topic', timeout: true)
        end.to raise_error(ArgumentError)
        expect do
          @client.receive('topic', timeout: false)
        end.to raise_error(ArgumentError)
      end

      it 'fails if passed an array as a timeout' do
        expect { @client.receive('topic', timeout: []) }
          .to raise_error(ArgumentError)
      end

      it 'fails if passed a hash as a timeout' do
        expect { @client.receive('topic', timeout: {}) }
          .to raise_error(ArgumentError)
      end

      it 'fails if passed out of range timeout' do
        expect { @client.receive('topic', timeout: -1) }
          .to raise_error(RangeError)
      end
    end

    it 'on missing destination' do
      expect do
        @client.receive('missing_destination')
      end.to raise_error(Mqlight::UnsubscribedError)
    end

    it 'on successful no message' do
      allow(Cproton).to receive(:pn_link_credit) do
        1
      end
      allow(Cproton).to receive(:pn_link_drain) .and_return (SWIG::TYPE_p_pn_link_t)
      allow(Cproton).to receive(:pn_link_draining) .and_return nil

      @client.subscribe('address001')
      expect do
        @client.receive('address001', {:timeout=>1})
      end.not_to raise_error
    end
  end

  describe '#state' do
    before(:each) do
      @client = Mqlight::BlockingClient.new(test_service_uri)
    end

    after(:each) do
      @client.stop if @client
    end

    context 'when stopped' do
      it 'returns stopped' do
        @client.stop
        expect(@client.state).to be :stopped
      end
    end

    context 'when started' do
      it 'returns started' do
        expect(@client.state).to be :started
      end
    end
  end

  describe '#service' do
    before(:each) do
      @client = Mqlight::BlockingClient.new(test_service_uri)
    end

    after(:each) do
      @client.stop if @client
    end

    context 'when stopped' do
      it 'returns nil' do
        @client.stop
        expect(@client.service).to be nil
      end
    end

    context 'when started' do
      it 'returns a string' do
        expect(@client.service).to eql("amqp://localhost:5672")
      end
    end
  end

  describe '#started?' do
    before(:each) do
      @client = Mqlight::BlockingClient.new(test_service_uri)
    end

    after(:each) do
      @client.stop if @client
    end

    context 'when stopped' do
      it 'returns false' do
        @client.stop
        expect(@client.started?).to be false
      end
    end

    context 'when started' do
      it 'returns true' do
        expect(@client.started?).to be true
      end
    end
  end

  describe '#stopped?' do
    before(:each) do
      @client = Mqlight::BlockingClient.new(test_service_uri)
    end

    after(:each) do
      @client.stop if @client
    end

    context 'when stopped' do
      it 'returns true' do
        @client.stop
        expect(@client.stopped?).to be true
      end
    end

    context 'when started' do
      it 'returns false' do
        expect(@client.stopped?).to be false
      end
    end
  end

  describe '#to_s' do
    it 'returns a string' do
      client = Mqlight::BlockingClient.new(test_service_uri)
      expect(client.to_s).to be_kind_of(String)
    end

    it "contains the client's id" do
      client = Mqlight::BlockingClient.new(test_service_uri, id: 'foo')
      expect(client.to_s).to include('foo')
    end
  end

  describe '#unsubscribe' do
    before(:each) do
      @client = Mqlight::BlockingClient.new(test_service_uri)
      calls = 0
      allow(Cproton).to receive(:pn_messenger_get_link) do
        calls += 1
        calls <= 1 ? nil : (SWIG::TYPE_p_pn_link_t)
      end
      @client.subscribe('valid_topic')
      calls = 0
      @client.subscribe('valid_topic', share: 'valid_share')
      calls = 0
    end

    after(:each) do
      @client.stop if @client
    end

    context 'when stopped' do
      it 'raises a StoppedError' do
        @client.stop
        expect do
          @client.unsubscribe('valid_topic')
        end.to raise_error(Mqlight::StoppedError)
      end
    end

    context 'when started' do
      it 'fails if passed no arguments' do
        expect { @client.unsubscribe }.to raise_error(ArgumentError)
      end

      it 'fails if passed non-string topic_pattern' do
        [1, true, false, nil, [], {}].each do |x|
          expect { @client.unsubscribe(x) }.to raise_error(ArgumentError)
        end
      end

      it 'completes if passed a subscribed topic_pattern' do
        expect(Cproton).to receive(:pn_messenger_get_link)
          .with(kind_of(SWIG::TYPE_p_pn_messenger_t),
                "#{test_service_uri}/private:valid_topic",
                false)
          .and_return(SWIG::TYPE_p_pn_link_t)
        expect(Cproton).to receive(:pn_link_close).with(anything)
        @client.unsubscribe('valid_topic')
      end

      it 'removes the subscription so that receive fails' do
        allow(Cproton).to receive(:pn_messenger_get_link).and_return(SWIG::TYPE_p_pn_link_t)
        @client.unsubscribe('valid_topic')
        expect do
          @client.receive('valid_topic')
        end.to raise_error(Mqlight::UnsubscribedError)
      end

      it 'fails if passed an unsubscribed topic_pattern' do
        expect do
          @client.unsubscribe('not_a_valid_topic')
        end.to raise_error(Mqlight::UnsubscribedError)
      end

      it 'completes if passed a subscribed topic_pattern and share' do
        expect(Cproton).to receive(:pn_messenger_get_link)
          .with(kind_of(SWIG::TYPE_p_pn_messenger_t),
                "#{test_service_uri}/share:valid_share:valid_topic",
                false)
          .and_return(SWIG::TYPE_p_pn_link_t)
        expect(Cproton).to receive(:pn_link_close).with(anything)
        @client.unsubscribe('valid_topic', share: 'valid_share')
      end

      it 'fails if passed a subscribed topic_pattern and unsubscribed share' do
        expect do
          @client.unsubscribe('topic', share: 'unsub_share')
        end.to raise_error(Mqlight::UnsubscribedError)
      end

      it 'fails if passed a unsubscribed topic_pattern and subscribed share' do
        expect do
          @client.unsubscribe('unsub_topic', share: 'valid_share')
        end.to raise_error(Mqlight::UnsubscribedError)
      end

      it 'fails if passed an unsubscribed share with colon' do
        expect do
          @client.unsubscribe('topic', share: 'With:Colon')
        end.to raise_error(ArgumentError)
      end
    end
  end

  # Private methods

  describe '#validate_service_list' do
    before(:each) do
      @client = Mqlight::BlockingClient.new(test_service_uri)
    end

    it 'fails if non amqp urls are in the service_list' do
      @client.instance_variable_set(:@service_list, [URI('ftp://localhost:5672')])
      expect do
        @client.__send__(:validate_service_list)
      end.to raise_error(ArgumentError)
    end

    it 'fails if non url strings are in the service_list' do
      @client.instance_variable_set(:@service_list, [URI('blah://blah')])
      expect do
        @client.__send__(:validate_service_list)
      end.to raise_error(ArgumentError)
    end

    it 'fails if valid and invalid amqp urls are in the service_list' do
      @client.instance_variable_set(:@service_list, [URI(test_service_uri),
                                                     URI('blah://blah')])
      expect do
        @client.__send__(:validate_service_list)
      end.to raise_error(ArgumentError)
    end

    it 'completes if only valid amqp urls are in the service_list' do
      @client.instance_variable_set(:@service_list, [URI(test_service_uri)])
      expect do
        @client.__send__(:validate_service_list)
      end.not_to raise_error
    end

    it 'completes if auth is specified but service url do not specify auth' do
      @client.instance_variable_set(:@user, 'user')
      @client.instance_variable_set(:@password, 'pass')
      @client.instance_variable_set(:@service_list, [URI(test_service_uri)])
      expect do
        @client.__send__(:validate_service_list)
      end.not_to raise_error
    end

    it 'completes if service url specifies auth but user does not' do
      @client.instance_variable_set(:@service_list,
                                    [URI('amqp://user:pass@localhost:5672')])
      expect do
        @client.__send__(:validate_service_list)
      end.not_to raise_error
    end

    it 'fails if service url auth specifies user but not password' do
      @client.instance_variable_set(:@service_list,
                                    [URI('amqp://user@localhost:5672')])
      expect do
        @client.__send__(:validate_service_list)
      end.to raise_error(ArgumentError)
    end

    it 'fails if service url auth does not match user specified auth' do
      @client.instance_variable_set(:@user, 'foo')
      @client.instance_variable_set(:@password, 'bar')
      @client.instance_variable_set(:@service_list,
                                    [URI('amqp://user:pass@localhost:5672')])
      expect do
        @client.__send__(:validate_service_list)
      end.to raise_error(ArgumentError)
    end

    it 'completes if service url auth matches user specified auth' do
      @client.instance_variable_set(:@user, 'user')
      @client.instance_variable_set(:@password, 'pass')
      @client.instance_variable_set(:@service_list,
                                    [URI('amqp://user:pass@localhost:5672')])
      expect do
        @client.__send__(:validate_service_list)
      end.not_to raise_error
    end
  end

end
