# app/services/openai.rb
require 'openai'

module BubbleSocket
  module Services
    module OpenAI
      def self.client
        @client ||= ::OpenAI::Client.new(access_token: BubbleSocket::Settings.config.openai_api_key)
      end
    end
  end
end
