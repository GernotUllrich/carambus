class AddIndex2ForUniqueness < ActiveRecord::Migration[6.1]
  def change
    # add_index :registration_ccs, ["player_id", "registration_list_cc_id"], unique: true
  end
end
