class RemoveOldFieldsFromTournaments < ActiveRecord::Migration[6.0]
  def change
    safety_assured { remove_column :tournaments, :time_out_stoke_preparation }
    safety_assured { remove_column :tournaments, :time_out_warm_up_first }
    safety_assured { remove_column :tournaments, :time_out_warm_up_folow_up }
  end
end
