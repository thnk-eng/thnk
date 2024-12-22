module BubbleSocket
  module Actions
    module Files
      class Upload < BubbleSocket::Action
        def handle(request, response)
          unless request.params[:file]
            response.status = 400
            response.render view('error', error: 'No file uploaded')
            return
          end

          file = request.params[:file]
          begin
            openai_response = BubbleSocket::Services::OpenAI.client.files.upload(
              parameters: { file: file[:tempfile], purpose: 'assistants' }
            )
            response.render view('success', file_id: openai_response.id)
          rescue => e
            response.status = 500
            response.render view('error', error: "Failed to upload file to OpenAI: #{e.message}")
          end
        end
      end
    end
  end
end
