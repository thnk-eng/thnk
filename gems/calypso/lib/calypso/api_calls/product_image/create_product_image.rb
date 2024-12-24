# lib/calypso/api_calls/create_product_image.rb
require 'httparty'
require 'dotenv/load'

module Calypso
  module ApiCalls
    module ProductImage
      class CreateProductImage
        def self.call(access_token, catalog_id, product_id, product_image_id, image_gcs_uri)
          base_url = ENV['API_BASE_URL']
          project_id = ENV['PROJECT_ID']

          response = HTTParty.post(
            "#{base_url}/projects/#{project_id}/locations/us-central1/catalogs/#{catalog_id}/products/#{product_id}/images",
            headers: {
              "Authorization" => "Bearer #{access_token}",
              "Content-Type" => "application/json"
            },
            body: {
                       productImage: {
                         name: "projects/#{project_id}/locations/us-central1/catalogs/#{catalog_id}/products/#{product_id}/images/#{product_image_id}",
                         gcsUri: image_gcs_uri
                       }
                     }.to_json
          )

          response.body
        end
      end
    end
  end
end
