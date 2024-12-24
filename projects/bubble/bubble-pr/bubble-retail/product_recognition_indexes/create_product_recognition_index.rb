# lib/calypso/api_calls/create_product_recognition_index.rb
require 'httparty'

module Calypso
  module ApiCalls
    class CreateProductRecognitionIndex
      def self.call(user, index_name:, catalog_id:)
        response = HTTParty.post(
          "#{user.api_base_url}/projects/#{user.project_id}/locations/us-central1/catalogs/#{catalog_id}/productRecognitionIndexes",
          headers: {
            "Authorization" => "Bearer #{user.access_token}",
            "Content-Type" => "application/json"
          },
          body: {
                     index: {
                       name: index_name
                     }
                   }.to_json
        )

        handle_response(response)
      end

      def self.handle_response(response)
        return response.parsed_response if response.success?

        {
          error: response.code,
          message: response.message,
          details: response.parsed_response
        }
      end
    end
  end
end
