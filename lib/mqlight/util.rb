# @(#) MQMBID sn=mqkoa-L160208.09 su=_Zdh2gM49EeWAYJom138ZUQ pn=appmsging/ruby/mqlight/lib/mqlight/util.rb
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
# (C) Copyright IBM Corp. 2014,2016
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
# </copyright>

require 'uri'
require 'net/http'
require 'json'

module Mqlight
  #
  #
  #
  # @private
  class Util
    include Mqlight::Logging

    def self.validate_services(service, property_user, property_pass)
      Logging.logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      Logging.logger.parms(@id, parms) do
        self.class.to_s + '#' + __method__.to_s
      end

      property_auth = nil
      if property_user && property_pass
        property_auth = "#{URI.encode_www_form_component(property_user)}:"\
                        "#{URI.encode_www_form_component(property_pass)}"
      end

      service_strings = []

      # Convert argument into an array
      if service.is_a?(Array)
        service_strings = service
      elsif service.is_a?(String)
        service_strings << service
      end

      service_uris = []
      # For each entry convert to URI and validate.
      service_strings.each do |s|
        begin
          uri = URI(s)
        rescue
          raise ArgumentError, "#{s} is not a valid service"
        end
        fail ArgumentError, "#{s} is not a valid service" if uri.host.nil?
        next if uri.scheme.eql?('http') || uri.scheme.eql?('https')

        fail ArgumentError, "#{s} is not a supported scheme" \
          unless uri.scheme.eql?('amqp') || uri.scheme.eql?('amqps')

        if uri.userinfo
          fail ArgumentError,
               "URLs supplied via the 'service' property must specify both a "\
               'user name and a password value, or omit both values' unless
          uri.userinfo.split(':').size == 2
          fail ArgumentError,
               "User name supplied as an argument (#{property_auth}) does not"\
               ' match user name supplied via a service url'\
               "(#{uri.userinfo})" if
            property_auth && !(property_auth.eql? uri.userinfo)
        end

        fail ArgumentError,
             "One of the supplied services (#{uri}) #{uri.path} " \
             'is not a valid URL' \
             unless uri.path.nil? || uri.path.length == 0 \
               || uri.path == '/'

        service_uris << uri
      end
      Logging.logger.exit(@id, [service_uris]) \
          { self.class.to_s + '#' + __method__.to_s }
      return service_uris
    end

    def self.generate_services(service, property_user, property_pass)
      Logging.logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      Logging.logger.parms(@id, parms) do
        self.class.to_s + '#' + __method__.to_s
      end

      # if 'service' param is an http(s) URI then fetch the service list from it
      if service.is_a?(String)
        uri = URI(service)
        if uri.scheme.eql?('http') || uri.scheme.eql?('https')
          service = get_service_urls(uri)
        end
      end
      service_uris = validate_services(service, property_user, property_pass)

      Logging.logger.exit(@id, [service_uris]) \
          { self.class.to_s + '#' + __method__.to_s }
      return service_uris
    end

    #
    def self.get_service_urls(lookup_uri)
      Logging.logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      Logging.logger.parms(@id, parms) do
        self.class.to_s + '#' + __method__.to_s
      end

      fail ArgumentError, 'lookup_uri must be a String or URI' unless
        (lookup_uri.is_a?(String)) || (lookup_uri.is_a?(URI))
      res = http_get(URI(lookup_uri))
      fail Mqlight::NetworkError, "http request to #{lookup_uri} failed "\
        "with status code of #{res.code}" unless res.code == '200'
      result = JSON.parse(res.body)['service']
      Logging.logger.exit(@id, result) \
          { self.class.to_s + '#' + __method__.to_s }
      result
    rescue => e
      Logging.logger.throw(nil, e) { self.class.to_s + '#' + __method__.to_s }
      raise e
    end

    # @private
    def self.http_get(lookup_uri)
      Logging.logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      Logging.logger.parms(@id, parms) do
        self.class.to_s + '#' + __method__.to_s
      end

      validate_uri_scheme(lookup_uri)
      Net::HTTP.start(lookup_uri.host, lookup_uri.port,
                      use_ssl: (lookup_uri.scheme == 'https')) do |http|
        path = lookup_uri.path
        path += '?' + lookup_uri.query if lookup_uri.query
        get = Net::HTTP::Get.new(path)
        http.request(get)
      end
    rescue => e
      Logging.logger.throw(nil, e) { self.class.to_s + '#' + __method__.to_s }
      raise ArgumentError, "Could not access lookup details because #{e}"
    end

    # @private
    def self.validate_uri_scheme(lookup_uri)
      fail ArgumentError, 'lookup_uri must be a http or https URI.' unless
        (lookup_uri.scheme.eql? 'http') || (lookup_uri.scheme.eql? 'https')
    end

    #
    #
    #
    def self.truncate(text)
      text
      text[0..200] + '... (truncated from ' + text.length.to_s + ')' \
        if text.length > 200
    end
  end # End of class

  #
  # A contain design to hold all the connection information.
  # Note. the 'to_s' has been designed to supress showing the password.
  #
  class Service
    include Mqlight::Logging
    include URI

    attr_reader :pattern
    attr_reader :address
    attr_reader :service
    attr_reader :host
    attr_reader :port

    #
    # @param service [URI] of the service to connect to
    # @param user [String] the user id to connect with
    # @param password [String] the password for the given user id.
    #
    def initialize(uri, user = nil, password = nil)
      # No Trace - security

      @service_uri = uri
      unless @service_uri.port
        @service_uri.port = (@service_uri.scheme == 'amqps') ? 5671 : 5672
      end

      # Handle authentication information.
      if user && password && @service_uri.userinfo.nil?
        @service_uri.userinfo = "#{URI.encode_www_form_component(user)}:"\
               "#{URI.encode_www_form_component(password)}"
      end

      @address = @service_uri.to_s
      p = @service_uri.clone
      p.userinfo = ''
      @pattern = p.to_s
      @service = "#{@service_uri.scheme}://#{@service_uri.host}:" \
        "#{@service_uri.port}"
      @host = @service_uri.host
      @port = @service_uri.port
      # No Trace
    end

    #
    #
    #
    def ssl?
      @service_uri.scheme == 'amqps'
    end

    #
    #
    #
    def to_s
      if @service_uri.userinfo
        "[Service] #{@service_uri.scheme}://#{@service_uri.user}:*******" \
          "@#{@service_uri.host}:#{@service_uri.port}"
      else
        "[Service] #{@service_uri.scheme}://#{@service_uri.host}:" \
          "#{@service_uri.port}"
      end
    end

    #
    # Override inspect so that the URI passwords are not returned
    # as clear text
    #
    def inspect
      a = '<Mqlight::Service'
      a << ' @service_uri = '
      a << @service_uri.inspect.sub(%r{:[^\/:]+@}, ':********@')
      a << ', @address = '
      a << @address.inspect.sub(%r{:[^\/:]+@}, ':********@')
      a << ', @pattern = '
      a << @pattern.inspect
      a << ', @service = '
      a << @service.inspect
      a << ', @host = '
      a << @host.inspect
      a << ', @port = '
      a << @port.inspect
      a << '>'
    end
  end # End of class

  #
  # This class handles and processes the
  # SSL connection options for this client.
  #
  class SecureSocket
    include Mqlight::Logging

    attr_reader :ssl_trust_certificate
    attr_reader :verified_host_name

    #
    # @params [] all SSL arguments
    #
    def initialize(options)
      @id = options.fetch(:id, nil)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      Logging.logger.parms(@id, parms) do
        self.class.to_s + '#' + __method__.to_s
      end

      # Look for any non keystore argument and remember first
      first_with_keystore_argument = nil
      without_keystore_options = \
        [:ssl_client_certificate, :ssl_trust_certificate,
         :ssl_client_key, :ssl_client_key_passphrase]
      with_keystore_options = [:ssl_keystore, :ssl_keystore_passphrase]
      with_keystore_options.each do |argument_name|
        unless options[argument_name].nil?
          first_with_keystore_argument = argument_name
          break
        end
      end

      # Look for any keystore argument and remember first
      first_without_keystore_argument = nil
      without_keystore_options.each do |argument_name|
        unless options[argument_name].nil?
          first_without_keystore_argument = argument_name
          break
        end
      end

      fail ArgumentError, 'Invalid combination of arguments '\
           "#{first_without_keystore_argument} and " \
           "#{first_with_keystore_argument}" \
        if first_without_keystore_argument && first_with_keystore_argument

      # Load and validate arguments
      if first_without_keystore_argument
        # Load options
        @ssl_client_certificate = options[:ssl_client_certificate]
        @ssl_trust_certificate = options[:ssl_trust_certificate]
        @ssl_client_key = options[:ssl_client_key]
        @ssl_client_key_passphrase = options[:ssl_client_key_passphrase]
        # Validate types
        fail ArgumentError, 'ssl_client_certificate must be of type String' \
          unless @ssl_client_certificate.nil? ||
                 @ssl_client_certificate.is_a?(String)
        fail ArgumentError, 'ssl_trust_certificate must be of type String' \
          unless @ssl_trust_certificate.nil? ||
                 @ssl_trust_certificate.is_a?(String)
        fail ArgumentError, 'ssl_client_key must be of type String' \
          unless @ssl_client_key.nil? ||
                 @ssl_client_key.is_a?(String)
        fail ArgumentError, 'ssl_client_key_passphrase must be of type String' \
          unless @ssl_client_key_passphrase.nil? ||
                 @ssl_client_key_passphrase.is_a?(String)
        # Combination check.
        fail ArgumentError,
             'Invalid combination of arguments. The client key passphrase is ' \
             'present but no associated client key has been specified' \
          if !@ssl_client_key_passphrase.nil? && @ssl_client_key.nil?
        # client key set : If one is present then all must be present
        # sslClientCertificate, sslClientKey and sslClientKeyPassphrase
        client_key_set_one_present = !@ssl_client_certificate.nil? || !@ssl_client_key.nil? || !@ssl_client_key_passphrase.nil?
        client_key_set_one_missing = @ssl_client_certificate.nil? || @ssl_client_key.nil? || @ssl_client_key_passphrase.nil?
        fail ArgumentError,
             'sslClientCertificate, sslClientKey and sslClientKeyPassphrase ' \
             'options must all be specified' \
          if client_key_set_one_present && client_key_set_one_missing
        # Check file references
        validate_file_path @ssl_trust_certificate, 'ssl_trust_certificate' \
          unless @ssl_trust_certificate.nil?
        validate_file_path @ssl_client_certificate, 'ssl_client_certificate'\
          unless @ssl_client_certificate.nil?
        validate_file_path @ssl_client_key, 'ssl_client_key'\
          unless @ssl_client_key.nil?
        @keystore_present = false
      elsif first_with_keystore_argument
        # Load options
        ssl_keystore = options[:ssl_keystore]
        ssl_keystore_passphrase = options[:ssl_keystore_passphrase]
        # Validate types
        fail ArgumentError, 'ssl_keystore must be of type String' \
          unless ssl_keystore.is_a? String
        fail ArgumentError, 'ssl_keystore_passphrase must be of type String' \
          unless ssl_keystore_passphrase.is_a? String
        # Combination check
        fail ArgumentError,
             'Invalid combination of arguments. The keystore passphrase is ' \
             'present but no associated keystore has been specified' \
          if ssl_keystore_passphrase.nil? && !ssl_keystore.nil?
        # Check file references
        validate_file_path ssl_keystore, 'ssl_keystore' \
          unless ssl_keystore.nil?

        # Load the keystore
        data = File.binread(ssl_keystore)
        @keystore_pkcs12 = OpenSSL::PKCS12.new(data, ssl_keystore_passphrase)
        @keystore_present = true
      end

      # If server host verification option required?
      @ssl_verify_name = options.fetch(:ssl_verify_name, false)
      fail ArgumentError, 'ssl_verify_name must be of type Binary' \
        unless @ssl_verify_name.is_a? TrueClass or
               @ssl_verify_name.is_a? FalseClass

      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
    rescue StandardError => e
      logger.throw(@id, e) { self.class.to_s + '#' + __method__.to_s }
      raise e
    end

    #
    # @return [PKey] containing the given private key or nil if none is present
    #
    def rsa_private_key
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      rc = nil
      if @keystore_present
        rc = @keystore_pkcs12.key
      elsif !@ssl_client_key.nil?
        begin
          rc = OpenSSL::PKey::RSA.new \
            File.read(@ssl_client_key), \
            @ssl_client_key_passphrase
        rescue OpenSSL::PKey::RSAError => re
          logger.throw(@id, re) { self.class.to_s + '#' + __method__.to_s }
          fail ArgumentError, \
               'File given for the ssl_client_key is not a valid RSA ' \
               'Certificate'
        end
      end
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
      rc
    end

    #
    # @return [X509Store] contains one or more CA for the given keystore
    #         or arguments. nil is returned is none are present
    #
    def x509_certificate_authorities
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      store = nil
      if @keystore_present && !@keystore_pkcs12.ca_certs.nil?
        store = OpenSSL::X509::Store.new
        @keystore_pkcs12.ca_certs.each do |cert|
          begin
            store.add_cert cert
          rescue OpenSSL::X509::StoreError => e
            fail ArgumentError, \
                 'File given for the \'ssl_trust_certificate\' argument ' \
                 "has the following error \'#{e}\'" \
                 unless e.message.include? 'cert already in hash table'
                   
            logger.data(@id, e.message + ' - Certificate has been skipped') do
              self.class.to_s + '#' + __method__.to_s
            end
          end
        end
      elsif ! @ssl_trust_certificate.nil?
        begin
          store = OpenSSL::X509::Store.new
          store.add_file @ssl_trust_certificate
        rescue OpenSSL::X509::StoreError => se
          logger.throw(@id, se) { self.class.to_s + '#' + __method__.to_s }
          fail ArgumentError, \
               'File given for the \'ssl_trust_certificate\' argument is not ' \
               'a valid trust certificate'
        end
      else
        store = OpenSSL::X509::Store.new
        store.set_default_paths
      end
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
      store
    end

    #
    # @return [OpenSSL::X509::Certificate] from the given attributes or
    #         null if not are present.
    #
    def x509_certificate
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      if @keystore_present
        rc = @keystore_pkcs12.certificate
      elsif ! @ssl_client_certificate.nil?
        begin
          rc = OpenSSL::X509::Certificate.new File.read(@ssl_client_certificate)
        rescue OpenSSL::X509::CertificateError => se
          logger.throw(@id, se) { self.class.to_s + '#' + __method__.to_s }
          fail ArgumentError,
               'File given for the \'ssl_client_certificate\' argument ' \
               'is not a valid X509 certificate'
        end
      end
      logger.exit(@id) { self.class.to_s + '#' + __method__.to_s }
      rc
    end

    #
    # Create the SSL context based on the given attributes
    # @param server_host_name [String] name of the server host to be used for
    #        validating certificates.
    # @return [SSLContext] the generated context
    #
    def context(server_host_name)
      logger.entry(@id) { self.class.to_s + '#' + __method__.to_s }
      parms = Hash[method(__method__).parameters.map do |parm|
        [parm[1], eval(parm[1].to_s)]
      end]
      logger.parms(@id, parms) { self.class.to_s + '#' + __method__.to_s }

      context = OpenSSL::SSL::SSLContext.new

      # Create the X509 Store for the CAs
      context.cert_store = x509_certificate_authorities

      # Private key
      context.key = rsa_private_key

      # Client Certificate
      context.cert = x509_certificate
      context.verify_mode = OpenSSL::SSL::VERIFY_PEER

      # If verify name required then assign callback facility to
      # receive acknowledgement
      @verified_host_name = false
      if @ssl_verify_name
        context.verify_callback = proc do |_preverify, inner_context|
          @verified_host_name |= OpenSSL::SSL.verify_certificate_identity(
            inner_context.current_cert, server_host_name)
          true
        end
      end

      logger.exit(@id, context) { self.class.to_s + '#' + __method__.to_s }
      context
    end

    # Validates that the given file is present and regular
    # @param file_path [String] file path to file to be validate
    # @param file_description [String] descriptive file of file.
    def validate_file_path(file_path, file_description)
      fail ArgumentError,
           "The file specified for #{file_description} does not exist" \
             unless File.exist?(file_path)
      fail ArgumentError,
           "The file specified for #{file_description} is not a regular file" \
             unless File.file?(file_path)
    end

    #
    # @return [Boolean] true indicate verification was required and it
    # failed.
    #
    def verify_server_host_name_failed?
      @ssl_verify_name && !@verified_host_name
    end
  end
end
