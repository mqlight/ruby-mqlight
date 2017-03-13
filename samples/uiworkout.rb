# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/samples/uiworkout.rb
#
# <copyright
# notice="lm-source-program"
# pids="5725-P60"
# years="2015"
# crc="3568777996" >
# Licensed Materials - Property of IBM
#
# 5725-P60
#
# (C) Copyright IBM Corp. 2015
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
# </copyright>

require 'mqlight'
require 'optparse'
require 'securerandom'
require 'json'
require 'thread'

%w(INT HUP QUIT).each do |signal|
  trap(signal) do
    $stderr.print "\n"
    $stderr.print "SIG#{signal} - Exiting..\n"
    exit! 1
  end
end
$stderr.sync = true
$stdout.sync = true

# The number of clients that will connect to any given shared destination
CLIENTS_PER_SHARED_DESTINATION = 2

# The topics to subscribe to for shared destinations
SHARED_TOPICS = ['shared1', 'shared/shared2']

# The topics to subscribe to for private destinations
PRIVATE_TOPICS = [
  'private1',
  'private/private2',
  'private/private3',
  'private4'
]

# The command line options, populated by the parser
options = {}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: uiworkout.rb [options]'
  opts.summary_width = 25
  opts.summary_indent = '  '
  opts.separator ''
  opts.separator 'Options:'

  opts.on('-h', '--help', 'show this help message and exit') do
    puts opts
    exit
  end

  options[:service] = nil
  opts.on('-sURL', '--service=URL', 'service to connect to, for example:',
          'amqp://user:password@host:5672 or',
          'amqps://host:5671 to use SSL/TLS',
          '(default: amqp://localhost)'
         ) do |url|
    options[:service] = url
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

# Performs the MQ Light UI workout operation for a single client.
class UIWorkout
  # All topics. An entry is picked at random each time a message is sent
  ALL_TOPICS = SHARED_TOPICS + PRIVATE_TOPICS

  # Text used to compose message bodies. A random number of words are picked.
  LOREM_IPSUM = 'Lorem ipsum dolor sit amet, consectetur adipisicing elit, '\
                'sed do eiusmod tempor incididunt ut labore et dolore '\
                'magna aliqua. Ut enim ad minim veniam, quis nostrud '\
                'exercitation ullamco laboris nisi ut aliquip ex ea '\
                'commodo consequat. Duis aute irure dolor in reprehenderit '\
                'in voluptate velit esse cillum dolore eu fugiat nulla '\
                'pariatur. Excepteur sint occaecat cupidatat non proident, '\
                'sunt in culpa qui officia deserunt mollit anim id est '\
                'laborum.'

  # Build an array of word ending offsets for lorem_ipsum
  LOREM_IPSUM_WORDS = []
  i = 0
  loop do
    i = LOREM_IPSUM.index(' ', i)
    if i.nil?
      LOREM_IPSUM_WORDS.push(LOREM_IPSUM.length)
      break
    else
      LOREM_IPSUM_WORDS.push(i)
      i += 1
    end
  end

  # A counter of all messages sent by the application
  @@mutex = Mutex.new
  @@message_count = 0
  @@first = true

  # Sets up the MQ Light client service and options for a new instance
  def initialize(options, topic, share = nil)
    @topic = topic
    @share = share
    
    # Generate a list of possible SSL arguments
    ssl_option_name_list = [:ssl_trust_certificate,:ssl_client_certificate,
                        :ssl_client_key,:ssl_client_key_passphrase,
                        :ssl_keystore,:ssl_keystore_passphrase,:verify_name]
    @ssl_opts = {}
    ssl_option_name_list.each do |name|
      @ssl_opts[name] = options[name] unless options[name].nil?
    end
    
    if !options[:service].nil?
      @service = options[:service]
    else
      unless bluemix_service_lookup?(false)
        @service = @ssl_opts.length == 0 ? 'amqp://localhost' :
                                          'amqps://localhost'
      end
    end
  end

  # Creates a MQ Light client. The client is used to
  # periodically publish a message to a randomly chosen topic.
  def run_send
    send_opts = @ssl_opts
    send_opts [:id] = "CLIENT_#{SecureRandom.hex[0..6]}"
    @client_send = Mqlight::BlockingClient.new(
      @service,
      send_opts) {| state, reason |
      puts "Connection to #{@service} failed because #{reason}" \
        unless reason.nil?
    }
    # Wait for the connection to complete
    until @client_send.started? 
      return if @client_receive.retrying?
      sleep(0.2)
    end
    print "Send connected to #{@client_send.service } using id " \
      "#{@client_send.id}\n"

    # Loop sending messages to randomly picked topics. Delay for a small
    # (random) amount of time, each time around.
    @@mutex.synchronize do
      print "Sending messages\n" if @@first
      @@first = false
    end
    loop do
      delay = SecureRandom.random_number * 20
      index = SecureRandom.random_number(ALL_TOPICS.length)
      send_topic = ALL_TOPICS[index]
      start_idx = SecureRandom.random_number(LOREM_IPSUM_WORDS.length - 15)
      end_idx = start_idx + 5 + SecureRandom.random_number(10)
      message = LOREM_IPSUM[LOREM_IPSUM_WORDS[start_idx]..
                            LOREM_IPSUM_WORDS[end_idx]]
      sleep(delay)
      @client_send.send(send_topic, message, {})

      @@mutex.synchronize do
        @@message_count += 1
        print "Sent #{@@message_count} messages\n" \
          if @@message_count % 10 == 0
      end
    end
  rescue => e
    $stderr.print "*** error ***\n"
    $stderr.print "Send message: #{e.class.name.split('::').last}: #{e}\n"
    $stderr.print "Send exiting.\n"
    exit 1
  ensure
    stop
  end

  # Creates a MQ Light client. The client will subscribe to @topic.  If the
  # @share variable is nil the destination will be private to the client. If
  # the @share variable is not nil, it will be used as the share name for
  # subscribing to a shared destination.
  def run_receive
    recv_opts = @ssl_opts
    recv_opts[:id] = "CLIENT_#{SecureRandom.hex[0..6]}"
    @client_receive = Mqlight::BlockingClient.new(
      @service,
      recv_opts) {| state, reason |
       puts "Connection to #{@service} failed because #{reason}" \
         unless reason.nil?
     }
    # Wait for the connection to complete
    until @client_receive.started?
      return if @client_receive.retrying?
      sleep(0.2)
    end
    print "Receive connected to #{@client_receive.service } using id " \
      "#{@client_receive.id}\n"

    subscribe_opts = { qos: 0 }
    subscribe_opts[:share] = @share unless @share.nil?
    @client_receive.subscribe(@topic, subscribe_opts)
    print "Receiving messages from topic pattern: #{@topic}"
    print "with share '#{@share}'" unless @share.nil?
    print "\n"

    until @client_receive.stopped?
      msg = @client_receive.receive(@topic, subscribe_opts)
      unless msg.nil?
        print "Received message from Topic:#{msg.topic_pattern}"
        print " with share:#{@share}" unless @share.nil?
        print "\n"
      end
    end
  rescue => e
    $stderr.print "*** error ***\n"
    $stderr.print "Receive message: #{e.class.name.split('::').last}: #{e}\n"
    $stderr.print "Receive exiting.\n"
    exit 1
  end

  # Stops the MQ Light client when started
  def stop
    @client_send.stop unless @client_send.nil?
    @client_receive.stop unless @client_receive.nil?
  end

  private

  # Checks to see if the application is running in IBM Bluemix. If it is, tries
  # to retrieve connection details from the environment and populates the
  # options object passed as an argument.
  def bluemix_service_lookup?(verbose)
    result = false
    if !ENV['VCAP_SERVICES'].nil?
      print "VCAP_SERVICES variable present in environment\n" if verbose
      services = JSON.parse(ENV[VCAP_SERVICES])
      if !services.mqlight.nil?
        mqlight_services = services[:mqlight]
        mqlight = mqlight_services[0]
        credentials = mqlight[:credentials]
        @opts[:user] = credentials[:username]
        @opts[:password] = credentials[:password]
        @service = credentials[:connectionLookupURI]
        if verbose
          print "Username: #{@opts[:user]}\n"
          print "Password: ****\n"
          print "LookupURI: #{@service}\n"
        end
      else
        fail StandardError, 'Running in IBM Bluemix but not bound to an '\
                          "instance of the 'mqlight' service."
      end
      result = true
    else
      print "VCAP_SERVICES variable not present in environment\n" if verbose
    end
    result
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
  clients = []
  threads = []

  # Create clients that subscribe to a shared topic, and send messages
  # randomly to any of the topics.
  i = SHARED_TOPICS.length - 1
  loop do
    j = 0
    loop do
      share_name = 'share' + (i + 1).to_s
      clients.push(UIWorkout.new(options, SHARED_TOPICS[i], share_name))
      j += 1
      break unless j < CLIENTS_PER_SHARED_DESTINATION
    end
    i -= 1
    break unless i >= 0
  end

  # Create clients that subscribe to private topics, and send messages
  # randomly to any of the topics.
  i = PRIVATE_TOPICS.length - 1
  loop do
    clients.push(UIWorkout.new(options, PRIVATE_TOPICS[i]))
    i -= 1
    break unless i >= 0
  end

  # Start the clients
  clients.each { |c| threads.push(Thread.new { c.run_receive }) }
  clients.each { |c| threads.push(Thread.new { c.run_send }) }

  # Wait for all client threads to end
  threads.each(&:join)

rescue => e
  $stderr.print "*** error ***\n"
  $stderr.print "message: #{e.class.name.split('::').last}: #{e}\n"
  $stderr.print "Exiting.\n"
  exit 1
ensure
  clients.each(&:stop)
end
