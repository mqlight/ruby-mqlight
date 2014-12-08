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

require 'date'
require_relative 'cproton'

require_relative 'qpid_proton/described'
require_relative 'qpid_proton/strings'
require_relative 'qpid_proton/mapping'
require_relative 'qpid_proton/data'
require_relative 'qpid_proton/message'
require_relative 'qpid_proton/exceptions'
require_relative 'qpid_proton/exception_handling'

require_relative 'mqlight/version'
require_relative 'mqlight/blocking_client'
require_relative 'mqlight/exceptions'
require_relative 'mqlight/destination'
require_relative 'mqlight/delivery'
require_relative 'mqlight/util'

#
module Mqlight
  QOS_AT_MOST_ONCE = 0
  QOS_AT_LEAST_ONCE = 1
end
