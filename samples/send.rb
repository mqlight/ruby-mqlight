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

begin
  client = Mqlight::BlockingClient.new(options[:service], id: options[:id])
  puts "Connected to #{client.service} using client-id #{client.id}"
  puts "Sending to: #{options[:topic]}"

  loop do
    messages.each_with_index do |msg, index|
      client.send(options[:topic], msg, {})
      puts msg
      sleep(options[:delay]) unless index == (messages.length - 1)
    end
    break if options[:repeat] == 1
    options[:repeat] -= 1 if options[:repeat] > 1
    sleep(options[:delay])
  end
rescue => e
  $stderr.puts '*** error ***'
  $stderr.puts "message: #{e.class.name.split('::').last}: #{e}"
  $stderr.puts 'Exiting.'
  exit 1
ensure
  client.stop if client
end
