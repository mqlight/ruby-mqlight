# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/lib/mqlight/connection.rb
#
# <copyright
# notice="lm-source-program"
# pids="5725-P60"
# years="2013,2016"
# crc="3568777996" >
# Licensed Materials - Property of IBM
#
# 5725-P60
#
# (C) Copyright IBM Corp. 2015,2016
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
# </copyright>

module Mqlight
  # This class monitors the following:
  # * the link state
  # * out of sequence error message from the server.
  #
  # If the link state enters :retrying then the classes
  # thread will periocally attempt to reconnect providing
  # * There are active subscriptions.
  # * A request awaiting to be processed.
  # @private
  class Connection
    include Qpid::Proton::Util::ErrorHandler
    include Mqlight::Logging

    #
    #
    #
    def initialize(args)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      logger.parms(@id, parms) { self.class.to_s + '#' + __method__.to_s }

      @args = args
      @thread_vars = args[:thread_vars]
      @service = args[:service]
      @user = args[:user]
      @password = args[:password]

      @connect_mutex = Mutex.new
      @connect_resource = ConditionVariable.new

      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    # Will attempt to connect one of the services and will return with state
    # Started : Successful connection, @service will have URI
    # Stopped : Failed conn. server in @service rejected the connection request
    # Retry : All attempt had network conn. failures; @service has last URI.
    #
    # @private
    def connect_to_a_server
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }

      @service_list = []
      begin
        @service_list = Util.generate_services(@service, @user, @password)
      rescue Mqlight::NetworkError => ne
        logger.data(@id, 'Failed connection to ' + @service.to_s +
                          ' because ' + ne.to_s) do
          self.class.to_s + '#' + __method__.to_s
        end
        @thread_vars.change_state(:retrying, ne)
      rescue StandardError => se
        logger.data(@id, 'Failed to generate service list from ' +
                @service.to_s + ' because ' + se.to_s) do
          self.class.to_s + '#' + __method__.to_s
        end
        @thread_vars.change_state(:stopped, se)
      end

      items_left_in_service_list = @service_list.length
      @thread_vars.change_state(:starting) if items_left_in_service_list> 0

      @service_list.each do |service|
        @thread_vars.service = Service.new(service, @user, @password)
        begin
          items_left_in_service_list -= 1

          # If old one present then drop it
          close_end_point unless @end_point.nil?

          if @thread_vars.service.ssl?
            @end_point = SecureEndPoint.new(@args)
          else
            @end_point = UnsecureEndPoint.new(@args)
          end

          # Define the connection parameters
          @thread_vars.proton.connect(@thread_vars.service)
          # Start the bottom level to handle the socket.
          @end_point.start_connection_threads
          # Initiate the connection sequence.
          @thread_vars.proton.wait_messenger_started(@thread_vars.service)

          # Assign the service if we start successfully (without auth info)
          logger.data(@id, 'Success connection to ' + \
                           @thread_vars.service.to_s) do
            self.class.to_s + '#' + __method__.to_s
          end

          # Reinstate the active subscriptions
          @thread_vars.proton.reinstate_links \
            if @thread_vars.subscriptions_present?

          @thread_vars.change_state(:started)

        rescue Mqlight::NetworkError => ne
          logger.data(@id, 'Failed connection to ' + @thread_vars.service.to_s +
                            ' because ' + ne.to_s) do
            self.class.to_s + '#' + __method__.to_s
          end
          # Only report this on the last service in the list.
          @thread_vars.change_state(:retrying, ne) \
            if items_left_in_service_list <= 0
        rescue Mqlight::SecurityError => se
          logger.data(@id, 'Failed connection to ' + @thread_vars.service.to_s +
                            ' because ' + se.to_s) do
            self.class.to_s + '#' + __method__.to_s
          end
          @thread_vars.change_state(:stopped, se)
        rescue Mqlight::ReplacedError => re
          logger.data(@id, 'Failed connection to ' + @thread_vars.service.to_s +
                            ' because ' + re.to_s) do
            self.class.to_s + '#' + __method__.to_s
          end
          @thread_vars.change_state(:stopped, re)
        rescue Mqlight::SubscribedError => sub
          logger.data(@id, 'Failed reinstate a subscription ' +
                      @thread_vars.service.to_s + ' because ' + sub.to_s) do
            self.class.to_s + '#' + __method__.to_s
          end
          @thread_vars.change_state(:stopped, sub)
        ensure
          if stopped?
            close_end_point unless @end_point.nil?
          end
        end

        # Terminate loop if at final state.
        break if stopped? || started?
      end
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    # Initiate and start the link monitoring thread.
    #
    def start_thread
      @proton_thread = Thread.new do
        Thread.current['name'] = 'proton_thread'
        begin
          proton_loop
          logger.data(@id, 'Proton loop terminating') do
            self.class.to_s + '#' + __method__.to_s
          end
        rescue => e
          logger.ffdc(self.class.to_s + '#' + __method__.to_s,
                      'ffdc001', self, 'Uncaught exception', e)
        end
      end
    end

    #
    # Issue stop and wait for all thread to terminate
    #
    def stop_thread
      @proton_thread.join
      close_end_point
    rescue StandardError => e
      # This is required for the rspec unit tests.
      # and is due to the fact some of the thread
      # take time to closedown
      logger.data(@id, "Thrown error #{e}") do
        self.class.to_s + '#' + __method__.to_s
      end
    end

    #
    # This table defines the rate at which a lost connection
    # is attempted to be recovered. The values is in seconds
    DEFER_TABLE = [1, 2, 4, 8, 16, 32, 60]

    #
    # The main class thread method. This method will only
    # return when the link state becomes ':stopped where
    # the thread will die.
    # @private
    def proton_loop
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }

      defer_pos = 0
      max_defer_index = DEFER_TABLE.length - 1
      until stopped?
        if starting? || (
            retrying? &&
            (
              @thread_vars.subscriptions_present? ||
              @thread_vars.processing_command?
            )
        )
          connect_to_a_server
          defer_pos += 1 if defer_pos < max_defer_index
        else
          # As link is up .. reset to first value.
          defer_pos = 0
        end

        # Monitor oos messages
        @thread_vars.proton.check_for_out_of_sequence_messages

        # Need a pause
        @connect_mutex.synchronize do
          @connect_resource.wait(@connect_mutex, DEFER_TABLE[defer_pos])
        end
      end

      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    rescue StandardError => e
      logger.throw(@id, e) { self.class.to_s + '#' + __method__.to_s }
      raise e
    end

    #
    #
    #
    def close_end_point
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      unless @end_point.nil?
        @end_point.stop_threads
        @end_point = nil
      end
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    #
    #
    def wakeup
      @connect_resource.signal
    end

    #
    #
    #
    def started?
      @thread_vars.state == :started
    end

    #
    #
    #
    def stopped?
      @thread_vars.state == :stopped
    end

    #
    #
    #
    def retrying?
      @thread_vars.state == :retrying
    end

    #
    #
    #
    def starting?
      @thread_vars.state == :starting
    end
    # End of class
  end
  #
  #
  #
  class UnsecureEndPoint
    include Mqlight::Logging

    #
    #
    #
    def initialize(args)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      logger.parms(@id, parms) { self.class.to_s + '#' + __method__.to_s }

      @thread_vars = args[:thread_vars]
      @proton = @thread_vars.proton
      @service = @thread_vars.service
      hostname = @service.host
      port = @service.port

      begin
        @tcp_transport = TCPSocket.open(hostname, port)
      rescue => e
        logger.throw(@id, e) { self.class.to_s + '#' + __method__.to_s }
        raise Mqlight::NetworkError, e.to_s
      end

      @transport = @tcp_transport
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    #
    #
    def start_connection_threads
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }

      @incoming = Thread.new do
        incoming_thread
      end

      @outgoing = Thread.new do
        outgoing_thread
      end

      # Time for the threads to start
      sleep(0.1)
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    # Stop the IO threads
    #
    def stop_threads
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      begin
        @transport.shutdown(:WR)
      rescue => e
        logger.data(@id, 'Ignored: shutdown error ' + e.to_s) do
          self.class.to_s + '#' + __method__.to_s
        end
      end
      @incoming.kill
      @outgoing.kill
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    #
    #
    def incoming_thread
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      @proton.sockets_open = true

      until stopped?
        begin
          logger.often(@id, 'Waiting for incoming message') do
            self.class.to_s + '#' + __method__.to_s
          end

          msg = read_socket
          break if stopped?

          logger.often(@id, 'New incoming message size=' + msg.size.to_s) do
            self.class.to_s + '#' + __method__.to_s
          end unless msg.nil?

          # TODO: a null length message is treated as stream close.
          # TODO: but could the server not send a blank message?
          # TODO: get a way to detect remote end disconnect.
          break  if msg.nil? || msg.size == 0

          until msg.nil? || msg.size == 0
            n = @proton.proton_push(msg)
            if n == -2
              msg = nil
            elsif  n <= 0
              # Busy - try later.
              sleep(0.2)
            elsif n < msg.size
              # trim the message
              msg = msg[n..msg.length]
            else
              # Delivered
              msg = nil
            end
          end

        rescue Errno::ECONNRESET, EOFError => e
          logger.data(@id, 'Connection remotely terminated') do
            self.class.to_s + '#' + __method__.to_s
          end
          @proton.sockets_open = false

          unless stopped? || stopping?
            # A race condition can occur here as this error
            # could be processed before the preceeding CLOSE
            # message is read. This then results in a Retry
            # So ... delaying the report to ensure any CLOSE
            # message is processed first
            sleep 0.5
            ne = Mqlight::NetworkError.new(
              'Connection remotely terminated [' + e.to_s + ']')
            @thread_vars.change_state(:retrying, ne)
          end
          break
        rescue => e
          logger.data(@id, "Exception: #{e}") do
            self.class.to_s + '#' + __method__.to_s
          end
          logger.ffdc(self.class.to_s + '#' + __method__.to_s,
                      'ffdc002', self, 'Uncaught exception', e)
        end
      end
      @proton.sockets_open = false
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    #
    #
    def read_socket
      @transport.recv(1024)
    end

    #
    #
    #
    def outgoing_thread
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      deliver = @thread_vars.proton.create_delivery_message(@service)
      until stopped? or not @proton.sockets_open?
        begin
          logger.often(@id, 'Waiting for outgoing message') do
            self.class.to_s + '#' + __method__.to_s
          end
          msg = deliver.get
          if msg.nil?
            # Wait a little and wake-up proton in case a heart beat is required.
            deliver.empty_pop
            sleep(0.01)
          else
            logger.often(@id, 'Outgoing message size=' + msg.size.to_s) do
              self.class.to_s + '#' + __method__.to_s
            end
            @transport.write(msg)
            @transport.flush
          end

        rescue Errno::EPIPE => e
          logger.data(@id, 'Connection remotely terminated') do
            self.class.to_s + '#' + __method__.to_s
          end
          # A race condition can occur here as this error
          # could be processed before the preceeding CLOSE
          # message is read. This then results in a Retry
          # So ... delaying the report to ensure any CLOSE
          # message is processed first
          sleep 0.5
          ne = Mqlight::NetworkError.new(
            'Connection remotely terminated [' + e.to_s + ']')
          @thread_vars.change_state(:retrying, ne)
        rescue => e
          logger.ffdc(self.class.to_s + '#' + __method__.to_s,
                      'ffdc003', self, 'Uncaught exception', e)
        end
      end
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    rescue => e
      logger.ffdc(self.class.to_s + '#' + __method__.to_s,
                  'ffdc004', self, 'Uncaught exception', e)
    end

    #
    #
    #
    def stopped?
      @thread_vars.state == :stopped
    end
    
    #
    #
    #
    def stopping?
      @thread_vars.state == :stopping
    end

    #
    #
    #
    def retrying?
      @thread_vars.state == :retrying
    end
  end
  # End of class

  #
  #
  #
  class SecureEndPoint < UnsecureEndPoint
    include Mqlight::Logging
    #
    #
    #
    def initialize(args)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      logger.parms(@id, parms) { self.class.to_s + '#' + __method__.to_s }

      super(args)

      # SSL details
      ssl = SecureSocket.new(args[:options])
      context = ssl.context(@thread_vars.service.host)

      begin
        ssl_transport = OpenSSL::SSL::SSLSocket.new(@tcp_transport, context)
        ssl_transport.connect
        fail Mqlight::SecurityError, 'certificate verify failed' \
          if ssl.verify_server_host_name_failed?
      rescue => e
        logger.throw(@id, e) { self.class.to_s + '#' + __method__.to_s }
        msg = e.to_s
        if msg.include? 'certificate verify failed'
          raise Mqlight::SecurityError, 'certificate verify failed'
        else
          raise Mqlight::NetworkError, msg
        end
      end
      @transport = ssl_transport
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    #
    #
    def read_socket
      @transport.sysread(1024)
    end

    #
    # Stop the IO threads
    #
    def stop_threads
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      begin
        @tcp_transport.shutdown(:WR)
      rescue => e
        logger.data(@id, 'Ignored: shutdown error ' + e.to_s) do
          self.class.to_s + '#' + __method__.to_s
        end
      end
      @incoming.kill
      @outgoing.kill
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end
  end
  # End of class
end
