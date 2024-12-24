# This migration comes from calypso (originally 20240929120002)
class EnableUuid < ActiveRecord::Migration[7.2]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
  end
end
