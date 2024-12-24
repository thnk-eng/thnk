require 'httparty'
require 'dotenv/load' # TODO: replace with envo

module Calypso
  module ApiCalls
    module ProductSet
      class AddProductsToProductSet
        def self.call(user, product_set_id:, product_ids:)
          response = HTTParty.post(
            "#{user.api_base_url}/projects/#{user.project_id}/locations/us-central1/catalogs/#{user.catalog_id}/productSets/#{product_set_id}:addProducts",
            headers: {
              "Authorization" => "Bearer #{user.access_token}",
              "Content-Type" => "application/json"
            },
            body: {
                       productIds: product_ids
                     }.to_json
          )

          handle_response(response)
        end

      private

        def self.handle_response(response)
          if response.success?
            response.body
          else
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
end

# # Fetch the user from the database
# user = User.find_by(name: 'John Doe')
#
# # Call the service to add products to the product set for this specific user
# Calypso::ApiCalls::AddProductsToProductSet.call(
#   user,
#   product_set_id: "your_product_set_id",
#   product_ids: ["product1", "product2"]
# )