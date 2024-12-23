# lib/envo/railtie.rb
# frozen_string_literal: true

require 'rails/railtie'

module Envo
  class Railtie < Rails::Railtie
    initializer 'envo.initialize' do |app|
      begin
        Envo.init

        env_file = Rails.root.join(".env.#{Rails.env}")
        env_file = Rails.root.join('.env') unless File.exist?(env_file)

        Envo.load_dotenv(env_file) if File.exist?(env_file)

        Envo.logger.info("Envo initialized successfully with #{env_file}")
      rescue Envo::Error => e
        Rails.logger.fatal("Envo initialization failed: #{e.message}")
        raise
      end
    end
  end
end
