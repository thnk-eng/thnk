require 'date'
require 'json'
require 'net/http'
require 'uri'

module ShippingCalculator
  class ShippoAPI
    BASE_URL = 'https://api.goshippo.com'

    def initialize(api_key)
      @api_key = api_key
    end

    def create_shipment(params)
      uri = URI.parse("#{BASE_URL}/shipments/")
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "ShippoToken #{@api_key}"
      request['Content-Type'] = 'application/json'
      request.body = params.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      JSON.parse(response.body)
    end
  end

  class FrontendToShippingCalculator
    def initialize(api_key)
      @shippo_api = ShippoAPI.new(api_key)
    end

    def calculate(params)
      shipment_data = create_shipment_data(params)
      response = @shippo_api.create_shipment(shipment_data)

      {
        shipment_id: response['object_id'],
        status: response['status'],
        shipping_options: parse_rates(response['rates']),
        messages: response['messages']
      }
    end

  private

    def create_shipment_data(params)
      {
        address_from: params[:address_from],
        address_to: params[:address_to],
        parcels: params[:parcels],
        async: false
      }
    end

    def parse_rates(rates)
      rates.map do |rate|
        {
          carrier: rate['provider'],
          service: rate['servicelevel']['name'],
          amount: rate['amount'],
          currency: rate['currency'],
          estimated_days: rate['estimated_days'],
          arrives_by: rate['arrives_by']
        }
      end
    end
  end
end

# Example usage
if __FILE__ == $0
  calculator = ShippingCalculator::FrontendToShippingCalculator.new(ENV['SHIPPO_API_KEY'])

  params = {
    address_from: {
      name: "Mr. Hippo",
      street1: "215 Clayton St.",
      city: "San Francisco",
      state: "CA",
      zip: "94117",
      country: "US"
    },
    address_to: {
      name: "Mrs. Hippo",
      street1: "965 Mission St.",
      city: "San Francisco",
      state: "CA",
      zip: "94105",
      country: "US"
    },
    parcels: [{
                length: "5",
                width: "5",
                height: "5",
                distance_unit: "in",
                weight: "2",
                mass_unit: "lb"
              }]
  }

  result = calculator.calculate(params)
  puts JSON.pretty_generate(result)
end