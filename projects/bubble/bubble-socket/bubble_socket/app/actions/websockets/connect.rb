# app/actions/websockets/connect.rb
require 'faye/websocket'

module BubbleSocket
  module Actions
    module Websockets
      class Connect < BubbleSocket::Action
        def handle(request, response)
          if Faye::WebSocket.websocket?(request.env)
            ws = Faye::WebSocket.new(request.env)

            ws.on :message do |event|
              begin
                data = JSON.parse(event.data)
                thread_id = data['thread_id'] || SecureRandom.uuid
                BubbleSocket::Workers::ChatWorker.perform_later(thread_id, data['messages'])

                # Subscribe to Redis channel for responses
                Thread.new do
                  BubbleSocket::Services::Redis.with do |conn|
                    conn.subscribe("chat_responses:#{thread_id}") do |on|
                      on.message do |channel, msg|
                        ws.send(msg)
                      end
                    end
                  end
                end

                ws.send({ threadId: thread_id }.to_json)
              rescue => e
                ws.send({ error: e.message }.to_json)
              end
            end

            ws.on :close do |event|
              puts "WebSocket connection closed"
            end

            ws.rack_response
          else
            response.status = 400
            response.body = "Bad Request"
          end
        end
      end
    end
  end
end
