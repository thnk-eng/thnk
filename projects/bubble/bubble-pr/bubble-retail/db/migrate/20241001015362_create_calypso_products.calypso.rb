# This migration comes from calypso (originally 20240929123717)
class CreateCalypsoProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :calypso_products do |t|
      t.string :name
      t.string :gtin
      t.string :catalog_id
      t.text :description
      t.decimal  :price
      t.references :calypso_user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
