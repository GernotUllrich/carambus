class CreateTournamentLocal < ActiveRecord::Migration[6.0]
  def change
    create_table :tournament_locals do |t|
      t.integer :tournament_id
      t.integer :timeout
      t.integer :timeouts
      t.boolean :admin_controlled
      t.boolean :gd_has_prio
    end
  end
end
