# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/lib/mqlight/logging.rb
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
  # Internal class that handles logging
  module Logging
    require 'logger'

    def logger
      Logging.logger
    end

    def self.logger
      @logger ||= MqlightLogger.new(STDERR)
    end

    # The logger used by all internal MQ Light classes
    class MqlightLogger < Logger
      require 'socket'
      # Logging severity.
      module Severity
        ALL = -1000
        PROTON_DATA = -1000
        PROTON_EXIT = -1000
        PROTON_ENTRY = -1000
        PROTON = -1000
        DATA_OFTEN = 100
        EXIT_OFTEN = 100
        ENTRY_OFTEN = 100
        OFTEN = 100
        RAW = 200
        DETAIL = 300
        DEBUG = 500
        EMIT = 800
        DATA = 1000
        PARMS = 1200
        HEADER = 1500
        EXIT = 1500
        ENTRY = 1500
        ENTRY_EXIT = 1500
        ERROR = 1800
        FFDC = 2000
        # an unknown message that should always be logged
        UNKNOWN = 3000
      end
      include Severity

      # The identifier used when a log entry is not associated with a
      # particular client.
      NO_CLIENT_ID = '*'

      # Define a method for logging each sev
      Severity.constants.each do |sev|
        define_method(sev.to_s.downcase) do |progname = NO_CLIENT_ID,
                                             msg = nil, &block|
          progname = NO_CLIENT_ID unless progname.is_a? String
          message = block.call.to_s
          if msg && @level > DETAIL
            message << ' ' + mask(msg).to_s
          elsif msg
            message << ' ' + msg.to_s
          end

          add(Severity.const_get(sev.to_s),
              message, (format_sev(sev) + progname), &block)
        end
      end

      def initialize(logdev, shift_age = 0, shift_size = 1_048_576)
        super(logdev, shift_age, shift_size)
        @ffdc_sequence = 0
        if ENV['MQLIGHT_RUBY_LOG'] 
          begin
          @level_name = ENV['MQLIGHT_RUBY_LOG'].upcase
            self.level = Severity.const_get(@level_name)
            header
          rescue
            @level_name = 'FFDC'
            self.level = FFDC
          end
        else
          @level_name = 'FFDC'
          self.level = FFDC
        end
      end

      def format_message(_severity, datetime, progname, msg)
        "#{datetime.strftime('%H:%M:%S.%L')} [" +
          format('%-14s', "#{Process.pid}:#{Thread.current.object_id}") +
          "] #{progname} #{msg}\n"
      end

      # Log exit from a method.
      #
      # @param progname [String] The id of the client logging the exception
      # @param rc The yielded value of the method
      # @param block The name of the method that is being exited
      def exit(progname = NO_CLIENT_ID, rc = nil, &block)
        progname = NO_CLIENT_ID unless progname.is_a? String
        begin
          msg = yield.to_s + ' ' + rc.class.to_s + '->' + rc.to_s unless rc.nil?
        rescue => e
          msg = nil
        end
        add(EXIT, msg, (format_sev('exit') + progname), &block)
      end

      # Log an exception being thrown.
      #
      # @param id [String] The id of the client logging the exception
      # @param err [String] The exception being thrown
      # @param _block [Method] The name of the method that is being exited
      def throw(id = NO_CLIENT_ID, err = nil, &_block)
        id = NO_CLIENT_ID unless id.is_a? String
        add(ERROR, '* Thrown exception: ' + err.class.to_s + \
          ': ' + err.to_s, (format_sev('exit') + id))
        add(EXIT, (yield.to_s + ' Exception thrown'), (format_sev('exit') + id))
      end

      def ffdc(_fnc = 'User-requested FFDC by function',
               probe_id = 255, client, data, exception)
        entry(@id) { self.class.to_s + '#' + __method__.to_s }
        parms = Hash[method(__method__).parameters.map do |parm|
          [parm[1], eval(parm[1].to_s)]
        end]
        parms(@id, parms) { self.class.to_s + '#' + __method__.to_s }

        @ffdc_sequence += 1

        add(FFDC, ('-' * 80), format_sev('ffdc'))
        add(FFDC, 'First Failure Data Capture', format_sev('ffdc'))
        header
        if exception && (exception.is_a? Exception)
          add(FFDC, 'Error', format_sev('ffdc'))
          add(FFDC, exception.inspect, format_sev('ffdc'))
          add(FFDC, exception.backtrace, format_sev('ffdc'))
        end
        add(FFDC, '', format_sev('ffdc'))
        add(FFDC, 'Function Stack', format_sev('ffdc'))
        caller.each do |key, value|
          add(FFDC, key.to_s + '=>' + value.to_s, format_sev('ffdc'))
        end
        add(FFDC, '', format_sev('ffdc'))
        if client
          add(FFDC, 'Client', format_sev('ffdc'))
          add(FFDC, client.to_s, format_sev('ffdc'))
          add(FFDC, '', format_sev('ffdc'))
        end
        if data
          add(FFDC, 'Data', format_sev('ffdc'))
          add(FFDC, data.to_s, format_sev('ffdc'))
          add(FFDC, '', format_sev('ffdc'))
        end
        if (@ffdc_sequence == 1) || (probe_id == 255)
          add(FFDC, 'Environment Variables', format_sev('ffdc'))
          ENV.to_hash.each do |key, value|
            add(FFDC, key.to_s + '=>' + value.to_s, format_sev('ffdc'))
          end
          add(FFDC, ('-' * 80), format_sev('ffdc'))
        end

        exit(@id) { self.class.to_s + '#' + __method__.to_s }
      rescue => e
        throw(nil, e) { self.class.to_s + '#' + __method__.to_s }
        raise e
      end

      private

      def header
        sev = format_sev(@level_name)
        add(@level, ('-' * 80), sev)
        add(@level, ('IBM MQ Light Ruby Client'), sev)
        add(@level, ('-' * 80), sev)
        add(@level, format_header_msg('Host Name') + Socket.gethostname, sev)
        add(@level, format_header_msg('Operating System') + RUBY_PLATFORM, sev)
        add(@level, format_header_msg('Ruby Version') + "#{RUBY_VERSION}-" \
                                      "p#{RUBY_PATCHLEVEL}", sev)
        add(@level, format_header_msg('Name') + 'mqlight', sev)
        add(@level, format_header_msg('Version') + Mqlight::VERSION, sev)
        add(@level, format_header_msg('Logging Level') + sev, sev)
        add(@level, ('-' * 80), sev)
      end

      def format_header_msg(msg)
        format('%-19s', msg) + ':- '
      end

      # Formats the severity of the message, ensuring alignment.
      def format_sev(sev)
        format('%-13s', sev.to_s.downcase)
      end

      # Masks passwords and message date from the supplied object.
      # Assumes Hash for now.
      def mask(to_strip)
        # Extensible if we want to mask from Strings etc in the future
        mask_from_hash(to_strip)
      end

      # Masks any passwords or message data in a Hash.
      def mask_from_hash(to_strip)
        return to_strip unless to_strip.is_a? Hash
        # Deep clone so we don't affect the original opts
        hash = deep_clone_hash(to_strip)
        # Mask any :password in the Hash
        hash[:password] = '********' if hash[:password]
        hash[:ssl_client_key_passphrase] = '********' if hash[:ssl_client_key_passphrase]
        hash[:ssl_keystore_passphrase] = '********' if hash[:ssl_keystore_passphrase]
        hash[:data] = '********' if hash[:data]
        # Recurse to sub-hashes
        hash.each do |key, value|
          hash[key] = mask_from_hash(value) if value.is_a? Hash
          next unless (key.to_s.eql? 'service') || (key.to_s.eql? 'address') || (key.to_s.eql? "service_list")
          if value.is_a? String
            hash[key] = mask_passwords_from_string(value)
          elsif value.is_a? Array
            value.map! { |url| mask_passwords_from_string(url.to_s) }
          end
        end
        hash
      end

      # Masks any passwords from a service url string
      def mask_passwords_from_string(to_strip)
        to_strip.sub(%r{:[^\/:]+@}, ':********@')
      end

      # Clone to we don't mask passwords from the actual strings we're logging.
      def deep_clone_hash(obj)
        hash = {}
        obj.each do |key, value|
          begin
            if value.is_a? Hash
              hash[key] = deep_clone_hash(value)
            else
              hash[key] = Marshal.load(Marshal.dump(value))
            end
          rescue TypeError
            # We'll get this in the case of SWIG objects and Procs.
            # We can shallow copy these as we won't be editing them.
            hash[key] = value
          end
        end
        hash
      end
    end
  end
end
