class AddTimeOutValuesToParties < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :time_out_stoke_preparation_sec, :integer
    change_column_default :parties, :time_out_stoke_preparation_sec, 45
    add_column :parties, :time_out_warm_up_first_min, :integer
    change_column_default :parties, :time_out_warm_up_first_min, 5
    add_column :parties, :time_out_warm_up_follow_up_min, :integer
    change_column_default :parties, :time_out_warm_up_follow_up_min, 3
  end
end
