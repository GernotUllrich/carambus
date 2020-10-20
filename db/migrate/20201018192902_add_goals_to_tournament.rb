class AddGoalsToTournament < ActiveRecord::Migration
  def change
    add_column :tournaments, :innings_goal, :integer
    add_column  :tournaments, :balls_goal, :integer
    add_column  :tournaments, :handicap_tournier, :boolean
  end
end
