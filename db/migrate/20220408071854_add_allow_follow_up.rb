class AddAllowFollowUp < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :allow_follow_up, :boolean, default: true, null: false
    add_column :tournament_locals, :allow_follow_up, :boolean, default: true, null: false
    add_column :tournament_monitors, :allow_follow_up, :boolean, default: true, null: false
  end
end
