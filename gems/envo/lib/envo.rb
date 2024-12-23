# lib/envo.rb
# frozen_string_literal: true

require_relative 'envo/version'
require_relative 'envo/env_loader'
require_relative 'envo/key_manager'
require_relative 'envo/railtie' if defined?(Rails)
require 'logger'

module Envo
  class Error < StandardError; end

  @mutex = Mutex.new
  @encrypted_vars = {}
  @logger = Logger.new($stdout)
  @logger.level = Logger::INFO

  class << self
    attr_reader :logger

    # Initialize Envo with encryption key from KeyManager
    def init
      key = Envo::KeyManager.get_key
      Envo::EnvLoader.init(key)
    rescue Envo::Error => e
      logger.fatal("Envo initialization failed: #{e.message}")
      raise
    end

    # Set an environment variable with encryption
    def set(key, value)
      @mutex.synchronize do
        EnvLoader.set(key, value)
        @encrypted_vars[key] = value
      end
    rescue StandardError => e
      logger.error("Failed to set #{key}: #{e.message}")
      raise Error, "Failed to set #{key}: #{e.message}"
    end

    # Get a decrypted environment variable
    def get(key)
      @mutex.synchronize do
        return @encrypted_vars[key] if @encrypted_vars.key?(key)

        value = EnvLoader.get(key)
        @encrypted_vars[key] = value if value
        value
      end
    rescue StandardError => e
      logger.error("Failed to get #{key}: #{e.message}")
      raise Error, "Failed to get #{key}: #{e.message}"
    end

    # Load environment variables from a .env file
    def load_dotenv(file_path = '.env')
      EnvLoader.load_dotenv(file_path)
    rescue StandardError => e
      logger.error("Failed to load dotenv from #{file_path}: #{e.message}")
      raise Error, "Failed to load dotenv from #{file_path}: #{e.message}"
    end
  end
end
