# lib/calypso/api_calls/batch_analyze.rb
require 'httparty'
require 'dotenv/load'

module Calypso
  module ApiCalls
    class BatchAnalyze
      def self.call(access_token, catalog_id, endpoint_id, input_file_uri, output_uri_prefix)
        base_url = ENV['API_BASE_URL']
        project_id = ENV['PROJECT_ID']

        response = HTTParty.post(
          "#{base_url}/projects/#{project_id}/locations/us-central1/endpoints/#{endpoint_id}:batchAnalyze",
          headers: {
            "Authorization" => "Bearer #{access_token}",
            "Content-Type" => "application/json"
          },
          body: {
            gcsSource: {
              uris: [input_file_uri]
            },
            outputGcsDestination: {
              outputUriPrefix: output_uri_prefix
            },
            features: [
              {
                type: "TYPE_PRODUCT_RECOGNITION"
              }
            ]
          }.to_json
        )

        response.body
      end
    end
  end
end
