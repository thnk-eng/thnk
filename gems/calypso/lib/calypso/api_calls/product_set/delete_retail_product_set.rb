require 'httparty'
require 'dotenv/load' # TODO: replace with envo

module ApiCalls
  def self.delete_retail_product_set(access_token, catalog_id, retail_product_set_id)
    base_url = ENV['API_BASE_URL']
    project_id = ENV['PROJECT_ID']

    response = HTTParty.delete(
      "#{base_url}/projects/#{project_id}/locations/us-central1/catalogs/#{catalog_id}/retailProductSets/#{retail_product_set_id}",
      headers: {
        "Authorization" => "Bearer #{access_token}"
      }
    )

    response.body
  end
end
