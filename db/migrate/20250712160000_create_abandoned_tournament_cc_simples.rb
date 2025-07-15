class CreateAbandonedTournamentCcSimples < ActiveRecord::Migration[7.0]
  def change
    create_table :abandoned_tournament_cc_simples do |t|
      t.integer :cc_id, null: false
      t.string :context, null: false
      t.datetime :abandoned_at, null: false

      t.timestamps
    end

    add_index :abandoned_tournament_cc_simples, [:cc_id, :context], unique: true, name: 'index_abandoned_cc_simples_on_cc_id_context'
  end
end 