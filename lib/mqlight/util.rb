# @(#) MQMBID sn=mqkoa-L141209.14 su=_mOo3sH-nEeSyB8hgsFbOhg pn=appmsging/ruby/mqlight/lib/mqlight/util.rb
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

require 'uri'
require 'net/http'
require 'json'

module Mqlight
  #
  class Util
    #
    def self.get_service_urls(lookup_uri)
      fail ArgumentError, 'lookup_uri must be a String or URI' unless
        (lookup_uri.is_a?(String)) || (lookup_uri.is_a?(URI))
      res = http_get(URI(lookup_uri))
      fail Mqlight::NetworkError, "http request to #{lookup_uri} failed "\
        "with status code of #{res.code}" unless res.code == '200'
      JSON.parse(res.body)['service']
    end

    #
    def self.validate_uri_scheme(lookup_uri)
      fail ArgumentError, 'lookup_uri must be a http or https URI.' unless
        (lookup_uri.scheme.eql? 'http') || (lookup_uri.scheme.eql? 'https')
    end

    #
    def self.http_get(lookup_uri)
      validate_uri_scheme(lookup_uri)
      Net::HTTP.start(lookup_uri.host, lookup_uri.port,
                      use_ssl: (lookup_uri.scheme == 'https')) do |http|
        path = lookup_uri.path
        path += '?' + lookup_uri.query if lookup_uri.query
        get = Net::HTTP::Get.new(path)
        http.request(get)
      end
    end
  end
end
