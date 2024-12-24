require 'httparty'
require 'dotenv/load'

module Narada
  module Calypso
    module ProductImage
      module ApiCalls
        def self.list_product_images(access_token, catalog_id, product_id)
          base_url = ENV['API_BASE_URL']
          project_id = ENV['PROJECT_ID']

          response = HTTParty.get(
            "#{base_url}/projects/#{project_id}/locations/us-central1/catalogs/#{catalog_id}/products/#{product_id}/images",
            headers: {
              "Authorization" => "Bearer #{access_token}"
            }
          )

          response.body
        end
      end
    end
  end
end