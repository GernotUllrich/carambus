class AddTimeOutValuesToTournament < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :time_out_stoke_preparation, :integer
    add_column :tournaments, :time_out_warm_up_first, :integer
    add_column :tournaments, :time_out_warm_up_folow_up, :integer
  end
end
