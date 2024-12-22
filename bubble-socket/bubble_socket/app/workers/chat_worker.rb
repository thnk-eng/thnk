# app/workers/chat_worker.rb
module BubbleSocket
  module Workers
    class ChatWorker
      include GoodJob::ActiveJobExtensions::Concurrency

      good_job_control_concurrency_with(
        total_limit: 10,
        key: -> { "chat_worker" }
      )

      def perform(thread_id, messages)
        thread = BubbleSocket::Services::OpenAI.client.threads.retrieve(id: thread_id)

        messages.each do |message|
          BubbleSocket::Services::OpenAI.client.messages.create(
            thread_id: thread.id,
            role: 'user',
            content: message['content'],
            file_ids: message['file_ids']
          )
        end

        run = BubbleSocket::Services::OpenAI.client.runs.create(
          thread_id: thread.id,
          assistant_id: BubbleSocket::Settings.config.assistant_id
        )

        timeout = Time.now + 30 # 30 seconds timeout
        loop do
          run = BubbleSocket::Services::OpenAI.client.runs.retrieve(thread_id: thread.id, id: run.id)
          break if ['completed', 'failed'].include?(run.status) || Time.now > timeout
          sleep 1
        end

        raise "Assistant run failed or timed out" if run.status != 'completed'

        messages = BubbleSocket::Services::OpenAI.client.messages.list(thread_id: thread.id)
        assistant_response = messages.data.find { |msg| msg.role == 'assistant' }&.content&.first&.text&.value

        raise "No assistant response found" unless assistant_response

        sanitized_response = BubbleSocket::Services::ResponseSanitizer.sanitize(assistant_response)

        # Update session with new messages
        session = BubbleSocket::Services::SessionManager.get_or_create_session(thread_id)
        session[:messages] += messages.map { |msg| { role: msg.role, content: msg.content&.first&.text&.value } }
        BubbleSocket::Services::SessionManager.update_session(thread_id, session[:messages])

        # Publish the response to a Redis channel
        BubbleSocket::Services::Redis.with do |conn|
          conn.publish("chat_responses:#{thread_id}", { aiResponse: sanitized_response, threadId: thread_id }.to_json)
        end
      end
    end
  end
end
