class AddInternationalSourceFkToTournaments < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    add_foreign_key :tournaments, :international_sources, validate: false
  end
end
