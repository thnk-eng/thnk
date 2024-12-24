# app.rb

require 'sinatra'
require_relative 'create_product'
require_relative 'list_products'
require_relative 'delete_product'
# ... require all other Ruby files similarly

post '/create_product' do
  data = JSON.parse(request.body.read)
  access_token = data['access_token']
  catalog_id = data['catalog_id']
  product_id = data['product_id']
  gtin = data['gtin']

  result = ApiCalls.create_product(access_token, catalog_id, product_id, gtin)
  content_type :json
  result
end

get '/list_products' do
  access_token = params['access_token']
  catalog_id = params['catalog_id']

  result = ApiCalls.list_products(access_token, catalog_id)
  content_type :json
  result
end

delete '/delete_product' do
  data = JSON.parse(request.body.read)
  access_token = data['access_token']
  catalog_id = data['catalog_id']
  product_id = data['product_id']

  result = ApiCalls.delete_product(access_token, catalog_id, product_id)
  content_type :json
  result
end

# ... define routes for other operations similarly
