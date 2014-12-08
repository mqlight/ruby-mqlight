#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

require 'mkmf'

INCLUDE_DIR = File.expand_path('../../include', RbConfig::CONFIG['srcdir'])
LIB_DIR = File.expand_path('../../lib', RbConfig::CONFIG['srcdir'])
RUBY_BINARY = File.join(RbConfig::CONFIG['bindir'],
                        RbConfig::CONFIG['ruby_install_name'])

def fail(*messages)
  $stderr.puts "+#{'-' * 76}+"
  messages.each do |msg|
    $stderr.puts "| #{msg}"
  end
  $stderr.puts "+#{'-' * 76}+"
end

# On MacOS we only support the x86_64 architecture and we don't include
# a universal libqpid-proton library. However, mkmf will attempt to build
# one if the Ruby binary is a universal binary
if RUBY_PLATFORM =~ /darwin/
  RUBY_ARCHS = `file #{RUBY_BINARY}`.strip!.scan(/executable (.+)/)
  fail 'ERROR: Gem is only supported on the x86_64 architecture for '\
       'Mac OS X' unless RUBY_ARCHS.include?(['x86_64'])
  fail 'ERROR: Gem cannot be built as a universal binary.',
       "export ARCHFLAGS='-arch x86_64' before re-running gem install" unless
         RUBY_ARCHS.length.eql?(1) || ENV['ARCHFLAGS'].eql?('-arch x86_64')
end

dir_config('qpid-proton', INCLUDE_DIR, LIB_DIR)

REQUIRED_HEADERS = [
  'proton/engine.h',
  'proton/message.h',
  'proton/sasl.h',
  'proton/driver.h',
  'proton/messenger.h'
]

REQUIRED_HEADERS.each do |header|
  abort "Missing header: #{header}" unless find_header header
end

# abort 'Missing library: crypto' unless find_library('crypto',
#                                                     'CRYPTO_add_lock')
# abort 'Missing library: ssl' unless find_library('ssl', 'SSL_accept')

# set the ruby version compiler flag
runtime_version = RUBY_VERSION.gsub(/\./, '')[0, 2]
$CFLAGS << " -DRUBY#{runtime_version}"

case RUBY_PLATFORM
when /darwin/i
  $LDFLAGS << " -Xlinker -rpath -Xlinker #{LIB_DIR}"
when /linux/i
  $LDFLAGS << " -Wl,-rpath,'$$ORIGIN' -Wl,-rpath,'#{LIB_DIR}'"
end

abort 'Missing library: qpid-proton' unless find_library('qpid-proton',
                                                         'pn_messenger_start')
create_makefile('cproton')
