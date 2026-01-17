class AddAllowOverflowToTournamentLocals < ActiveRecord::Migration[7.2]
  def change
    add_column :tournament_locals, :allow_overflow, :boolean, default: false, null: false
  end
end
