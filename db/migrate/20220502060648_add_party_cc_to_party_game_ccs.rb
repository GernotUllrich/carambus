class AddPartyCcToPartyGameCcs < ActiveRecord::Migration[6.1]
  def change
    add_column :party_game_ccs, :party_cc_id, :integer
  end
end
