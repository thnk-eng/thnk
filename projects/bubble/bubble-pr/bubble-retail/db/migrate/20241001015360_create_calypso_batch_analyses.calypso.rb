# This migration comes from calypso (originally 20240929120009)
class CreateCalypsoBatchAnalyses < ActiveRecord::Migration[7.2]
  def change
    create_table :calypso_batch_analyses do |t|
      t.string :input_file_uri
      t.string :output_uri_prefix

      t.timestamps
    end
  end
end
