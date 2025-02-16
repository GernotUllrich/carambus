class AddStaffelToLeagueCc < ActiveRecord::Migration[6.1]
  def change
    add_column :league_ccs, :cc_id2, :integer
  end
end
