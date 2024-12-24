module ShippingCalculator
  class PackageOptimizer
    def self.optimize(items)
      Services::PackingAlgorithm.optimize(items)
    end
  end
end
