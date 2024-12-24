# lib/calypso/api_calls/delete_product_image.rb
require 'httparty'
require 'dotenv/load'

module Calypso
  module ApiCalls
    module ProductImage
      class DeleteProductImage
        def self.call(access_token, catalog_id, product_id, product_image_id)
          base_url = ENV['API_BASE_URL']
          project_id = ENV['PROJECT_ID']

          response = HTTParty.delete(
            "#{base_url}/projects/#{project_id}/locations/us-central1/catalogs/#{catalog_id}/products/#{product_id}/images/#{product_image_id}",
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
