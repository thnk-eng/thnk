require 'httparty'
require 'dotenv/load'

module ApiCalls
  def self.get_product_recognition_config(access_token)
    base_url = ENV['API_BASE_URL']
    project_id = ENV['PROJECT_ID']

    response = HTTParty.get(
      "#{base_url}/projects/#{project_id}/locations/us-central1/retailProductRecognitionConfig",
      headers: {
        "Authorization" => "Bearer #{access_token}"
      }
    )

    response.body
  end
end
