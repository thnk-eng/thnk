# lib/envo/env_loader.rb
# frozen_string_literal: true

require 'openssl'
require 'base64'
require 'yaml'
require 'digest'

module Envo
  class EnvLoader
    class << self
      # Initialize the EnvLoader with the encryption key
      #
      # @param encryption_key [String] The encryption key.
      # @raise [Envo::Error] If the encryption key is invalid.
      def init(encryption_key)
        @encryption_key = encryption_key
        validate_key!
      end

      # Set and encrypt a value for a given key
      #
      # @param key [String] The name of the environment variable.
      # @param value [Object] The value to be encrypted and stored.
      # @raise [Envo::Error] If encryption fails.
      def set(key, value)
        encrypted_value = encrypt_value(value)
        ENV[key] = encrypted_value
      end

      # Get and decrypt the value for a given key
      #
      # @param key [String] The name of the environment variable.
      # @return [Object, nil] The decrypted value or nil if not set.
      # @raise [Envo::Error] If decryption fails.
      def get(key)
        encrypted_value = ENV[key]
        return nil unless encrypted_value

        decrypt_value(encrypted_value)
      end

      # Load environment variables from a .env file
      #
      # @param file_path [String] The path to the .env file.
      # @raise [Envo::Error] If file reading or parsing fails.
      def load_dotenv(file_path = '.env')
        unless File.exist?(file_path)
          Envo.logger.warn("Dotenv file #{file_path} does not exist.")
          return
        end

        File.readlines(file_path).each_with_index do |line, index|
          line.strip!
          next if line.empty? || line.start_with?('#')

          if line =~ /\A(\w+)=(.+)\z/
            key, value = Regexp.last_match.captures
            begin
              parsed_value = parse_value(value)
              set(key, parsed_value)
            rescue StandardError => e
              Envo.logger.error("Error parsing line #{index + 1} in #{file_path}: #{e.message}")
              next
            end
          else
            Envo.logger.warn("Invalid format in #{file_path} on line #{index + 1}: #{line}")
          end
        end
      end

      # Rotates encryption key by re-encrypting all existing ENV variables
      #
      # @param old_key [String] The current encryption key.
      # @param new_key [String] The new encryption key.
      # @raise [Envo::Error] If re-encryption fails.
      def rotate_key(old_key, new_key)
        # Temporarily set the new encryption key
        original_key = @encryption_key
        @encryption_key = new_key

        # Iterate over all ENV variables managed by Envo and re-encrypt them
        managed_keys = ENV.keys.select { |k| envo_managed_key?(k) }

        managed_keys.each do |key|
          encrypted_value = ENV[key]
          next unless encrypted_value

          # Decrypt with old key
          decrypted_value = decrypt_value_with_key(encrypted_value, old_key)

          # Encrypt with new key
          new_encrypted_value = encrypt_value_with_key(decrypted_value, new_key)

          # Update ENV
          ENV[key] = new_encrypted_value
        end

        # Restore the original encryption key
        @encryption_key = original_key
      rescue StandardError => e
        Envo.logger.error("Key rotation failed: #{e.message}")
        raise Envo::Error, "Key rotation failed: #{e.message}"
      end

    private

      # Validates the presence of the encryption key
      #
      # @raise [Envo::Error] If the encryption key is invalid.
      def validate_key!
        raise Error, 'Encryption key is not set.' unless @encryption_key && !@encryption_key.strip.empty?
        raise Error, 'Encryption key must be a valid hexadecimal string of length 64 characters (32 bytes).' unless valid_hex_key?(@encryption_key)
      end

      # Checks if the key is a valid hexadecimal string of 64 characters (32 bytes)
      #
      # @param key [String] The encryption key to validate.
      # @return [Boolean] True if valid, else false.
      def valid_hex_key?(key)
        !!(/\A\h{64}\z/ =~ key)
      end

      # Encrypts a given value using AES-256-GCM
      #
      # @param value [Object] The value to encrypt.
      # @return [String] The Base64-encoded encrypted value.
      # @raise [Envo::Error] If encryption fails.
      def encrypt_value(value)
        cipher = OpenSSL::Cipher.new('aes-256-gcm')
        cipher.encrypt
        cipher.key = Digest::SHA256.digest(@encryption_key)
        iv = cipher.random_iv

        plaintext = YAML.dump(value)
        encrypted = cipher.update(plaintext) + cipher.final
        tag = cipher.auth_tag

        # Pack IV, tag, and encrypted data together
        packed = [iv, tag, encrypted].map(&:bytes).flatten.pack('C*')
        Base64.strict_encode64(packed)
      rescue StandardError => e
        Envo.logger.error("Encryption failed: #{e.message}")
        raise Envo::Error, "Encryption failed: #{e.message}"
      end

      # Decrypts a given encrypted value using AES-256-GCM
      #
      # @param encrypted_value [String] The Base64-encoded encrypted value.
      # @return [Object] The decrypted value.
      # @raise [Envo::Error] If decryption fails.
      def decrypt_value(encrypted_value)
        decoded = Base64.strict_decode64(encrypted_value)
        iv, tag, encrypted = decoded.unpack('a12a16a*')

        cipher = OpenSSL::Cipher.new('aes-256-gcm')
        cipher.decrypt
        cipher.key = Digest::SHA256.digest(@encryption_key)
        cipher.iv = iv
        cipher.auth_tag = tag

        decrypted = cipher.update(encrypted) + cipher.final
        YAML.load(decrypted)
      rescue OpenSSL::Cipher::CipherError => e
        Envo.logger.error("Decryption failed: #{e.message}")
        raise Envo::Error, "Decryption failed for value: #{e.message}"
      rescue StandardError => e
        Envo.logger.error("Decryption error: #{e.message}")
        raise Envo::Error, "Decryption error: #{e.message}"
      end

      # Decrypts a value using a specific key (used during rotation)
      #
      # @param encrypted_value [String] The encrypted value.
      # @param key [String] The decryption key.
      # @return [Object] The decrypted value.
      # @raise [Envo::Error] If decryption fails.
      def decrypt_value_with_key(encrypted_value, key)
        decoded = Base64.strict_decode64(encrypted_value)
        iv, tag, encrypted = decoded.unpack('a12a16a*')

        cipher = OpenSSL::Cipher.new('aes-256-gcm')
        cipher.decrypt
        cipher.key = Digest::SHA256.digest(key)
        cipher.iv = iv
        cipher.auth_tag = tag

        decrypted = cipher.update(encrypted) + cipher.final
        YAML.load(decrypted)
      rescue OpenSSL::Cipher::CipherError => e
        Envo.logger.error("Decryption failed during key rotation: #{e.message}")
        raise Envo::Error, "Decryption failed during key rotation: #{e.message}"
      rescue StandardError => e
        Envo.logger.error("Decryption error during key rotation: #{e.message}")
        raise Envo::Error, "Decryption error during key rotation: #{e.message}"
      end

      # Encrypts a value using a specific key (used during rotation)
      #
      # @param value [Object] The value to encrypt.
      # @param key [String] The encryption key.
      # @return [String] The encrypted value.
      # @raise [Envo::Error] If encryption fails.
      def encrypt_value_with_key(value, key)
        cipher = OpenSSL::Cipher.new('aes-256-gcm')
        cipher.encrypt
        cipher.key = Digest::SHA256.digest(key)
        iv = cipher.random_iv

        plaintext = YAML.dump(value)
        encrypted = cipher.update(plaintext) + cipher.final
        tag = cipher.auth_tag

        # Pack IV, tag, and encrypted data together
        packed = [iv, tag, encrypted].map(&:bytes).flatten.pack('C*')
        Base64.strict_encode64(packed)
      rescue StandardError => e
        Envo.logger.error("Encryption failed during key rotation: #{e.message}")
        raise Envo::Error, "Encryption failed during key rotation: #{e.message}"
      end

      # Determines if the ENV key is managed by Envo
      #
      # @param key [String] The environment variable key.
      # @return [Boolean] True if managed by Envo, else false.
      def envo_managed_key?(key)
        # Implement a naming convention or tracking mechanism
        # For simplicity, assume all keys are managed by Envo
        # Alternatively, prefix keys with "ENVO_" or maintain a registry
        true
      end

      # Parses string values into appropriate Ruby data types
      #
      # @param value [String] The string representation of the value.
      # @return [Object] The parsed value.
      # @raise [Envo::Error] If parsing fails.
      def parse_value(value)
        value = value.strip

        case value
          when /\A\d+\z/
            value.to_i
          when /\A\d+\.\d+\z/
            value.to_f
          when /\A(true|false)\z/i
            value.downcase == 'true'
          when /\A\{.*\}\z/, /\A\[.*\]\z/
            YAML.safe_load(value, [Symbol], aliases: true)
          when /\A".*"\z/, /\A'.*'\z/
            value[1..-2]
          else
            value
        end
      rescue StandardError => e
        Envo.logger.error("Failed to parse value '#{value}': #{e.message}")
        raise Envo::Error, "Failed to parse value '#{value}': #{e.message}"
      end
    end
  end
end
