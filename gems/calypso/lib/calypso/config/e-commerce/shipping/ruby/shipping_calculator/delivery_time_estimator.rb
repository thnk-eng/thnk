module ShippingCalculator
  class DeliveryTimeEstimator
    def self.estimate_delivery_times(destination, shipping_options)
      shipping_options.map do |option|
        carrier_api = get_carrier_api(option[:carrier])
        carrier_api.estimate_delivery_time(destination, option[:service])
      end
    end

  private

    def self.get_carrier_api(carrier)
      case carrier
        when "FedEx" then Carriers::FedExAPI
        when "UPS" then Carriers::UPSApi
        when "DHL" then Carriers::DHLApi
        else
          raise ArgumentError, "Unsupported carrier: #{carrier}"
      end
    end
  end
end