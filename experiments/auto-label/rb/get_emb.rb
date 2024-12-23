require 'net/http'
require 'uri'
require 'json'
require 'mime/types'
require 'thread'
require 'logger'

module RubyChain
  class GetImgEmbed
    API_URL = 'https://api-atlas.nomic.ai/v1/embedding/image'

    def initialize(api_key, concurrency: 5, logger: Logger.new(STDOUT))
      @api_key = api_key
      @concurrency = concurrency
      @logger = logger
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
    rescue StandardError => e
      { error: e.message, code: 'Exception' }
    end

    def get_embeddings_from_directory(directory_path, output_file, model = 'nomic-embed-vision-v1.5')
      image_files = Dir.glob(File.join(directory_path, '*')).select { |f| valid_image?(f) }

      @logger.info "Found #{image_files.size} image(s) in '#{directory_path}'. Starting processing..."

      queue = Queue.new
      image_files.each { |file| queue << file }

      File.open(output_file, 'w') do |file|
        threads = []
        @concurrency.times do
          threads << Thread.new do
            until queue.empty?
              image_path = queue.pop(true) rescue nil
              next unless image_path

              @logger.info "Processing: #{image_path}"
              response = get_embedding(image_path, model)
              write_response_to_file(file, response, image_path)
            end
          end
        end
        threads.each(&:join)
      end

      @logger.info "Processing complete. Embeddings saved to '#{output_file}'."
    end

  private

    def valid_image?(file_path)
      mime_type = MIME::Types.type_for(file_path).first
      mime_type && mime_type.media_type == 'image'
    end

    def write_response_to_file(file, response, image_path)
      response_data = { image_path: image_path, response: response }
      @mutex ||= Mutex.new
      @mutex.synchronize { file.puts(response_data.to_json) }
    end
  end
end

api_key = ENV['NOMIC_API_KEY']
directory_path = 'dl_imgs'
output_file = 'embeddings2.jsonl'
concurrency_level = 5 # TURN DOWN TO 3 OR RATE LIMIT WILL BE HIT @ AROUND 1100
embedder = RubyChain::GetImgEmbed.new(api_key, concurrency: concurrency_level)
embedder.get_embeddings_from_directory(directory_path, output_file)
