# app/services/redis.rb
require 'connection_pool'
require 'redis'

module BubbleSocket
  module Services
    module Redis
      def self.connection_pool
        @connection_pool ||= ConnectionPool.new(size: 5, timeout: 5) do
          ::Redis.new(url: BubbleSocket::Settings.config.redis_url)
        end
      end

      def self.with(&block)
        connection_pool.with(&block)
      end
    end
  end
end
