# lib/calypso/api_calls/undeploy_product_recognition_index.rb
require 'httparty'
require 'dotenv/load'

module Calypso
  module ApiCalls
    class UndeployProductRecognitionIndex
      def self.call(access_token, catalog_id, endpoint_id)
        base_url = ENV['API_BASE_URL']
        project_id = ENV['PROJECT_ID']

        response = HTTParty.post(
          "#{base_url}/projects/#{project_id}/locations/us-central1/catalogs/#{catalog_id}/endpoints/#{endpoint_id}:undeployRetailProductRecognitionIndex",
          headers: {
            "Authorization" => "Bearer #{access_token}",
            "Content-Type" => "application/json"
          },
          body: {}.to_json
        )

        response.body
      end
    end
  end
end
