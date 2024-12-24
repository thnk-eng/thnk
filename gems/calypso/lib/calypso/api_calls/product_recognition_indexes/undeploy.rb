# lib/calypso/api_calls/undeploy.rb
require 'httparty'

module Calypso
  module ApiCalls
    module ProductRecognitionIndexes
      class Undeploy
        def self.call(user, catalog_id:, endpoint_id:)
          response = HTTParty.post(
            "#{user.api_base_url}/projects/#{user.project_id}/locations/us-central1/catalogs/#{catalog_id}/endpoints/#{endpoint_id}:undeployRetailProductRecognitionIndex",
            headers: {
              "Authorization" => "Bearer #{user.access_token}",
              "Content-Type" => "application/json"
            },
            body: {}.to_json
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
