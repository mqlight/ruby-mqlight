# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/lib/mqlight/thread_vars.rb
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
# (C) Copyright IBM Corp. s2015
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
# </copyright>

module Mqlight
  # This class handles the inter-communication between the threads
  # The class serves two purposes
  # (1) Central location for all module shared variables.
  # (2) Access control
  # @private
  class ThreadVars
    include Mqlight::Logging

    # These variable do not need to be protected by mutex.
    attr_reader :reply_queue
    attr_reader :message_queue
    attr_reader :callback_queue
    attr_reader :proton
    attr_reader :connect_id
    attr_writer :state_callback
    attr_reader :last_state_error
    #
    #
    #
    def initialize(id)
      #
      @id = id
      #
      @thread_vars_mutex = Mutex.new
      @thread_vars_resource = ConditionVariable.new

      @proton = Mqlight::ProtonContainer.new(self, @id)

      @state = :stopped
      @processing_command = false

      # Setup queue for returning acknowledgements or exception
      # from the proton loop to the block caller.
      @reply_queue = Queue.new
      # Setup queue for running any user callbacks in
      @callback_queue = Queue.new
      # The list of subscription for this client.
      @destinations = []
      # Number of reconnections
      @connect_id = 0
      # The error information associated with the last state change
      @last_state_error = nil
    end

    #
    # Will update the connection state and notify those
    # interest in the change.
    #
    def state=(new_state)
      @thread_vars_mutex.synchronize do
        if @state != new_state
          @state = new_state
          @thread_vars_resource.signal
        end
      end
    end

    #
    # Return the current connection state.
    #
    def state
      @thread_vars_mutex.synchronize do
        @state
      end
    end

    #
    # Will block the calling thread until there is a change
    # of connection state.
    #
    def wait_for_state_change(timeout)
      @thread_vars_mutex.synchronize do
        @thread_vars_resource.wait(@thread_vars_mutex, timeout)
      end
      @state
    end

    #
    # Defines in the command thread is processing a command
    #
    def processing_command=(new_processing_command)
      @thread_vars_mutex.synchronize do
        @processing_command = new_processing_command
      end
    end

    #
    # Indicate if the command thread is processing a command.
    #
    def processing_command?
      @thread_vars_mutex.synchronize do
        @processing_command
      end
    end

    #
    # Will update the connection state and notify those
    # interest in the change.
    #
    def messenger_impl=(messenger_impl)
      @thread_vars_mutex.synchronize do
        @messenger_impl = messenger_impl
      end
    end
    #
    # Return the current connection state.
    #
    def messenger_impl
      @thread_vars_mutex.synchronize do
        @messenger_impl
      end
    end

    #
    # Return the current connection state.
    #
    def destinations
      @thread_vars_mutex.synchronize do
        @destinations
      end
    end

    #
    # Indicate if the command thread is processing a command.
    #
    def service
      @thread_vars_mutex.synchronize do
        @service_tools
      end
    end

    #
    # Set the connections service URL
    #
    def service=(service_tools)
      @thread_vars_mutex.synchronize do
        @service_tools = service_tools
      end
    end

    #
    # Handle the change of state and when change
    # Send message to the callback to report back to
    # Client
    #
    def change_state(new_state, reason = nil)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      logger.parms(@id, parms) { self.class.to_s + '#' + __method__.to_s }
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s } if
         state == new_state

      @last_state_error = reason
      return if @state == new_state
      @state = new_state
      @callback_queue.push([@state_callback, @state, reason]) if
        @state_callback
      @thread_vars_resource.signal

      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    rescue StandardError => e
      logger.throw(@id, e) { self.class.to_s + '#' + __method__.to_s }
      raise e
    end

    #
    #
    #
    def subscriptions_present?
      !@destinations.empty?
    end

    #
    #
    #
    def subscriptions_clear
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      @destinations = []
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    end

    #
    #
    #
    def reconnected
      @connect_id += 1
    end
    # End of class
  end
end
