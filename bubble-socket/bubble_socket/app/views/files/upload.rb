# app/views/files/upload.rb
module BubbleSocket
  module Views
    module Files
      class Upload < BubbleSocket::View
        def render
          raw case params[:status]
          when 'error'
            { error: params[:error] }.to_json
          when 'success'
            { file_id: params[:file_id] }.to_json
          end
        end
      end
    end
  end
end
