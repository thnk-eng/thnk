require 'httparty'
require 'logger'

module Calypso
  module ApiCalls
    module Products
      class CreateProduct
        include HTTParty
        # Optional: Set base_uri if you frequently call the same base URL.
        # base_uri 'https://example.com/api'

        def self.call(user, product_name:, gtin:, catalog_id:)
          begin
            response = HTTParty.post(
              "#{user.api_base_url}/projects/#{user.project_id}/locations/us-central1/catalogs/#{catalog_id}/products",
              headers: {
                "Authorization" => "Bearer #{user.access_token}",
                "Content-Type" => "application/json"
              },
              body: {
                         product: {
                           name: product_name,
                           gtin: gtin
                         }
                       }.to_json,
              timeout: 10 # Set a timeout of 10 seconds
            )

            log_response(response)
            handle_response(response)
          rescue HTTParty::Error => e
            log_error(e)
            { error: 'httparty_error', message: e.message }
          rescue StandardError => e
            log_error(e)
            { error: 'standard_error', message: e.message }
          end
        end

      private

        # Handle response, including successful and failed ones
        def self.handle_response(response)
          if response.success?
            response.parsed_response
          else
            {
              error: response.code,
              message: response.message,
              details: response.parsed_response
            }
          end
        end

        # Optional: Logging responses for debugging purposes
        def self.log_response(response)
          logger.info("Response Code: #{response.code}")
          logger.info("Response Body: #{response.body}")
        end

        def self.log_error(error)
          logger.error("Error occurred: #{error.message}")
        end

        # Logger setup
        def self.logger
          @logger ||= Logger.new(STDOUT)
        end
      end
    end
  end
end
