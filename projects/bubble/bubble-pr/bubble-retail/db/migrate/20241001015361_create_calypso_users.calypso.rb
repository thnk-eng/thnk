# This migration comes from calypso (originally 20240929123716)
class CreateCalypsoUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :calypso_users do |t|
      t.string :name
      t.string :access_token
      t.string :project_id
      t.string :api_base_url

      t.timestamps
    end
  end
end
