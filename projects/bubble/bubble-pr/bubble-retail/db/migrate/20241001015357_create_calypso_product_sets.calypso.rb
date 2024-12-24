# This migration comes from calypso (originally 20240929120005)
class CreateCalypsoProductSets < ActiveRecord::Migration[7.2]
  def change
    create_table :calypso_product_sets do |t|
      t.string :name
      t.string :catalog_id

      t.timestamps
    end
  end
end
