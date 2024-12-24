require 'httparty'
require 'dotenv/load' # TODO: replace with envo

module Calypso
  module ApiCalls
    class ListProductSets
      def self.call(access_token, catalog_id)
        base_url = ENV['API_BASE_URL']
        project_id = ENV['PROJECT_ID']

        response = HTTParty.get(
          "#{base_url}/projects/#{project_id}/locations/us-central1/catalogs/#{catalog_id}/productSets",
          headers: {
            "Authorization" => "Bearer #{access_token}"
          }
        )

        response.body
      end
    end
  end
end
