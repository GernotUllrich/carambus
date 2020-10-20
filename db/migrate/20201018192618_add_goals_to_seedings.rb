class AddGoalsToSeedings < ActiveRecord::Migration
  def change
    add_column  :seedings, :balls_goal, :integer
    add_column  :seedings, :playing_discipline_id, :integer
  end
end
