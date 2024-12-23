# lib/envo/key_manager.rb
# frozen_string_literal: true

require 'securerandom'
require 'rails'

module Envo
  class KeyManager
    class << self
      # Generates a secure random encryption key
      #
      # @param length [Integer] The length of the key in bytes. Default is 32 bytes (256 bits).
      # @return [String] The generated key encoded in hexadecimal.
      def generate_key(length: 32)
        SecureRandom.hex(length)
      end

      # Retrieves the encryption key from Rails credentials
      #
      # @return [String] The encryption key.
      # @raise [Envo::Error] If the encryption key is not set.
      def get_key
        key = Rails.application.credentials.envo_encryption_key
        raise Envo::Error, 'Encryption key is not set in Rails credentials (envo_encryption_key).' unless key && !key.strip.empty?

        key
      end

      # Sets the encryption key in Rails credentials
      #
      # @param key [String] The encryption key to set.
      # @raise [Envo::Error] If setting the key fails.
      def set_key(key)
        begin
          credentials = Rails.application.credentials
          credentials.envo_encryption_key = key
          Rails.application.credentials.write
        rescue StandardError => e
          raise Envo::Error, "Failed to set encryption key: #{e.message}"
        end
      end

      # Rotates the encryption key
      #
      # @param new_key [String] The new encryption key.
      # @raise [Envo::Error] If rotation fails.
      def rotate_key(new_key)
        old_key = get_key
        # Reinitialize EnvLoader with the new key
        Envo::EnvLoader.rotate_key(old_key, new_key)
        set_key(new_key)
      rescue StandardError => e
        raise Envo::Error, "Key rotation failed: #{e.message}"
      end

      # Validates the encryption key
      #
      # @raise [Envo::Error] If the encryption key is invalid.
      def validate_key!
        key = get_key
        raise Envo::Error, 'Encryption key must be a valid hexadecimal string of length 64 characters (32 bytes).' unless valid_hex_key?(key)
      end

    private

      # Checks if the key is a valid hexadecimal string of 64 characters (32 bytes)
      #
      # @param key [String] The encryption key to validate.
      # @return [Boolean] True if valid, else false.
      def valid_hex_key?(key)
        !!(/\A\h{64}\z/ =~ key)
      end
    end
  end
end
