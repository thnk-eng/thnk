# lib/calypso/api_calls/deploy_product_recognition_index.rb
require 'httparty'
require 'dotenv/load'

module Calypso
  module ApiCalls
    class DeployProductRecognitionIndex
      def self.call(access_token, catalog_id, endpoint_id, index_id)
        base_url = ENV['API_BASE_URL']
        project_id = ENV['PROJECT_ID']

        response = HTTParty.post(
          "#{base_url}/projects/#{project_id}/locations/us-central1/catalogs/#{catalog_id}/endpoints/#{endpoint_id}:deployRetailProductRecognitionIndex",
          headers: {
            "Authorization" => "Bearer #{access_token}",
            "Content-Type" => "application/json"
          },
          body: {
            retailProductRecognitionIndex: "projects/#{project_id}/locations/us-central1/catalogs/#{catalog_id}/productRecognitionIndexes/#{index_id}"
          }.to_json
        )

        response.body
      end
    end
  end
end
