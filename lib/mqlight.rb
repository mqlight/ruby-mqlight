# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/lib/mqlight.rb
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

require 'date'
require_relative 'cproton'

require_relative 'core/exceptions'
require_relative 'core/message'
require_relative 'types/described'
require_relative 'types/hash'
require_relative 'types/strings'
require_relative 'util/error_handler'
require_relative 'codec/data'
require_relative 'codec/mapping'

require_relative 'mqlight/version'
require_relative 'mqlight/logging'
require_relative 'mqlight/blocking_client'
require_relative 'mqlight/exceptions'
require_relative 'mqlight/destination'
require_relative 'mqlight/delivery'
require_relative 'mqlight/util'
require_relative 'mqlight/thread_vars'
require_relative 'mqlight/command'
require_relative 'mqlight/connection'
require_relative 'mqlight/proton_container'

#
module Mqlight
  QOS_AT_MOST_ONCE = 0
  QOS_AT_LEAST_ONCE = 1
end
