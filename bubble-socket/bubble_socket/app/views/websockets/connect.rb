# app/views/websockets/connect.rb
module BubbleSocket
  module Views
    module Websockets
      class Connect < BubbleSocket::View
        def render
          raw({ message: 'WebSocket connection established' }.to_json)
        end
      end
    end
  end
end
