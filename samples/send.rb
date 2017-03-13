# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/samples/send.rb
#
# <copyright
# notice="lm-source-program"
# pids="5725-P60"
# years="2013,2015"
# crc="3568777996" >
# Licensed Materials - Property of IBM
#
# 5725-P60
#
# (C) Copyright IBM Corp. 2013, 2015
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
  opts.banner = 'Usage: send.rb [options] <msg_1> ... <msg_n>'
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

  options[:topic] = 'public'
  opts.on('-tTOPIC', '--topic=TOPIC', 'sends messages to topic TOPIC',
          '(default: public)'
         ) do |topic|
    options[:topic] = topic
  end

  options[:id] = 'send_' + SecureRandom.hex[0..6]
  opts.on('-iID', '--id=ID', 'the ID to use when connecting to MQ Light',
          '(default: send_[0-9a-f]{7})'
         ) do |id|
    options[:id] = id
  end

  options[:delay] = 0
  opts.on('-dNUM', '--delay=NUM', Float,
          'add NUM seconds delay between each request'
         ) do |num|
    options[:delay] = num
  end

  options[:repeat] = 1
  opts.on('-rNUM', '--repeat=NUM', Float,
          'send messages NUM times, default is 1, if',
          'NUM <= 0 then repeat forever'
         ) do |num|
    options[:repeat] = num
  end

  options[:ttl] = nil
  opts.on('--message-ttl=NUM', Integer,
          'set message time-to-live to NUM seconds'
         ) do |ttl|
    options[:ttl] = ttl
  end

  options[:sequence] = false
  opts.on('--sequence', nil, 'prefix a sequence number to the message ',
                             'payload (ignored for binary messages)'
         ) do |sequence|
    options[:sequence] = true
  end

  options[:file] = nil
  opts.on('-fFILE', '--file=FILE', String,
          'send FILE as binary data.'
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
  remain = parser.parse!
rescue OptionParser::InvalidOption => e
  $stderr.puts "ERR: #{e}"
  $stderr.puts
  $stderr.puts parser.help
  exit 1
end

messages = ['Hello World!']
messages = remain unless remain.empty?
messages = [IO.binread(options[:file])] unless options[:file].nil?

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
  puts "Sending to: #{options[:topic]}"

  opts = {}
  opts[:ttl] = options[:ttl] * 1000 unless options[:ttl].nil?
  opts[:qos] = 1 # At least once

  # Forever loop
  if options[:repeat] == 0
    sequence_index = 1
    loop do
      messages.each_with_index do |msg, index|
        msg = sequence_index.to_s+':'+msg \
          if options[:sequence] && options[:file].nil?
        client.send(options[:topic], msg, opts)
        puts msg
        sleep(options[:delay]) unless index == (messages.length - 1)
      end
      sleep(options[:delay])
        sequence_index += 1
    end
  end
  # Multiple & single loop
  (1..options[:repeat]).each do |sequence_index|
    sleep(options[:delay]) unless sequence_index == 1
    messages.each_with_index do |msg, index|
      msg = sequence_index.to_s+':'+msg \
        if options[:sequence] && options[:file].nil?
      client.send(options[:topic], msg, opts)
      puts msg
      sleep(options[:delay]) unless index == (messages.length - 1)
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
