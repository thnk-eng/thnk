module ShippingCalculator
  class CarrierRateFetcher
    def initialize(shipping_gateway:)
      @shipping_gateway = shipping_gateway
      @fedex_id = ENV['FEDEX_ID'] # => eafb37bfbc2f4126890d9c6e9b2ba31e
      @ups_id = ENV['UPS_ID']     # => 3f853c4667d44c0f9ff39654785f6264
      @dhl_id = ENV['DHL_ID']     # => 00252d1755ef49b4b4825a336754dd7a
    end
    def self.fetch_rates(destination, items)
      carriers = [Carriers::FedExAPI, Carriers::UPSApi, Carriers::DHLApi]

      carriers.flat_map do |carrier|
        carrier.get_rates(destination, items)
      end
    end
  end
end


require 'shippo'
Shippo::API.token = '<API_TOKEN>'

# Create address object
address_from = Shippo::Address.create(
  :name => "Shawn Ippotle",
  :company => "Shippo",
  :street1 => "Clayton St.",
  :street_no => "215",
  :street2 => "",
  :city => "San Francisco",
  :state => "CA",
  :zip => "94117",
  :country => "US",
  :phone => "+1 555 341 9393",
  :email => "shippotle@shippo.com"
)
