require_relative 'products/create_product'
require_relative 'products/delete_product'

module Calypso
  module Products
    include HTTParty
    base_uri ''

  end
end