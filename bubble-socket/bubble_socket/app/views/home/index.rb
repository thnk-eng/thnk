module BubbleSocket
  module Views
    module Home
      class Index < BubbleSocket::View
        def render
          raw {{ message: 'Welcome to Bubble Socket' }.to_json}
        end
      end
    end
  end
end
