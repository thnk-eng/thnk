
# app/services/session_manager.rb
module BubbleSocket
  module Services
    module SessionManager
      def self.get_or_create_session(thread_id)
        BubbleSocket::Services::Redis.with do |conn|
          session = conn.get("session:#{thread_id}")
          if session
            JSON.parse(session, symbolize_names: true)
          else
            new_session = { thread_id: thread_id, messages: [] }
            conn.set("session:#{thread_id}", new_session.to_json)
            new_session
          end
        end
      end

      def self.update_session(thread_id, messages)
        BubbleSocket::Services::Redis.with do |conn|
          session = get_or_create_session(thread_id)
          session[:messages] = messages.last(10) # Keep only last 10 messages
          conn.set("session:#{thread_id}", session.to_json)
        end
      end
    end
  end
end
