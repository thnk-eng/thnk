# Load environment variables
require 'dotenv/load'
require_relative '../settings'

BubbleSocket::Settings.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.assistant_id = ENV['ASSISTANT_ID']
  config.redis_url = ENV['REDIS_URL']
  config.database_url = ENV['DATABASE_URL']
end
