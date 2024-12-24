require 'httparty'
require 'dotenv/load' # TODO: replace with envo

module ApiCalls
  class RemoveProductsFromProductSet
    def self.remove_products_from_product_set(access_token, catalog_id, product_set_id, product_ids)
      base_url = ENV['API_BASE_URL']
      project_id = ENV['PROJECT_ID']

      response = HTTParty.post(
        "#{base_url}/projects/#{project_id}/locations/us-central1/catalogs/#{catalog_id}/productSets/#{product_set_id}:removeProducts",
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Content-Type" => "application/json"
        },
        body: { productIds: product_ids }.to_json
      )
      response.body
    end
  end
end

