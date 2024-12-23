# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'csv'
require 'open3'

module LabelService
  class VisionAPI
    INITIAL_DELAY = 1
    MAX_RETRIES = 5
    MAX_THREADS = 8

    def initialize(image_dir, output_dir)
      @image_dir = image_dir
      @output_dir = output_dir
      @queue = Queue.new
      validate_directories
    end

    def process_images
      create_output_directory
      image_files = Dir.glob(File.join(@image_dir, '*')).select { |file| file_file?(file) && image_file?(file) }

      if image_files.empty?
        puts "No image files found in #{@image_dir}."
        return
      end

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

      FileUtils.mkdir_p(@output_dir) unless Dir.exist?(@output_dir)
    end

    def create_output_directory
      FileUtils.mkdir_p(@output_dir) unless Dir.exist?(@output_dir)
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
        # Execute the gcloud command and capture stdout and stderr
        stdout, stderr, status = Open3.capture3("gcloud ml vision detect-labels #{shell_escape(image_path)}")

        if status.success?
          File.write(output_file, stdout)
          puts "Successfully processed #{image_path}"
          return
        else
          puts "API call failed for #{image_path}. Error: #{stderr.strip}. Retrying in #{delay} seconds..."
          sleep delay
          delay *= 2
          retries += 1
        end
      end

      puts "Failed to process #{image_name} after #{max_retries} retries."
    end

    def generate_dataset
      csv_file = File.join(@output_dir, "dataset.csv")
      CSV.open(csv_file, "wb") do |csv|
        csv << ["name/handle", "image_url", "labels"]

        Dir.glob(File.join(@output_dir, '*.json')).each do |json_file|
          json_data = JSON.parse(File.read(json_file))
          labels = extract_labels(json_data)

          name_handle = File.basename(json_file, ".json")
          image_path = find_image_path(name_handle)
          image_url = image_path ? "file://#{image_path}" : "N/A"

          csv << [name_handle, image_url, labels]
        end
      end

      puts "Dataset CSV generated at #{csv_file}"
    end

    def extract_labels(json_data)
      annotations = json_data.dig("responses", 0, "labelAnnotations")
      if annotations && annotations.is_a?(Array)
        annotations.map { |label| label["description"] }.join(", ")
      else
        ""
      end
    end

    def find_image_path(name_handle)
      Dir.glob(File.join(@image_dir, "#{name_handle}.*")).find { |path| File.file?(path) }
    end

    # Helper method to safely escape shell arguments
    def shell_escape(str)
      "'" + str.gsub("'", "'\\\\''") + "'"
    end

    # Helper method to check if a file is an image based on extension
    def image_file?(file)
      %w[.jpg .jpeg .png .gif .bmp .tiff .webp].include?(File.extname(file).downcase)
    end

    # Helper method to check if a path is a file
    def file_file?(file)
      File.file?(file)
    end
  end
end

# Usage example:
image_dir = 'dl_imgs'         # Directory where images are stored
output_dir = 'dl_imgs/labels' # Directory where label JSONs and CSV will be stored

processor = LabelService::VisionAPI.new(image_dir, output_dir)
processor.process_images
