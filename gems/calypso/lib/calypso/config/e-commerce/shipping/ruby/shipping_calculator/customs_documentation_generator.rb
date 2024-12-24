module ShippingCalculator
  class CustomsDocumentationGenerator
    def self.generate(destination, items)
      Services::CustomsDocService.generate_documentation(destination, items)
    end
  end
end
