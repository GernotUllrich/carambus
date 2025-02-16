class AddMore < ActiveRecord::Migration[7.0]
  def change
    add_column :tournament_locals, :innings_goal, :integer
    add_column :tournament_locals, :balls_goal, :integer
  end
end
