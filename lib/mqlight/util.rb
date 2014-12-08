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

require 'uri'
require 'net/http'
require 'json'

module Mqlight
  #
  class Util
    #
    def self.get_service_urls(lookup_uri)
      fail ArgumentError, 'lookup_uri must be a String or URI' unless
        lookup_uri.is_a?(String) || lookup_uri.is_a?(URI)
      lookup_uri = URI(lookup_uri)
      fail ArgumentError, 'lookup_uri must be a http or https URI.' unless
        (lookup_uri.scheme.eql? 'http') || (lookup_uri.scheme.eql? 'https')
      res = Net::HTTP.start(lookup_uri.host, lookup_uri.port,
                            use_ssl: (lookup_uri.scheme == 'https')) do |http|
        http.request(Net::HTTP::Get.new(lookup_uri.path))
      end
      fail Mqlight::NetworkError, "http request to #{lookup_uri} failed "\
                                  "with status code of #{res.code}" unless
        res.code == '200'
      JSON.parse(res.body)['service']
    end
  end
end
