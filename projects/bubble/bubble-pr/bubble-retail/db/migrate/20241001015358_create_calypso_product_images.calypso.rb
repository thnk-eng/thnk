# This migration comes from calypso (originally 20240929120006)
class CreateCalypsoProductImages < ActiveRecord::Migration[7.2]
  def change
    create_table :calypso_product_images do |t|
      t.integer :product_id
      t.string :gcs_uri
      t.string :catalog_id

      t.timestamps
    end
  end
end
