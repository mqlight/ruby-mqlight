# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/lib/mqlight/proton_container.rb
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

module Mqlight
  # This class handles the interaction with the qpid_proton
  # and protecting access via multible thread.
  # Must methods are wrapped in a 'synchronize' block to
  # ensure only one thread has access to the qpid proton
  # at any one time.
  # @private
  class ProtonContainer
    include Qpid::Proton::Util::ErrorHandler
    include Mqlight::Logging

    # @param thread_vars [class] holds all the shared variables
    # @param id [string] identification to be used with qpid proton.
    #
    def initialize(thread_vars, id)
      @thread_vars = thread_vars
      @container = Mutex.new
      @container_resource = ConditionVariable.new
      @id = id
      @sockets_open = false
    end

    #
    # Attempts to connect to the given service.
    # If it fails it will throw an exception indicating the
    # failure type.
    #
    def connect(service)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      logger.parms(@id, parms) { self.class.to_s + '#' + __method__.to_s }

      @container.synchronize do
        @messenger_impl = Cproton.pn_messenger(@id)
        Cproton.pn_messenger_set_flags(@messenger_impl,
                                       Cproton::PN_FLAGS_CHECK_ROUTES |
                                       Cproton::PN_FLAGS_EXTERNAL_SOCKET)
        Cproton.pn_messenger_set_passive(@messenger_impl, true)
        Cproton.pn_messenger_set_incoming_window(@messenger_impl, 1024)
        Cproton.pn_messenger_set_outgoing_window(@messenger_impl, 1024)
        Cproton.pn_messenger_set_external_socket(@messenger_impl)
        Cproton.pn_messenger_route(@messenger_impl,
                                   service.pattern + '/*',
                                   service.address + '/$1')

        check_for_error(Cproton.pn_messenger_start(@messenger_impl))
        @connection = Cproton.pn_messenger_resolve(@messenger_impl,
                                                   service.address)
        fail(Mqlight::InternalError,
             "Could not resolve #{service.pattern} to a connection") \
             if @connection.nil?
      end
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
      rescue => e
        Logging.logger.throw(nil, e) { self.class.to_s + '#' + __method__.to_s }
        raise e
    end

    # Monitor the lower level waiting for the
    # connection to be confirmed as started.
    # @param service [Service]  used to assist for trace messages.
    # @raise [Mqlight::TimeoutError]
    # @raise [Mqlight::SecurityError]
    # @raise [Mqlight::NetworkError]
    def wait_messenger_started(service)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      finished = false
      Timeout.timeout(8.0) do
        while !finished  do
          @container.synchronize do
            finished = check_started()
            next if finished
            check_sasl_outcome()
          end
          sleep(0.1)
        end
      end
      raise Mqlight::NetworkError,
            'Connection remotely terminated' unless sockets_open?

      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
      # Success - return
    rescue Timeout::Error
      logger.data(@id, 'Timeout exception waiting for ' + service.to_s) do
        self.class.to_s + '#' + __method__.to_s
      end
      free_messenger
      raise Mqlight::NetworkError,
            'Mqlight server did not respond within timeout'

    rescue Qpid::Proton::ProtonError => e
      free_messenger
      error_msg = e.to_s
      logger.data(@id, 'Exception for ' + service.to_s + ' of ' + error_msg) do
        self.class.to_s + '#' + __method__.to_s
      end
      if /sasl /.match(error_msg) || /SSL /.match(error_msg) || /2035/.match(error_msg)
        new_msg = "AMQXR9001E:Security Error (amqp:unauthorized-access) #{error_msg}"
        raise Mqlight::SecurityError, new_msg
      else
        raise Mqlight::NetworkError, error_msg
      end
    end

    #
    #
    #
    def sockets_open=(state)
      logger.entry_often(@id) { self.class.to_s + '#' + __method__.to_s }
      @container_resource.broadcast
      @sockets_open = state
      logger.exit_often(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    # Check to see of the connection has started and then if
    # there were any errors.
    # @return [boolean] where connection has started
    # @raise [ProtonError] if there is a reported error.
    # 
    def check_started
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      Cproton.pn_messenger_work(@messenger_impl, 1000)
      rc  = Cproton::pn_messenger_started(@messenger_impl)
      if (Cproton.pn_messenger_errno(@messenger_impl) != 0)
        text = Cproton.pn_error_text(
          Cproton.pn_messenger_error(@messenger_impl))
        logger.data(@id, 'Throwing : ' + text) \
          { self.class.to_s + '#' + __method__.to_s }
        puts "Thrown 001"
        fail Qpid::Proton::ProtonError, text
      end
      logger.exit(@id,rc) { self.class.to_s + '#' + __method__.to_s }
      rc
    end

    #
    # Check to see if SASL status has changed. If change check for
    # connection closed and report error.
    # there were any errors.
    # @raise [ProtonError] if there is a reported error.
    # 
    def check_sasl_outcome
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      transport = Cproton.pn_connection_transport(@connection);
      outcome = Cproton.pn_sasl_outcome(transport)
      if outcome >= 1
        Cproton.pn_connection_was_closed(@messenger_impl, @connection)
        if (Cproton.pn_messenger_errno(@messenger_impl) != 0)
          text = Cproton.pn_error_text(
            Cproton.pn_messenger_error(@messenger_impl))
          logger.data(@id, 'Throwing : ' + text) \
            { self.class.to_s + '#' + __method__.to_s }
          fail Qpid::Proton::ProtonError, text
        end
        logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
      end
    end

    #
    #
    #
    def free_messenger
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      @container.synchronize do
        unless @messenger_impl.nil?
          # XXX: this segfaults
          #Cproton.pn_messenger_work(@messenger_impl, 1000)
          #Cproton.pn_messenger_free(@messenger_impl)
          @messenger_impl = nil
        end
      end
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    # This method reinstates all the active subscriptions that
    # were present when the connect to the server was lost.
    #
    def reinstate_links
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }

      @container.synchronize do
        # for all destinations
        @thread_vars.destinations.each do |destination|
          Cproton.pn_messenger_subscribe_ttl(@messenger_impl,
                                             destination.address,
                                             destination.ttl)
          link = Cproton.pn_messenger_get_link(@messenger_impl,
                                               destination.address,
                                               false)
          while (Cproton.pn_link_state(link) &
                 Cproton::PN_REMOTE_ACTIVE) == 0
            # TODO: Let low level process I/O
            @container_resource.wait(@container, 1)
            # Perform work
            Cproton.pn_messenger_work(@messenger_impl, 1000)
            # Check for errors from last work action
            unless Cproton.pn_messenger_errno(@messenger_impl) == 0
              # Stop on 1st failed to reinstate a subscription
              fail Mqlight::SubscribedError, Cproton.pn_error_text(
                Cproton.pn_messenger_error(@messenger_impl))
            end
            # Short pause - ok to hold on to the lock here as
            # nothing else can be done until this completes.
            sleep 0.1
          end
        end
      end
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    #
    # @private
    def check_for_out_of_sequence_messages
      logger.entry_often(@id) { self.class.to_s + '#' + __method__.to_s }

      @container.synchronize do
        break if @messenger_impl.nil?
        Cproton.pn_messenger_work(@messenger_impl, 1000)
        interpret_message if Cproton.pn_messenger_errno(@messenger_impl) != 0 && started?

        unless sockets_open?
          # Braces of the belt and braces
          logger.data(@id, 'Detected lower level socket closed') do
            self.class.to_s + '#' + __method__.to_s
          end
          @thread_vars.change_state(:retrying,
                                    Mqlight::NetworkError.new(
                                      'Connection terminated')) \
                      if @thread_vars.state == :started
        end
      end
      logger.exit_often(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    #
    # No synchronize as dead lock can occur
    def self.finalize!(impl)
      proc do
        # Cproton.pn_messenger_free(impl) unless @messenger_impl.nil?
      end
    end

    #
    #
    # No synchronize as dead lock can occur
    def error
      Cproton.pn_error_text(Cproton.pn_messenger_error(@messenger_impl))
    end

    #
    #
    #
    def put_message(msg, qos)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      @container.synchronize do
        check_for_error(Cproton.pn_messenger_put(@messenger_impl, msg))
        if qos == 0
          tracker = Cproton.pn_messenger_outgoing_tracker(@messenger_impl)
          check_for_error(
            Cproton.pn_messenger_settle(@messenger_impl, tracker, 0))
        end
        check_for_error(Cproton.pn_messenger_send(@messenger_impl, 1))
      end
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    #
    #
    def tracker_status
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      rc = 0
      @container.synchronize do
        tracker = Cproton.pn_messenger_outgoing_tracker(@messenger_impl)
        rc = Cproton.pn_messenger_status(@messenger_impl, tracker)
      end
      logger.exit(@id, rc) { self.class.to_s + '#' + __method__.to_s }
      rc
    end

    #
    #
    #
    def outbound_pending?
      logger.entry_often(@id) { self.class.to_s + '#' + __method__.to_s }
      rc = false
      @container.synchronize do
        tracker = Cproton.pn_messenger_outgoing_tracker(@messenger_impl)
        rc = Cproton.pn_messenger_buffered(@messenger_impl, tracker)
      end
      logger.exit_often(@id, rc) { self.class.to_s + '#' + __method__.to_s }
      rc
    end

    #
    # returns the associated error condition/description store in the
    # selected tracker for the messenger_impl parameter.
    def tracker_condition_description(default_value)
      Logging.logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      Logging.logger.parms(@id, parms) do
        self.class.to_s + '#' + __method__.to_s
      end

      @container.synchronize do
        tracker = Cproton.pn_messenger_outgoing_tracker(@messenger_impl)
        return default_value if tracker.nil?
        delivery = Cproton.pn_messenger_delivery(@messenger_impl, tracker)
        return default_value if delivery.nil?
        disposition = Cproton.pn_delivery_remote(delivery)
        return default_value if disposition.nil?
        condition = Cproton.pn_disposition_condition(disposition)
        return default_value if condition.nil?
        description = Cproton.pn_condition_get_description(condition)
        return default_value if description.nil?
        #
        logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
        description
      end
    rescue => e
      Logging.logger.throw(nil, e) { self.class.to_s + '#' + __method__.to_s }
      raise e
    end

    #
    #
    #
    def create_subscription(destination)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      Logging.logger.parms(@id, parms) do
        self.class.to_s + '#' + __method__.to_s
      end
      rc = 0
      @container.synchronize do
        Cproton.pn_messenger_subscribe_ttl(@messenger_impl,
                                           destination.address,
                                           destination.ttl)
        rc = Cproton.pn_messenger_get_link(@messenger_impl,
                                           destination.address,
                                           false)
      end
      logger.exit(@id, rc) { self.class.to_s + '#' + __method__.to_s }
      rc
    end

    #
    # Check to see if the subscription link is up?
    #
    def link_up?(link)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }

      rc = true
      @container.synchronize do
        Cproton.pn_messenger_work(@messenger_impl, 1000)
        if ((Cproton.pn_link_state(link) & Cproton::PN_REMOTE_ACTIVE) == 0)
          # Still down, was there an error?
          fail Mqlight::SubscribedError,
               Cproton.pn_error_text(
                 Cproton.pn_messenger_error(@messenger_impl)) unless \
                   Cproton.pn_messenger_errno(@messenger_impl) == 0
          rc = false
        end
      end

      logger.exit(@id, rc.to_s) { self.class.to_s + '#' + __method__.to_s }
      rc
    end

    #
    #
    #
    def close_link(destination, ttl)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      Logging.logger.parms(@id, parms) do
        self.class.to_s + '#' + __method__.to_s
      end

      link = nil
      @container.synchronize do
        # find and close the link
        link = Cproton.pn_messenger_get_link(@messenger_impl,
                                             destination.address,
                                             false)
        fail Mqlight::InternalError,
             "Missing link for close_link(#{destination}, #{ttl})" if link.nil?

        if ttl == 0
          Cproton.pn_terminus_set_expiry_policy(Cproton.pn_link_target(link),
                                                Cproton::PN_EXPIRE_WITH_LINK)
          Cproton.pn_terminus_set_expiry_policy(Cproton.pn_link_source(link),
                                                Cproton::PN_EXPIRE_WITH_LINK)
          Cproton.pn_terminus_set_timeout(Cproton.pn_link_target(link), ttl)
          Cproton.pn_terminus_set_timeout(Cproton.pn_link_source(link), ttl)
        end

        expiry_policy =
          Cproton.pn_terminus_get_expiry_policy(Cproton.pn_link_target(link))
        timeout = Cproton.pn_terminus_get_timeout(Cproton.pn_link_target(link))

        # if we're not expiring the link, we won't get an ACK from the server
        # so all we can do is wait until our request has gone over the network
        if timeout > 0 || expiry_policy == Cproton::PN_EXPIRE_NEVER
          Cproton.pn_link_detach(link)
          until Cproton.pn_link_remote_detached(link)
            Cproton.pn_messenger_work(@messenger_impl, 1000)
            # TODO: long wait here .. could lower level signal to release earlier?
            @container_resource.wait(@container, 1)
          end
          Cproton.pn_messenger_reclaim_link(@messenger_impl, link)
          Cproton.pn_link_free(link)
        else
          # otherwise we can wait for server-side confirmation of the close
          #
          Cproton.pn_link_close(link)
          while (Cproton.pn_link_state(link) & Cproton::PN_REMOTE_CLOSED) == 0
            Cproton.pn_messenger_work(@messenger_impl, 1000)
            @container_resource.wait(@container, 1)
          end
        end
      end

      logger.exit(@id, link) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    #
    #
    def open_for_message(destination)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }

      link = nil
      @container.synchronize do
        link = Cproton.pn_messenger_get_link(@messenger_impl,
                                             destination.address, false)

        unless link.nil?
          Cproton.pn_link_flow(link, 1) if Cproton.pn_link_credit(link) == 0
          begin
            Cproton.pn_messenger_set_timeout(@messenger_impl, 250)
            check_for_error(Cproton.pn_messenger_recv(@messenger_impl, -2))
          rescue Qpid::Proton::TimeoutError
            logger.debug(@id, 'TimeoutError. This is fine.') do
              self.class.to_s + '#' + __method__.to_s
            end
          rescue Qpid::Proton::StateError => e
            # Assuming this means there is a network error, so exit
            logger.data(@id, 'StateError ... lost of connection.') do
              self.class.to_s + '#' + __method__.to_s
            end
            raise e
          ensure
            Cproton.pn_messenger_set_timeout(@messenger_impl, -1)
          end
        end
      end

      # Return the link
      logger.exit(@id, link) { self.class.to_s + '#' + __method__.to_s }
      link
    end

    #
    #
    def message?
      logger.entry_often(@id) { self.class.to_s + '#' + __method__.to_s }

      rc = false
      @container.synchronize do
        rc = Cproton.pn_messenger_incoming(@messenger_impl) > 0
      end

      logger.exit_often(@id, rc) { self.class.to_s + '#' + __method__.to_s }
      rc
    end

    #
    #
    #
    def drain_message(link)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      rc = 0
      @container.synchronize do
        # if no message was received, we set the drain flag and wait for the
        # server to advance the delivery-count, consuming our credit
        Cproton.pn_link_drain(link, 0)
        while Cproton.pn_link_draining(link) && started?
          logger.data(@id, 'Waiting for drain to complete') do
            self.class.to_s + '#' + __method__.to_s
          end
          Cproton.pn_messenger_work(@messenger_impl, 1000)
          @container_resource.wait(@container, 1)
        end
        rc = Cproton.pn_messenger_incoming(@messenger_impl) > 0
      end

      logger.exit(@id, rc) { self.class.to_s + '#' + __method__.to_s }
      rc
    end

    #
    #
    #
    def collect_message
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }

      msg = nil
      @container.synchronize do
        msg = Qpid::Proton::Message.new
        begin
          Cproton.pn_messenger_work(@messenger_impl, 1000)
          check_for_error(Cproton.pn_messenger_get(@messenger_impl, msg.impl))
          msg.post_decode
        rescue  => error
          logger.throw(@id, error) { self.class.to_s + '#' + __method__.to_s }
          raise error
        end
      end

      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
      msg # return the message
    end

    #
    #
    #
    def tracker
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }

      @container.synchronize do
        Cproton.pn_messenger_incoming_tracker(@messenger_impl)
      end

      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    # Performs a settle of the given message/track with error handling.
    #
    def settle(_link)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      logger.parms(@id, parms) { self.class.to_s + '#' + __method__.to_s }

      @container.synchronize do
        tracker =  Cproton.pn_messenger_incoming_tracker(@messenger_impl)
        Cproton.pn_messenger_settle(@messenger_impl, tracker, 0);
        interpret_message if Cproton.pn_messenger_errno(@messenger_impl) != 0
      end

      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    rescue => e
      logger.throw(@id, e) { self.class.to_s + '#' + __method__.to_s }
      raise e
    end

    #
    # Performs a accept of the given message/track with error handling
    #
    def accept(_link)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      logger.parms { parms }

      @container.synchronize do
        tracker =  Cproton.pn_messenger_incoming_tracker(@messenger_impl)
        Cproton.pn_messenger_accept(@messenger_impl, tracker, 0)
        fail Mqlight::NetworkError,
             Cproton.pn_error_text(
               Cproton.pn_messenger_error(@messenger_impl)) \
                 unless Cproton.pn_messenger_errno(@messenger_impl) == 0
      end

      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    rescue => e
      logger.throw(@id, e) { self.class.to_s + '#' + __method__.to_s }
      raise e
    end

    #
    #
    #
    def remote_idle_timeout(service)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }

      rc = 0
      @container.synchronize do
        rc = Cproton.pn_messenger_get_remote_idle_timeout(
          @messenger_impl, service.to_s)
      end

      logger.exit(@id, rc) { self.class.to_s + '#' + __method__.to_s }
      rc
    end

    #
    #
    #
    def stop
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }

      @container.synchronize do
        rc = Cproton.pn_messenger_stop(@messenger_impl)
        if rc == Cproton::PN_INPROGRESS
          until Cproton.pn_messenger_stopped(@messenger_impl)
            Cproton.pn_connection_pop(@connection, 0) # Push the stop through
            @container_resource.wait(@container, 0.1)
          end
        end
        #Cproton.pn_messenger_free(@messenger_impl)
        @messenger_impl = nil
      end

      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    # Configures the settle mode based on the given QoS
    #
    def settle_mode=(qos)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      logger.parms(@id, parms) { self.class.to_s + '#' + __method__.to_s }

      @container.synchronize do
        if qos == 0
          logger.debug(@id, 'Setting snd mode to ' + \
                            Cproton::PN_SND_SETTLED.to_s) do
            self.class.to_s + '#' + __method__.to_s
          end
          Cproton.pn_messenger_set_snd_settle_mode(
            @messenger_impl,
            Cproton::PN_SND_SETTLED)
          logger.debug(@id, 'Setting rcv mode to ' + \
                            Cproton::PN_RCV_FIRST.to_s) do
            self.class.to_s + '#' + __method__.to_s
          end
          Cproton.pn_messenger_set_rcv_settle_mode(
            @messenger_impl,
            Cproton::PN_RCV_FIRST)
        elsif qos == 1
          logger.debug(@id, 'Setting snd mode to ' + \
                            Cproton::PN_SND_UNSETTLED.to_s) do
            self.class.to_s + '#' + __method__.to_s
          end
          Cproton.pn_messenger_set_snd_settle_mode(
            @messenger_impl,
            Cproton::PN_SND_UNSETTLED)
          logger.debug(@id, 'Setting snd mode to ' + \
                            Cproton::PN_RCV_FIRST.to_s) do
            self.class.to_s + '#' + __method__.to_s
          end
          Cproton.pn_messenger_set_rcv_settle_mode(
            @messenger_impl,
            Cproton::PN_RCV_FIRST)
        else
          fail ArgumentError,
               "Argument qos=#{qos} is an invalid value. " \
               'Must be either QOS_AT_LEAST_ONCE(0) or QOS_AT_MOST_ONCE(1)'
        end
      end
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    rescue => e
      logger.throw(@id, e) { self.class.to_s + '#' + __method__.to_s }
      raise e
    end

    #
    #
    #
    def proton_push(msg)
      logger.entry_often(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      logger.often(@id, parms) { self.class.to_s + '#' + __method__.to_s }

      size = 0
      @container.synchronize do
        unless @messenger_impl.nil?
          size = Cproton.pn_connection_push(@connection, msg, msg.length)
          Cproton.pn_connection_pop(@connection, 0) if started?
        end
      end

      logger.exit_often(@id, size) \
        { self.class.to_s + '#' + __method__.to_s }
      size
    end

    #
    #
    # @param service [String]
    def create_delivery_message(service)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      logger.parms(@id, parms) { self.class.to_s + '#' + __method__.to_s }
      rc = DeliveryMessage.new(@messenger_impl, service, @container)
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
      rc
    end

    #
    #
    #
    def sockets_open?
      @sockets_open
    end

    #
    #
    #
    def starting?
      @thread_vars.state == :starting
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
    def interpret_message
      text = Cproton.pn_error_text(
        Cproton.pn_messenger_error(@messenger_impl))
      error = Cproton.pn_messenger_error(@messenger_impl)
      Cproton.pn_error_clear(error)
      logger.data(@id, "interpreting message: #{text}") do
        self.class.to_s + '#' + __method__.to_s
      end
      unless text.nil?
        if text.include? '_Takeover'
          @thread_vars.change_state(:stopped,
                                    Mqlight::ReplacedError.new(text))
        elsif text.include? 'connection aborted'
          @thread_vars.change_state(:retrying,
                                    Mqlight::NetworkError.new(text))
        else
          @thread_vars.change_state(:retrying,
                                    Mqlight::NetworkError.new(text))
        end
      end
    end

    #
    #
    #
    class DeliveryMessage
      include Mqlight::Logging

      IS_CLOSED = Cproton::PN_LOCAL_CLOSED | Cproton::PN_REMOTE_CLOSED \
                | Cproton::PN_REMOTE_UNINIT

      #
      #
      #
      def initialize(messenger_impl, service, container)
        logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
        parms = Hash[method(__method__).parameters.map do |parm|
          [parm[1], eval(parm[1].to_s)]
        end]
        logger.parms(@id, parms) { self.class.to_s + '#' + __method__.to_s }
        @container = container
        @container.synchronize do
          @pn_connection = Cproton.pn_messenger_resolve(messenger_impl,
                                                        service.address)
          @pn_transport = Cproton.pn_connection_transport(@pn_connection) \
              unless @pn_connection.nil?
        end
        fail(Mqlight::InternalError,
             "Could not resolve #{service} to a connection") \
              if @pn_connection.nil?
        fail(Mqlight::InternalError,
             "Could not resolve connection of #{service} to a transport") \
              if @pn_transport.nil?
        logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
      end

      #
      # get a message from the transport head
      #
      def get
        logger.entry_often(@id) { self.class.to_s + '#' + __method__.to_s }
        parms = Hash[method(__method__).parameters.map do |parm|
          [parm[1], eval(parm[1].to_s)]
        end]
        logger.often(@id, parms) { self.class.to_s + '#' + __method__.to_s }
        msg = nil
        @container.synchronize do
          pending_bytes = Cproton.pn_transport_pending(@pn_transport)
          if pending_bytes > 0
            # The patched pn_transport_peek returns two values
            _length, msg = Cproton.pn_transport_peek(
              @pn_transport, pending_bytes)
            Cproton.pn_connection_pop(@pn_connection, pending_bytes)
          end
        end
        logger.often(@id, msg.nil? ? 'nil' : msg.size) \
          { self.class.to_s + '#' + __method__.to_s }
        msg # return
      rescue => e
        logger.ffdc(self.class.to_s + '#' + __method__.to_s,
                    'ffdc008', self, 'Uncaught exception', e)
        logger.throw(@id, e) { self.class.to_s + '#' + __method__.to_s }
        raise e
      end

      #
      # Triggers a wake-up with proton
      #
      def empty_pop
        @container.synchronize do
          Cproton.pn_connection_pop(@pn_connection, 0) \
            unless (Cproton.pn_connection_state(@pn_connection) & IS_CLOSED) != 0
        end
      end
    end
  end
end
