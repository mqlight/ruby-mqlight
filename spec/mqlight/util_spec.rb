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

    it 'makes a http request if passed an http uri string' do
      stub = stub_request(:get, 'http://example.com/blah')
        .to_return(body: "{\"service\":[\"amqp:\/\/example.com:5672\","\
                         "\"amqp:\/\/example.com:5673\"]}", status: 200)
      Mqlight::Util.get_service_urls('http://example.com/blah')
      expect(stub).to have_been_requested
    end

    it 'makes a https request if passed an https uri string' do
      stub = stub_request(:get, 'https://example.com/blah')
        .to_return(body: "{\"service\":[\"amqp:\/\/example.com:5672\","\
                         "\"amqp:\/\/example.com:5673\"]}", status: 200)
      Mqlight::Util.get_service_urls('https://example.com/blah')
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
end
