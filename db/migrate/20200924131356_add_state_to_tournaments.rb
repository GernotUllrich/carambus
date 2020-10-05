class AddStateToTournaments < ActiveRecord::Migration
  def change
    add_column :tournaments, :state, :string
    add_column :tournaments, :single_or_league, :string
  end
end
