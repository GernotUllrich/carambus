class AddCIdToParty < ActiveRecord::Migration[6.1]
  def change
    add_column :parties, :cc_id, :integer
  end
end
