module BubbleSocket
  module Actions
    module Home
      class Index < BubbleSocket::Action
        def handle(request, response)
          response.render view
        end
      end
    end
  end
end
