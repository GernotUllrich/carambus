class AddClearTextAttributesToTournamentCcs < ActiveRecord::Migration[7.0]
  def change
    add_column :tournament_ccs, :branch_cc_name, :string
    add_column :tournament_ccs, :category_cc_name, :string
    add_column :tournament_ccs, :championship_type_cc_name, :string
  end
end
