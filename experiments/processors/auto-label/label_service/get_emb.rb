# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'mime/types'

module RubyChain
  class GetImgEmbed
    API_URL = 'https://api-atlas.nomic.ai/v1/embedding/image'

    def initialize(api_key)
      @api_key = api_key
    end

    def get_embedding(image_path, model = 'nomic-embed-vision-v1.5')
      uri = URI.parse(API_URL)
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@api_key}"
      request['Content-Type'] = 'multipart/form-data'

      form_data = [['model', model], ['images', File.open(image_path)]]

      request.set_form(form_data, 'multipart/form-data')

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(request)
      end

      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      else
        { error: response.message, code: response.code }
      end
    end

    def get_embeddings_from_directory(directory_path, output_file, model = 'nomic-embed-vision-v1.5')
      File.open(output_file, 'w') do |file|
        Dir.foreach(directory_path) do |filename|
          next if filename == '.' || filename == '..'

          image_path = File.join(directory_path, filename)
          if File.file?(image_path) && valid_image?(image_path)
            puts "Processing: #{image_path}"
            response = get_embedding(image_path, model)
            write_response_to_file(file, response, image_path)
          end
        end
      end
    end

  private

    def valid_image?(file_path)
      mime_type = MIME::Types.type_for(file_path).first
      mime_type && mime_type.media_type == 'image'
    end

    def write_response_to_file(file, response, image_path)
      response_data = { image_path: image_path, response: response }
      file.puts(response_data.to_json)
    end
  end
end

# Example usage:
# api_key = 'your_nomic_api_key'
# directory_path = '/path/to/your/images'
# output_file = 'embeddings.jsonl'
# embedder = RubyChain::GetImgEmbed.new(api_key)
# embedder.get_embeddings_from_directory(directory_path, output_file)
# Example usage:
