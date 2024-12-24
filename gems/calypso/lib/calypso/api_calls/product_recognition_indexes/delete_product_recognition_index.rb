# lib/calypso/api_calls/delete_product_recognition_index.rb
require 'httparty'
require 'dotenv/load'

module Calypso
  module ApiCalls
    class DeleteProductRecognitionIndex
      def self.call(access_token, catalog_id, index_id)
        base_url = ENV['API_BASE_URL']
        project_id = ENV['PROJECT_ID']

        response = HTTParty.delete(
          "#{base_url}/projects/#{project_id}/locations/us-central1/catalogs/#{catalog_id}/productRecognitionIndexes/#{index_id}",
          headers: {
            "Authorization" => "Bearer #{access_token}"
          }
        )

        response.body
      end
    end
  end
end
