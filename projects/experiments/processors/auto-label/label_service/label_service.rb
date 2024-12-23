# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'csv'
require 'net/http'
require 'uri'
require 'open3'
require 'dotenv'


module LabelService
  class VisionAPI
    INITIAL_DELAY = 1
    MAX_RETRIES = 5
    MAX_THREADS = 8
    NOMIC_API_KEY = ENV['NOMIC_API_KEY']
    NOMIC_MODEL = 'nomic-embed-vision-v1.5'

    def initialize(image_dir, output_dir, input_type, input_file)
      @image_dir = image_dir
      @output_dir = output_dir
      @input_type = input_type
      @input_file = input_file
      @queue = Queue.new
      validate_directories
    end

    def process_images
      download_and_resize_images
      create_output_directory
      image_files = Dir.glob(File.join(@image_dir, '*')).select { |file| File.file?(file) }

      image_files.each { |image_path| @queue.push(image_path) }

      threads = Array.new(MAX_THREADS) do
        Thread.new do
          while !@queue.empty?
            image_path = @queue.pop(true) rescue nil
            if image_path
              process_image(image_path, @output_dir, INITIAL_DELAY, MAX_RETRIES)
            end
          end
        end
      end

      threads.each(&:join)

      puts "Processing complete. Outputs are in #{@output_dir}"
      generate_dataset
    end

  private

    def validate_directories
      unless Dir.exist?(@image_dir)
        raise ArgumentError, "Image directory does not exist: #{@image_dir}"
      end

      unless Dir.exist?(@output_dir)
        FileUtils.mkdir_p(@output_dir)
      end
    end

    def create_output_directory
      FileUtils.mkdir_p(@output_dir) unless Dir.exist?(@output_dir)
    end

    def download_and_resize_images
      command = "./speedgo #{@input_type} #{@input_file} #{@image_dir}"
      system(command)
    end

    def process_image(image_path, output_dir, initial_delay, max_retries)
      call_vision_api(image_path, output_dir, initial_delay, max_retries)
    end

    def call_vision_api(image_path, output_dir, initial_delay, max_retries)
      delay = initial_delay
      retries = 0
      image_name = File.basename(image_path)
      output_file = File.join(output_dir, "#{image_name}.json")

      while retries <= max_retries
        success = Open3.capture3("gcloud ml vision detect-labels #{image_path} > #{output_file}")
        return if success[2].success?

        puts "API call failed for #{image_path}. Retrying in #{delay} seconds..."
        sleep delay
        delay *= 2
        retries += 1
      end

      puts "Failed to process #{image_name} after #{max_retries} retries."
    end

    def generate_dataset
      csv_file = File.join(@output_dir, "dataset.csv")
      CSV.open(csv_file, "wb") do |csv|
        csv << ["name/handle", "image_url", "labels", "embedding"]

        Dir.glob(File.join(@output_dir, '*.json')).each do |json_file|
          json_data = JSON.parse(File.read(json_file))
          labels = json_data.dig("responses", 0, "labelAnnotations")&.map { |label| label["description"] }&.join(", ") || ""
          embedding = generate_embedding_from_file(json_file)

          name_handle = File.basename(json_file, ".json")
          image_url = "file://#{File.join(@image_dir, name_handle)}"

          csv << [name_handle, image_url, labels, embedding]
        end
      end
    end

    def generate_embedding_from_file(image_path)
      uri = URI("https://api-atlas.nomic.ai/v1/embedding/image")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{NOMIC_API_KEY}"
      request.set_form({ "model" => NOMIC_MODEL, "images" => File.open(image_path) }, "multipart/form-data")

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)['embeddings'][0].join(", ")
      else
        puts "Failed to generate embedding for image: #{image_path}"
        Array.new(768, 0).join(", ")  # Return a zero vector as a placeholder
      end
    end
  end
end

# Usage example:
image_dir = ''
output_dir = ''
input_type = 'txt'  # or 'yaml'
input_file = ''

processor = LabelService::VisionAPI.new(image_dir, output_dir, input_type, input_file)
processor.process_images
