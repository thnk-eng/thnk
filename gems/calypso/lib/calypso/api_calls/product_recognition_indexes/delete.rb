# lib/calypso/api_calls/product_recognition_indexes/delete.rb
require 'httparty'

module Calypso
  module ApiCalls
    module ProductRecognitionIndexes
      class Delete
        def self.call(user, catalog_id:, recognition_index_id:)
          response = HTTParty.delete(
            "#{user.api_base_url}/projects/#{user.project_id}/locations/us-central1/catalogs/#{catalog_id}/productRecognitionIndexes/#{recognition_index_id}",
            headers: {
              "Authorization" => "Bearer #{user.access_token}"
            }
          )

          handle_response(response)
        end

        def self.handle_response(response)
          return true if response.success?

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
