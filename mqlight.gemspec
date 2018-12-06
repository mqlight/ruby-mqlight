# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/mqlight.gemspec
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

lib = 'mqlight'
lib_path = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'mqlight/version'

Gem::Specification.new do |spec|
  spec.name          = lib
  spec.version       = Mqlight::VERSION
  spec.platform      = Gem::Platform::CURRENT
  spec.summary       = 'An MQ Light client.'
  spec.description   = 'Allows you to connect and send messages with the MQ ' \
                       'Light API.'

  spec.authors       = ['IBM MQ Light team']
  spec.email         = 'mqlight@uk.ibm.com'
  spec.homepage      = 'https://developer.ibm.com/messaging/mq-light/'
  spec.licenses      = ['Proprietary', 'Apache-2.0']

  spec.extensions    = 'ext/cproton/extconf.rb'
  spec.files         = %w(Gemfile LICENSE README.md Rakefile version.yaml)
  spec.files        += Dir.glob('{ext,include,lib,samples,spec}/**/*')
  spec.files        << "#{lib}.gemspec"
  spec.executables   = spec.files.grep(/^bin/) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(/^(test|spec|features)/)
  spec.require_paths = ['lib']

  # this gem is only supported with ruby 1.9.x or newer
  spec.required_ruby_version = '>= 1.9.1'

  spec.add_development_dependency 'bundler', '~> 1.0'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'rake-compiler', '~> 0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.61.0'
  spec.add_development_dependency 'ruby-prof', '~> 0'
  spec.add_development_dependency 'simplecov', '~> 0'
  spec.add_development_dependency 'webmock', '~> 1.0'
end
