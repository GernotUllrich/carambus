class AddCcidToLeagues < ActiveRecord::Migration[6.1]
  def change
    add_column :leagues, :cc_id, :integer
  end
end
