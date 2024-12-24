# lib/calypso/api_calls/product_recognition_indexes/list.rb
require 'httparty'

module Calypso
  module ApiCalls
    module ProductRecognitionIndexes
      class List
        def self.call(user, catalog_id:)
          response = HTTParty.get(
            "#{user.api_base_url}/projects/#{user.project_id}/locations/us-central1/catalogs/#{catalog_id}/productRecognitionIndexes",
            headers: {
              "Authorization" => "Bearer #{user.access_token}"
            }
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
end
