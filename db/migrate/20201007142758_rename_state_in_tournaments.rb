class RenameStateInTournaments < ActiveRecord::Migration
  def change
    rename_column :tournaments, :state, :plan_or_show
  end
end
