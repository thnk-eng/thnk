# lib/calypso/api_calls/products/list_products.rb
require 'httparty'

module Calypso
  module ApiCalls
    module Products
      class ListProducts
        include HTTParty

        def self.call(user_id)
          user = CalypsoUser.find(user_id)
          response = HTTParty.get(
            "#{user.api_base_url}/projects/#{user.project_id}/locations/us-central1/catalogs/#{user.catalog_id}/products",
            headers: {
              "Authorization" => "Bearer #{user.access_token}",
              "Content-Type" => "application/json"
            },
            timeout: 10
          )

          handle_response(response)
        rescue HTTParty::Error => e
          log_error(e)
          { error: 'httparty_error', message: e.message }
        rescue StandardError => e
          log_error(e)
          { error: 'standard_error', message: e.message }
        end

      private

        def self.handle_response(response)
          if response.success?
            response.parsed_response['products']
          else
            {
              error: response.code,
              message: response.message,
              details: response.parsed_response
            }
          end
        end

        def self.log_error(error)
          logger = Logger.new(STDOUT)
          logger.error("ListProducts Error: #{error.message}")
        end
      end
    end
  end
end
