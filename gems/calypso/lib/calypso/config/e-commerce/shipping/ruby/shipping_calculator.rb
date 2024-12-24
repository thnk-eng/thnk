require 'date'
require 'json'
require 'net/http'
require 'uri'

require_relative 'shipping_calculator/frontend_to_shipping_calculator'
require_relative 'shipping_calculator/carrier_rate_fetcher'
require_relative 'shipping_calculator/delivery_time_estimator'
require_relative 'shipping_calculator/package_optimizer'
require_relative 'shipping_calculator/customs_documentation_generator'
require_relative 'shipping_calculator/carriers/fedex_api'
require_relative 'shipping_calculator/carriers/ups_api'
require_relative 'shipping_calculator/carriers/dhl_api'
require_relative 'shipping_calculator/services/customs_regulations'
require_relative 'shipping_calculator/services/packing_algorithm'
require_relative 'shipping_calculator/services/customs_doc_service'

module ShippingCalculator
  class FrontendToShippingCalculator
    ENDPOINT = '/api/shipping'
    METHOD = 'POST'

    def self.calculate(params)
      validate_params(params)

      destination = params[:destination]
      items = params[:items]

      shipping_options = CarrierRateFetcher.fetch_rates(destination, items)
      total_weight = calculate_total_weight(items)
      estimated_delivery_dates = DeliveryTimeEstimator.estimate_delivery_times(destination, shipping_options)
      optimized_package = PackageOptimizer.optimize(items)
      customs_docs = CustomsDocumentationGenerator.generate(destination, items) if requires_customs_documentation?(destination)

      {
        shipping_options: shipping_options.map.with_index { |option, index|
          option.merge(estimated_delivery: estimated_delivery_dates[index])
        },
        total_weight: total_weight,
        optimized_package: optimized_package,
        customs_documentation: customs_docs,
        message: "Shipping options calculated successfully"
      }
    end

  private

    def self.validate_params(params)
      raise ArgumentError, "Missing required parameter: destination" unless params[:destination]
      raise ArgumentError, "Missing required parameter: items" unless params[:items]

      validate_destination(params[:destination])
      validate_items(params[:items])
    end

    def self.validate_destination(destination)
      raise ArgumentError, "Invalid destination format" unless destination.is_a?(Hash)
      raise ArgumentError, "Missing country in destination" unless destination[:country]
      raise ArgumentError, "Missing postal_code in destination" unless destination[:postal_code]
    end

    def self.validate_items(items)
      raise ArgumentError, "Items must be an array" unless items.is_a?(Array)
      items.each do |item|
        raise ArgumentError, "Invalid item format" unless item.is_a?(Hash)
        raise ArgumentError, "Missing product_id in item" unless item[:product_id]
        raise ArgumentError, "Missing quantity in item" unless item[:quantity]
        raise ArgumentError, "Missing weight in item" unless item[:weight]
        validate_dimensions(item[:dimensions]) if item[:dimensions]
      end
    end

    def self.validate_dimensions(dimensions)
      raise ArgumentError, "Invalid dimensions format" unless dimensions.is_a?(Hash)
      [:length, :width, :height].each do |dim|
        raise ArgumentError, "Missing #{dim} in dimensions" unless dimensions[dim]
      end
    end

    def self.calculate_total_weight(items)
      items.sum { |item| item[:weight] * item[:quantity] }
    end

    def self.requires_customs_documentation?(destination)
      Services::CustomsRegulations.requires_documentation?(destination[:country])
    end
  end
end

