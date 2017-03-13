# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/samples/recv.rb
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

require 'mqlight'
require 'optparse'
require 'securerandom'

%w(INT HUP QUIT).each do |signal|
  trap(signal) do
    $stderr.puts
    $stderr.puts "SIG#{signal} - Exiting.."
    exit! 1
  end
end
$stderr.sync = true
$stdout.sync = true

options = {}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: recv.rb [options]'
  opts.summary_width = 25
  opts.summary_indent = '  '
  opts.separator ''
  opts.separator 'Options:'

  opts.on('-h', '--help', 'show this help message and exit') do
    puts opts
    exit
  end

  options[:service] = 'amqp://localhost'
  opts.on('-sURL', '--service=URL', 'service to connect to, for example:',
          'amqp://user:password@host:5672 or',
          'amqps://host:5671 to use SSL/TLS',
          '(default: amqp://localhost)'
         ) do |url|
    options[:service] = url
  end

  options[:pattern] = 'public'
  opts.on('-tTOPICPATTERN', '--topic-pattern=TOPICPATTERN',
          'subscribe to receive messages matching TOPICPATTERN',
          '(default: public)'
         ) do |pattern|
    options[:pattern] = pattern
  end

  options[:id] = 'recv_' + SecureRandom.hex[0..6]
  opts.on('-iID', '--id=ID', 'the ID to use when connecting to MQ Light',
          '(default: recv_[0-9a-f]{7})'
         ) do |id|
    options[:id] = id
  end

  options[:share] = nil
  opts.on('-nNAME', '--share-name=NAME',
          'optionally, subscribe to a shared destination using',
          'NAME as the share name.'
         ) do |share|
    options[:share] = share
  end

  options[:ttl] = nil
  opts.on('--destination-ttl=NUM', Integer,
          'set destination time-to-live to NUM seconds'
         ) do |ttl|
    options[:ttl] = ttl
  end

  options[:delayConfirm] = nil
  opts.on('-d NUM','--delay=NUM', Integer,
          'delay confirming for NUM seconds each time a message is received.'
         ) do |delayConfirm|
    options[:delayConfirm] = delayConfirm
  end

  opts.on('--verbose', 'print additional information about each message',
          'received') do
    options[:verbose] = true
  end

  options[:file] = nil
  opts.on('-fFILE', '--file=STRING', String,
          'write the payload of the next message received to FILE',
          '(overwriting previous file contents) then end.'
         ) do |file|
    options[:file] = file
  end

  # Non keystore options
  options[:ssl_trust_certificate] = nil
  opts.on('-cFILE', '--trust-certificate=FILE', String,
          'use the certificate contained in FILE (in PEM format) to',
          'validate the identity of the server. The connection must',
          'be secured with SSL/TLS (e.g. the service URL must start',
          'with amqps://'
         ) do |ssl_trust_certificate|
    options[:ssl_trust_certificate] = ssl_trust_certificate
  end
  options[:ssl_client_certificate] = nil
  opts.on('--client-certificate=FILE', String,
          'use the certificate contained in FILE (in PEM format) to',
          'supply the identity of the client. The connection must',
          'be secured with SSL/TLS'
         ) do |ssl_client_certificate|
    options[:ssl_client_certificate] = ssl_client_certificate
  end
  options[:ssl_client_key] = nil
  opts.on('--client-key=FILE', String,
          'use the private key contained in FILE (in PEM format)',
          'for encrypting the specified client certificate'
         ) do |ssl_client_key|
    options[:ssl_client_key] = ssl_client_key
  end
  options[:ssl_client_key_passphrase] = nil
  opts.on('--client-key-passphrase=PASSPHRASE', String,
          'use PASSPHRASE to access the client private key'
         ) do |ssl_client_key_passphrase|
    options[:ssl_client_key_passphrase] = ssl_client_key_passphrase
  end
  
  # Key store
  options[:ssl_keystore] = nil
  opts.on('--keystore=FILE', String,
          'use key store contained in FILE (in PKCS#12 format) to',
          'supply the client certificate, private key and trust',
          'certificates.',
          'The Connection must be secured with SSL/TLS (e.g. the',
          'service URL must start with \'amqps://\').',
          'Option is mutually exclusive with the client-key,',
          'client-certificate and trust-certifcate options'
         ) do |ssl_keystore|
    options[:ssl_keystore] = ssl_keystore
  end
  options[:ssl_keystore_passphrase] = nil
  opts.on('--keystore-passphrase=PASSPHRASE', String,
          'use PASSPHRASE to access the key store'
         ) do |ssl_keystore_passphrase|
    options[:ssl_keystore_passphrase] = ssl_keystore_passphrase
  end
  options[:verify_name] = true
  opts.on('--no-verify-name',
          'specify to not additionally check the server\'s common name in',
          'the specified trust certificate matches the actual server\'s',
          'DNS name'
         ) do |verify_name|
    options[:verify_name] = false
  end
end

begin
  parser.parse!
rescue OptionParser::InvalidOption => e
  $stderr.puts "ERR: #{e}"
  $stderr.puts
  $stderr.puts parser.help
  exit 1
end

begin
  option_name_list = [:id,:ssl_trust_certificate,:ssl_client_certificate,
                      :ssl_client_key,:ssl_client_key_passphrase,
                      :ssl_keystore,:ssl_keystore_passphrase,:verify_name]
  opts = {}
  option_name_list.each do |name|
    opts[name] = options[name] unless options[name].nil?
  end
  client = Mqlight::BlockingClient.new(options[:service], opts)  {| state, reason |
    $stderr.puts "Connection to #{options[:service]} failed because #{reason}" \
      unless reason.nil?
  }
  exit 2 unless client.state == :started

  puts "Connected to #{client.service} using client-id #{client.id}"

  subscribe_opts = {qos: 0}
  subscribe_opts[:share] = options[:share] unless options[:share].nil?
  subscribe_opts[:ttl] = options[:ttl] * 1000 unless options[:ttl].nil?
  client.subscribe(options[:pattern], subscribe_opts)
  if options[:share]
    puts "Subscribed to share: #{options[:share]}, pattern: "\
         "#{options[:pattern]}"
  else
    puts "Subscribed to pattern: #{options[:pattern]}"
  end

  receive_opts = {}
  receive_opts[:share] = options[:share] unless options[:share].nil?
  i = 0
  loop do
    delivery = client.receive(options[:pattern], receive_opts)
    next unless delivery
    i += 1
    puts "# received message (#{i})" if options[:verbose]
    if options[:file]
      puts 'Writing message data to ' + options[:file]
      IO.binwrite(options[:file], delivery.data)
      delivery.confirm.call unless delivery.confirm.nil?
      exit 0
    else
      puts delivery.data
      puts delivery.to_s if options[:verbose]
      sleep options[:delayConfirm] unless options[:delayConfirm].nil?
      delivery.confirm.call unless delivery.confirm.nil?
    end
  end
rescue => e
  $stderr.puts '*** error ***'
  $stderr.puts "message: #{e.class.name.split('::').last}: #{e}"
  $stderr.puts 'Exiting.'
  exit 1
ensure
  client.stop if client
end
