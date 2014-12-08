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

require 'thread'
require 'securerandom'
require 'uri'
require 'timeout'

module Mqlight
  #
  # The MQ Light Client.  This can be used to exchange messages between with
  # the MQ Light server.  This version of the client blocks the calling thread
  # while carrying out messaging operations. The methods provided by this
  # client object are thread safe such that multiple threads can safely
  # interact with the same instance of the client.  Individual methods of the
  # client are protected such that they can only be accessed by a single thread
  # at any given time.
  #
  # @note this class uses timeouts in milliseconds with zero meaning: "don't
  #       wait at all" and nil meaning "wait forever - don't time out".
  class BlockingClient
    include Qpid::Proton::ExceptionHandling

    # @return [String] the client id, which can either be explicitly specified
    #         when the client is created or automatically generated.
    attr_reader :id

    # @return [Symbol] the current state of the client.  This will be one of:
    #         :starting, :started, :stopping, :stopped, :retrying, or :restarted
    attr_reader :state

    # Creates a new instance of the client.  The client will be created in
    # starting state. The constructor will make a connection attempt to the
    # server and report failures (such as "you are not authorized") as
    # exceptions.  This means that in the golden path case the constructor
    # will return an instance of the BlockingClient that is in started state.
    # A code block, yielded to by the constructor can be used to register a
    # listener that receives notifications when the associated client changes
    # state.

    # @param service [String] a String containing the URL for the service to
    #   connect to, or alternatively an Array containing a list of URLs to
    #   attempt to connect to in turn. User names and passwords may be embedded
    #   into the URL (e.g. amqp://user:pass@host).
    # @option options [String] :id a unique identifier for this client. A
    #   maximum of one instance of the client (as identified by the value
    #   of this property) can be connected the an MQ Light server at a given
    #   point in time. If another instance of the same client connects, then
    #   the previously connected instance will be disconnected. This is
    #   reported, to the first client, as a ReplacedError being emitted as an
    #   error event and the client transitioning into stopped state. If the id
    #   property is not a valid client identifier (e.g. it contains a colon,
    #   it is too long, or it contains some other forbidden character) then
    #   the function will throw an ArgumentError exception.
    # @option options [String] :user user name for authentication.
    #   Alternatively, the user name may be embedded in the URL passed via the
    #   service property. If you choose to specify a user name via this
    #   property and also embed a user name in the URL passed via the surface
    #   argument then all the user names must match otherwise an ArgumentError
    #   exception will be thrown. User names and passwords must be specified
    #   together (or not at all). If you specify just the user property but no
    #   password property an ArgumentError exception will be thrown.
    # @option options [String] :password password for authentication.
    #   Alternatively, user name may be embedded in the URL passed via the
    #   service property.
    # @option options [String] :ssl_trust_certificate SSL trust certificate
    #   to use when authentication is required for the MQ Light server. Only
    #   used when service specifies the amqps scheme.
    # @option options [Boolean] :sslVerifyName whether or not to additionally
    #   check the MQ Light server's common name in the certificate matches the
    #   actual server's DNS name. Only used when the sslTrustCertificate
    #   option is specified.  The default is true.
    #
    # @yield an optional block of code that is called into each time a
    #        transition occurs in the state machine underpinning the client.
    # @yieldparam state [Symbol] the state that the client has now transitioned
    #             into.  This will be one of: :starting, :started:, :stopping,
    #             :stopped, :retrying, :restarted.
    # @yieldparam reason [Exception, nil] an indication of why the client
    #             transitioned into this state.  An Exception is passed back
    #             when the client encounters an exception which causes it to
    #             transition into a new state.  A value of nil indicates that
    #             the client transitioned into this state either automatically
    #             or as a result of the user invoking the start or stop
    #             methods.
    #
    # @return [BlockingClient] the newly created instance of the client.
    # 
    # @raise [ArgumentError] if one of the arguments supplied to the method
    #   is not valid.
    # @raise [SecurityError] if, during the construction process of the
    #   client, the MQ Light server rejects the client's connection attempt
    #   for a security related reason.
    def initialize(service, options = {}, &state_callback)
      @id = options.fetch(:id, nil)
      @user = options.fetch(:user, nil)
      @password = options.fetch(:password, nil)

      # Validate id
      fail ArgumentError, 'Client identifier must be a String.' unless
        @id.is_a?(String) || @id.nil?

      set_defaults

      # Validate id some more
      fail ArgumentError, "Client identifier '#{@id}' is longer than the "\
        'maximum ID length of 48.' if @id.length > 48

      # currently client ids are restricted, reject any invalid ones
      invalid_client_id_pattern = /[^A-Za-z0-9%\/\._]+/
      invalid_client_id_pattern.match(@id) do |m|
        fail ArgumentError, "Client Identifier '#{@id}' contains invalid "\
          "char: #{m[0]}"
      end

      # Validate username and password
      fail ArgumentError, 'Both user and password properties must '\
                          'be specified together.' if
        (@user && !@password) || (!@user && @password)

      if @user && @password
        fail ArgumentError, 'Both user and password must be Strings.' unless
          (@user.is_a? String) && (@password.is_a? String)
      end

      # Validate service
      @service_list = []
      if service.is_a?(Array)
        @service_list = service
      elsif service.is_a?(String)
        begin
          @service_list << service if URI(service).scheme.eql?('amqp') ||
                                      URI(service).scheme.eql?('amqps')
          @service_lookup_uri = service if URI(service).scheme.eql?('http') ||
                                           URI(service).scheme.eql?('https')
        rescue
          @service_list = []
          @service_lookup_uri = nil
        end
      end

      fail ArgumentError, 'A valid service must be specified.' if
        @service_list.length == 0 && @service_lookup_uri.nil?

      @state_callback = state_callback

      # Setup queue for sharing with proton thread
      @proton_queue = Queue.new
      @proton_queue_mutex = Mutex.new
      @proton_queue_resource = ConditionVariable.new

      # Setup queue for running any user callbacks in
      @callback_queue = Queue.new

      # Setup queue for returning messages from proton thread
      @message_queue = Queue.new

      start
    end

    def self.finalize!(impl) # :nodoc:
      proc do
        Cproton.pn_messenger_free(impl)
      end
    end

    # Requests that the client transition into started state.  This method will
    # block the calling thread until the client has either:
    #  1. Attained started state (effectively being a no-op if the client is
    #     already in started state)
    #  2. Attained stopped state (most likely due to another thread calling the
    #     stop method before the client manages to attain started state).
    #
    # @return [BlockingClient] the instance of the client that the send method
    #   was invoked upon.  This allows for method chaining.
    #
    # @raise [StoppedError] if the client transitions into stopped state before
    #   attaining started state.
    def start
      return unless stopped?
      change_state(:starting)

      generate_service_list
      validate_service_list

      # Sort out authentication information
      if @user && @password
        auth = "#{URI.encode_www_form_component(@user)}:"\
               "#{URI.encode_www_form_component(@password)}"
      else
        auth = nil
      end

      # Try each service in turn
      @service_list.each do |service|

        service_url = URI(service)

        # Add default port for scheme unless one is specified already
        unless service_url.port
          service_url.port = (service_url.scheme == 'amqps') ? 5671 : 5672
        end

        if service_url.userinfo
          address = service_url
          pattern = service_url.clone
          pattern.userinfo = ''
        else
          pattern = service_url
        end

        unless address
          address = service_url.clone
          address.userinfo = auth
        end

        begin
          # Setup the proton messenger
          @messenger_impl = Cproton.pn_messenger(@id)
          ObjectSpace.define_finalizer(self,
                                       self.class.finalize!(@messenger_impl))
          Cproton.pn_messenger_set_flags(@messenger_impl,
                                         Cproton::PN_FLAGS_CHECK_ROUTES)
          Cproton.pn_messenger_set_incoming_window(@messenger_impl,
                                                   1024)
          Cproton.pn_messenger_set_outgoing_window(@messenger_impl,
                                                   1024)
          Cproton.pn_messenger_route(@messenger_impl,
                                     (pattern.to_s + '/*'),
                                     (address.to_s + '/$1'))
          # Try to start the messenger
          check_for_error(Cproton.pn_messenger_start(@messenger_impl))
          # Assign the service if we start successfully (without auth info)
          @service = "#{service_url.scheme}://#{service_url.host}:"\
            "#{service_url.port}"
          change_state(:started)
        rescue Qpid::Proton::ProtonError => e
          msg = e.to_s
          if /sasl /.match(msg) || /SSL /.match(msg)
            raise Mqlight::SecurityError, msg
          else
            raise Mqlight::NetworkError, msg
          end
        end

        break if started?
        change_state(:retrying)
      end

      fail Mqlight::NetworkError, 'Unable to connect to MQ Light' unless
        started?

      @proton_thread = Thread.new do
        Thread.current['name'] = 'proton_loop'
        proton_loop while started?

        # drain remaining proton_queue requests before Thread completes
        proton_loop until @proton_queue.empty?
      end

      @callback_thread = Thread.new do
        Thread.current['name'] = 'callback_thread'
        callback_loop while started?
      end

      self
    end

    # Requests that the client transition into stopped state. This method will
    # block the calling thread until the client has attained stopped state.
    # The client will attempt to flush any buffered messages (e.g. those
    # passed to the client via the send method), to the network, for a period
    # of time governed by the timeout option before completing its transition
    # to the stopped state.  The client will never have any messages buffered
    # to pass to the application (e.g. received from the server and pending
    # delivery to the user's application).
    #
    # @option options [nil, Numeric] :timeout the amount of time (in
    #         milliseconds) to wait to flush any outstanding messages to the
    #         network.  A value of zero indicates the client should stop
    #         immediately without attempting to flush messages.  A value of nil
    #         (the default) indicates the method will block until all messages
    #         are flushed.
    # @return [Boolean] true if client has flushed any buffered messages to the
    #         network before attaining the stopped state, or false otherwise.
    def stop
      return unless started?
      @proton_queue_mutex.synchronize do
        change_state(:stopped)
        @proton_queue_resource.broadcast
      end
      @proton_thread.join
      check_for_error(Cproton.pn_messenger_stop(@messenger_impl))
    end

    # Sends a message to the specified topic, blocking the calling thread while
    # the send operation takes place (or until the timeout value, as specified
    # via the timeout option is exceeded).
    #  * For QoS 0 messages the calling thread will block until the client is
    #    both successfully network connected and the message has been buffered
    #    by the client.  This method may or may not block until the data has
    #    been flushed to the underlying network, at the discretion of the
    #    client implementation which balances throughput against buffering
    #    large amounts of data.
    #  * For QoS 1 messages the calling thread will block until the client is
    #    both successfully network connected and has received confirmation
    #    from the server that the server has received a copy of the message.
    #
    # @param topic [String] the topic to which the message will be sent.
    # @param data [String] the data to send in the message payload.
    # @option options [Numeric] :qos The quality of service to use when
    #   sending the message. 0 is used to denote at most once (the default)
    #   and 1 is used for at least once. If a value which is not 0 and not 1
    #   is specified then this method will throw a RangeError exception.
    # @option options [nil, Numeric] :timeout the minimum amount
    #   of time (in milliseconds) that the client will attempt to send
    #   the message for.  If the client is not able to send the message
    #   after this period has elapsed then this method will raise
    #   TimeoutError. A value of zero is intepreted as timeout
    #   immediately.  A value of nil (the default) means wait
    #   indefinately.
    # @option options [Numeric] :ttl A time to live value for the message in
    #   milliseconds. MQ Light will endeavour to discard, without delivering,
    #   any copy of the message that has not been delivered within its time to
    #   live period. The default time to live is 604800000 milliseconds
    #   (7 days). The value supplied for this argument must be greater than
    #   zero and finite, otherwise a RangeError exception will be thrown when
    #   this method is called.
    #
    # @return [BlockingClient] the instance of the client that the send method
    #   was invoked upon.  This allows for method chaining.
    #
    # @raise ArgumentError if one of the arguments supplied to the method is
    #   not valid.
    # @raise TimeoutError if the amount of time taken to process the send
    #   request has exceeded the value specified by the timeout option. If
    #   the send operation is sending a QoS 0 message then the message will
    #   not have been sent. If a QoS 1 message is being sent then the message
    #   may have been sent to the server, but not as yet acknowledged by
    #   the server.
    # @raise StoppedError if the method is called while the client is in
    #   stopped state, or has transitioned into stopped state while the send
    #   operation was taking place.
    # @raise UnsupportedError if either ttl or QoS 1 is specified.
    def send(topic, data, options = {})
      fail Mqlight::StoppedError, 'Not started.' unless started?
      fail ArgumentError, 'topic must be a String' unless topic.is_a? String
      fail Mqlight::UnsupportedError, "#{data.class.name.split('::').last} "\
        'is not yet supported as a message data type' unless data.is_a? String

      if options.is_a? Hash
        qos = options.fetch(:qos, nil)
        ttl = options.fetch(:ttl, nil)
        timeout = options.fetch(:timeout, nil)
        
        fail Mqlight::UnsupportedError,
                      "ttl is not yet supported by this client" unless ttl.nil?
      else
        fail ArgumentError, 'options must be a Hash.' unless options.nil?
      end
      qos ||= QOS_AT_MOST_ONCE

      if qos == QOS_AT_LEAST_ONCE
        fail Mqlight::UnsupportedError,
             "qos=#{QOS_AT_LEAST_ONCE} is not yet supported by this client"
        # check_for_error(Cproton.pn_messenger_set_snd_settle_mode(
        #   @messenger_impl,
        #   Cproton::PN_SND_UNSETTLED))
      else
        check_for_error(Cproton.pn_messenger_set_snd_settle_mode(
                        @messenger_impl,
                        Cproton::PN_SND_SETTLED))
      end

      if timeout
        fail ArgumentError, 'timeout must be nil or a unsigned Integer' if
          (!timeout.is_a? Integer) || (timeout < 0)
        timeout /= 1000.0
      end

      # Setup the message
      msg = Qpid::Proton::Message.new

      # URI escape anything apart from path separators (/) and all known
      # unreserved characters
      msg.address = "#{@service}/"\
        "#{URI.encode(topic, Regexp.new("[^/#{URI::PATTERN::UNRESERVED}]"))}"
      msg.ttl = ttl if ttl
      msg.body = data
      msg.content_type = 'text/plain'

      # Send the message
      begin
        Timeout.timeout(timeout, Mqlight::TimeoutError) do
          msg.pre_encode
          @proton_queue_mutex.synchronize do
            @proton_queue.push(type: 'send', params: msg.impl)
            @proton_queue_resource.signal
            until @proton_queue.empty?
              @proton_queue_resource.wait(@proton_queue_mutex, timeout)
            end
            @proton_queue_resource.signal
          end
        end
      rescue StandardError => error
        raise error
      end
      self
    end

    # Subscribes to receive messages from a destination, identified by the
    # topic pattern argument. The receive(...) method can then be used to
    # retrieve messages, held at the server, for the destination.
    #
    # The client cannot be in stopped or stopping state when this method is
    # called, otherwise a StoppedError will be raised.  The client does not,
    # however, need to be network connected to the server at the point this
    # method will be called.  If the client is not network connected to the
    # server, when this method is called, then the method will return
    # immediately (e.g. it does not block until connected) and the subscription
    # will be made when the client is next connected to the server.
    #
    # @param topic_pattern [String] the topic pattern to subscribe to.  This
    #        identifies or creates a destination.
    # @option options [Boolean] :autoConfirm
    # @option options [Numeric] :qos
    # @option options [Numeric] :ttl (currently not supported).
    # @option options [String] :share
    # @raise StoppedError if the method is called while the client is in the
    #        stopped state.
    # @raise SubscribedError if the client is already subscribed to the
    #        destination.
    #
    # @note should the topic_pattern argument also accept an array of strings?
    #       this would allow multiple destinations to be subscribed to by
    #       one call.
    def subscribe(topic_pattern, options = {})
      fail Mqlight::StoppedError, 'Not started.' if stopped?
      destination = Mqlight::Destination.new(@service,
                                             topic_pattern,
                                             options)

      check_for_error(Cproton.pn_messenger_set_rcv_settle_mode(
                      @messenger_impl,
                      Cproton::PN_RCV_FIRST))

      @proton_queue_mutex.synchronize do
        @proton_queue.push(type: 'subscription', params: destination)
        @proton_queue_resource.signal
        until @proton_queue.empty?
          @proton_queue_resource.wait(@proton_queue_mutex)
          @proton_queue_resource.signal
        end
      end
      self
    end

    # Receive a message from one or more destinations, as identified by the
    # topic patterns used to subscribe to the destinations.
    # @param topic_patterns [Array<String>, String] one or more topic patterns,
    #        identifying the destinations to attempt to receive messages from.
    #        These destinations must previously have been subscribed to using
    #        the subscribe method.  This method will block the calling thread
    #        until at least one message is received from any of these
    #        destinations or the operation times out (see the timeout option).
    # @option options [nil, Numeric] :timeout the period of time
    #         (in milliseconds) to wait for a message to be received from at
    #         least one of the destinations. If no messages are received from
    #         any of the destinations within this time period, then an empty
    #         array is returned. A value of zero is interpreted as time out
    #         immediately.  A value of nil (the default) is intepreted as
    #         never timeout.
    # @return (Delivery, nil) either a delivery object - representing the
    #         message received or nil if no message was received (e.g. because
    #         the operation timed out).
    # @raise StoppedError if the client is in stopped or stopping state.  This
    #        can also occur because another thread calls the stop method while
    #        a thread is blocked inside this receive method.
    # @raise UnsubscribedError if one or more of the topic_patterns refers to a
    #        destination that the client not not currently subscribed to.  This
    #        can also occur because another thread calls the unsubscribe method
    #        while a thread is blocked inside this receive method.
    #
    # @example Receiving from a single topic:
    #   client.subscribe("/foo")
    #   delivery = receive("/foo", :timeout=>1000)  # wait up to a second
    #   unless delivery.empty? then
    #     puts delivery.data
    #   end
    #   client.unsubscribe("/foo")
    #
    # @example Receive from multiple topics:
    #   client.subscribe("/foo")
    #   client.subscribe("/bar")
    #   deliveries = receive(["/foo", "/bar"], :timeout=>1000)
    #   deliveries.each {|x| puts x.data} # can contain zero to two entries...
    #   client.unsubscribe("/foo")
    #   client.unsubscribe("/bar")
    def receive(topic_pattern, options = {})
      # Validate topic_pattern
      fail ArgumentError, 'topic_pattern must be a String.' unless
        topic_pattern.is_a? String

      # Validate options
      fail ArgumentError, 'options must be a Hash.' unless
        options.is_a?(Hash) || options.nil?

      timeout = options.fetch(:timeout, nil) if options.is_a? Hash
      if timeout
        fail ArgumentError, 'timeout must be nil or a unsigned Integer' if
          (!timeout.is_a? Integer) || (timeout < 0)
      end

      destination = @destinations.find do |dest|
        dest.topic_pattern.eql? topic_pattern
      end
      fail Mqlight::UnsubscribedError, 'You must be subscribed to a '\
        'destination to receive messages from it.' if destination.nil?

      @proton_queue_mutex.synchronize do
        @proton_queue.push(type: 'receive',
                           timeout: timeout,
                           destination: destination)
        @proton_queue_resource.signal
        until @proton_queue.empty?
          @proton_queue_resource.wait(@proton_queue_mutex, timeout)
        end
        @proton_queue_resource.signal
      end
      @message_queue.pop
    end

    # Unsubscribes from a destination.  The client will no longer be able to
    # receive messages from the destination.  If another thread is using the
    # receive() methods to retrieve messages from the destination that is being
    # unsubscribed from then the receive() method will return immediately
    # raising an UnsubscribedError.
    #
    # @param topic_pattern [String] the topic pattern to unsubscribe from.
    #        This identifies the destination to unsubscribe from.
    # @option options [Numeric] :ttl
    # @option options [String] :share
    # @raise StoppedError if the client is in stopped or stopping state.  This
    #        can also occur because another thread calls the stop method while
    #        a thread is blocked inside this receive method.
    # @raise UnsubscribedError if the client is not subscribed to the
    #        destination (e.g. there has been no matching call to the subscribe
    #        method).
    #
    # @note should the topic_pattern argument also accept an array of strings,
    #       allowing multiple topics to be unsubscribed from with a single
    #       method call?
    def unsubscribe(topic_pattern, options={})
      fail Mqlight::StoppedError, 'Not started' unless started?
      fail ArgumentError,
           'topic_pattern must be a String' unless topic_pattern.is_a? String
      @topic_pattern = topic_pattern

      destination = @destinations.find do |dest|
        dest.topic_pattern.eql? topic_pattern
      end
      fail Mqlight::UnsubscribedError,
           'client is not subscribed to this address' if destination.nil?

      # find and close the link
      link = Cproton.pn_messenger_get_link(@messenger_impl,
                                           destination.address,
                                           false)
      expiry_policy =
        Cproton.pn_terminus_get_expiry_policy(Cproton.pn_link_target(link))
      timeout = Cproton.pn_terminus_get_timeout(Cproton.pn_link_target(link))

      # if we're not expiring the link, we won't get an ACK from the server
      # so all we can do is wait until our request has gone over the network
      if timeout > 0 || expiry_policy == Cproton::PN_EXPIRE_NEVER
        Cproton.pn_link_detach(link)
        session = Cproton.pn_link_session(link)
        connection = Cproton.pn_session_connection(session)
        transport = Cproton.pn_connection_transport(connection)
        until Cproton.pn_transport_quiesced(transport)
          Cproton.pn_messenger_work(@messenger_impl, 0)
        end
      else
        # otherwise we can wait for server-side confirmation of the close
        Cproton.pn_link_close(link)
        while (Cproton.pn_link_state(link) & Cproton::PN_REMOTE_CLOSED) == 0
          Cproton.pn_messenger_work(@messenger_impl, 0)
        end
      end
    end

    # @return [nil, String] either the URL of the service that the client is
    #         currently connect to, or nil if the client is not currently
    #         connected to a service.
    def service
      if started?
        @service
      else
        nil
      end
    end

    #
    def started?
      @state == :started
    end

    #
    def stopped?
      @state == :stopped
    end

    #
    def retrying?
      @state == :retrying
    end

    # Returns the most recent error message.
    #
    def error
      Cproton.pn_error_text(Cproton.pn_messenger_error(@messenger_impl))
    end

    #
    def to_s
      "#{@id}"
    end

    private

    #
    def set_defaults
      # Generate id if none supplied
      @id ||= 'AUTO_' + SecureRandom.hex[0..6]
      # Empty service list to be populated
      @service_list = []
      # Initialise as stopped
      @state = :stopped
      # Start with no destinations
      @destinations = []
    end

    #
    def change_state(new_state, reason = nil)
      return if @state == new_state
      @state = new_state
      @callback_queue.push([@state_callback, @state, reason]) if @state_callback
    end

    #
    def generate_service_list
      return unless @service_lookup_uri

      # TODO: Retry logic
      @service_list = Mqlight::Util.get_service_urls(@service_lookup_uri)
    end

    #
    def validate_service_list
      property_auth = nil
      if @user && @password
        property_auth = "#{URI.encode_www_form_component(@user)}:"\
                        "#{URI.encode_www_form_component(@password)}"
      end

      @service_list.each do |service|
        service_auth = URI(service).userinfo
        if service_auth
          fail ArgumentError,
            "URLs supplied via the 'service' property must specify both a "\
            'user name and a password value, or omit both values' unless
          service_auth.split(':').size == 2
          fail ArgumentError,
            "User name supplied as an argument (#{property_auth}) does not "\
            "match user name supplied via a service url (#{service_auth})" if
            property_auth && !(property_auth.eql? service_auth)
        end

        next if URI(service).scheme.eql?('amqp')
        # TODO: remove comment once amqps:// is supported
        # next if URI(service).scheme.eql?('amqps')

        fail ArgumentError,
             "One of the supplied services (#{service}) is not a "\
             'URL scheme that is supported by this client'
      end
    end

    #
    def callback_loop
      argv = @callback_queue.pop
      callback = argv.shift
      callback.call(argv)
    end

    # @return the remote idle timeout in milliseconds or -1 if an error occurs
    def remote_timeout
      Cproton.pn_messenger_get_remote_idle_timeout(@messenger_impl,
                                                   @service.to_s)
    end

    #
    def proton_loop
      @proton_queue_mutex.synchronize do
        unless @proton_queue.empty?
          begin
            op = @proton_queue.pop(true)
            case op[:type]
            when 'send'
              process_queued_send op[:params]
            when 'subscription'
              process_queued_subscription op[:params]
            when 'receive'
              check_for_messages(op[:destination], op[:timeout])
            end
          rescue ThreadError
            # thrown by queue.pop if queue is empty (should never happen)
            break
          end
        end
        @proton_queue_resource.signal
        unless stopped?
          @proton_queue_resource.wait(@proton_queue_mutex,
                                      remote_timeout / 1000)
          Cproton.pn_messenger_work(@messenger_impl, 0)
          @proton_queue_resource.signal
        end
      end
    end

    #
    def process_queued_send(msg)
      check_for_error(Cproton.pn_messenger_put(@messenger_impl, msg))
      check_for_error(Cproton.pn_messenger_send(@messenger_impl, 1))
    rescue Qpid::Proton::ProtonError => error
      # FIXME: rather than raise exceptions, we need to pass them back
      #        to the client
      raise "ERROR: #{error.message}"
    end

    #
    def process_queued_subscription(destination)
      Cproton.pn_messenger_subscribe_ttl(@messenger_impl,
                                         destination.address,
                                         destination.ttl)
      link = Cproton.pn_messenger_get_link(@messenger_impl,
                                           destination.address,
                                           false)
      # block until link is active
      while (Cproton.pn_link_state(link) & Cproton::PN_REMOTE_ACTIVE) == 0
        Cproton.pn_messenger_work(@messenger_impl, 0)
      end

      # FIXME: shouldn't call link flow unless using manual credit (we're using
      #        explicit credit on our recv call)
      # Cproton.pn_link_flow(link, destination.credit) if destination.credit > 0

      # Store record of subscription
      @destinations.push(destination)
    rescue Qpid::Proton::ProtonError => error
      # FIXME: rather than raise exceptions, we need to pass them back
      #        to the client
      raise "ERROR: #{error.message}"
    end

    #
    def check_for_messages(destination, timeout = nil)
      link = Cproton.pn_messenger_get_link(@messenger_impl,
                                           destination.address, false)
      Cproton.pn_link_flow(link, 1) if Cproton.pn_link_credit(link) == 0
      loop do
        begin
          break unless started?
          # if timeout > 0
          #   loop_timeout = [timeout, remote_timeout].min
          # else
          #   loop_timeout = remote_timeout
          # end
          # XXX: until Cproton releases the GIL, use shorter timeouts
          loop_timeout = 1_000
          Cproton.pn_messenger_set_timeout(@messenger_impl, loop_timeout)
          check_for_error(Cproton.pn_messenger_recv(@messenger_impl, -2))
          break
        rescue Qpid::Proton::TimeoutError
          Cproton.pn_messenger_work(@messenger_impl, 0)
          next if timeout.nil?
          timeout -= loop_timeout
          break if timeout <= 0
        end
      end
      Cproton.pn_messenger_set_timeout(@messenger_impl, -1)

      incoming_count = Cproton.pn_messenger_incoming(@messenger_impl)
      if incoming_count == 0
        @message_queue.push(nil)
        return
      end

      msg = Qpid::Proton::Message.new
      begin
        check_for_error(Cproton.pn_messenger_get(@messenger_impl, msg.impl))
        msg.post_decode unless msg.nil?
      rescue Qpid::Proton::Error => error
        raise "ERROR: #{error.message}"
      end
      message = Mqlight::Delivery.new(msg, destination)

      # TODO: drain if Cproton.pn_link_credit(link).nonzero?
      @message_queue.push(message)

      fail "unexpectedly received #{incoming_count} messages when only 1 was "\
           'expected' if incoming_count > 1
    end
  end
end
