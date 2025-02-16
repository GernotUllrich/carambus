class AddIndexesForUniqueness < ActiveRecord::Migration[6.1]
  def change
    add_index :region_ccs, ["cc_id", "context"], unique: true
    add_index :branch_ccs, ["region_cc_id", "cc_id", "context"], unique: true
    add_index :competition_ccs, ["branch_cc_id", "cc_id", "context"], unique: true
    add_index :season_ccs, ["competition_cc_id", "cc_id", "context"], unique: true
  end
end
