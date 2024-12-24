# lib/calypso/api_calls/inventory/get_inventory_by_id.rb
require 'httparty'

module Calypso
  module ApiCalls
    module Inventory
      class GetInventoryById
        include HTTParty

        def self.call(product_id)
          # Assuming you have a user or service to authenticate API calls
          user = CalypsoUser.first # Replace with appropriate logic

          response = HTTParty.get(
            "#{user.api_base_url}/projects/#{user.project_id}/locations/us-central1/inventory/#{product_id}",
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
            response.parsed_response
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
          logger.error("GetInventoryById Error: #{error.message}")
        end
      end
    end
  end
end
