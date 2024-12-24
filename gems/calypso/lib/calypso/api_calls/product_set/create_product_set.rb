require 'httparty'
require 'dotenv/load' # TODO: replace with envo

module Calypso
  module ApiCalls
    module ProductSet
      class CreateProductSet
        def self.call(access_token, catalog_id, product_set_id)
          base_url = ENV['API_BASE_URL']
          project_id = ENV['PROJECT_ID']

          response = HTTParty.post(
            "#{base_url}/projects/#{project_id}/locations/us-central1/catalogs/#{catalog_id}/productSets",
            headers: {
              "Authorization" => "Bearer #{access_token}",
              "Content-Type" => "application/json"
            },
            body: {
                       productSet: {
                         name: "projects/#{project_id}/locations/us-central1/catalogs/#{catalog_id}/productSets/#{product_set_id}"
                       }
                     }.to_json
          )

          response.body
        end
      end
    end
  end
end
