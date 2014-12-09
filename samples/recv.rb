# @(#) MQMBID sn=mqkoa-L141209.14 su=_mOo3sH-nEeSyB8hgsFbOhg pn=appmsging/ruby/mqlight/samples/recv.rb
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

  opts.on('--verbose', 'print additional information about each message',
          'received') do
    options[:verbose] = true
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
  client = Mqlight::BlockingClient.new(options[:service], id: options[:id])
  puts "Connected to #{client.service} using client-id #{client.id}"

  client.subscribe(options[:pattern], share: options[:share], qos: 0)
  if options[:share]
    puts "Subscribed to share: #{options[:share]}, pattern: "\
         "#{options[:pattern]}"
  else
    puts "Subscribed to pattern: #{options[:pattern]}"
  end

  i = 0
  loop do
    delivery = client.receive(options[:pattern])
    next unless delivery
    i += 1
    puts "# received message (#{i})" if options[:verbose]
    puts delivery.data
    puts delivery.to_s if options[:verbose]
  end
rescue => e
  $stderr.puts '*** error ***'
  $stderr.puts "message: #{e.class.name.split('::').last}: #{e}"
  $stderr.puts 'Exiting.'
  exit 1
ensure
  client.stop if client
end
