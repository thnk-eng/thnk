require 'json'
require 'csv'

# Directory containing both images and JSON files
DIR = 'dl_imgs'
OUTPUT_CSV = 'output.csv'

def parse_json_file(file_path)
  file = File.read(file_path)
  data = JSON.parse(file)
  labels = data.dig("responses", 0, "labelAnnotations") || []
  labels.map do |label|
    [label["description"], label["score"], label["topicality"]]
  end
end

def generate_csv
  max_labels = 0
  all_data = []

  # First pass to determine the maximum number of labels
  Dir.foreach(DIR) do |filename|
    next if filename == '.' || filename == '..' || File.extname(filename) != '.jpg'

    json_filename = filename + ".json"
    json_path = File.join(DIR, json_filename)

    if File.exist?(json_path)
      labels = parse_json_file(json_path)
      max_labels = [max_labels, labels.length].max
      all_data << [filename, labels.flatten]
    else
      puts "JSON file for #{filename} not found."
    end
  end

  # Generate the CSV with appropriate header and rows
  CSV.open(OUTPUT_CSV, "wb") do |csv|
    # Header row
    header = ["Image"]
    max_labels.times do |i|
      header += ["Label #{i+1} Description", "Label #{i+1} Score", "Label #{i+1} Topicality"]
    end
    csv << header

    # Data rows
    all_data.each do |image_data|
      filename, labels = image_data
      csv << [filename, *labels]
    end
  end
end

generate_csv
puts "CSV file generated at #{OUTPUT_CSV}"
