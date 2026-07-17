class CreateUserTournaments < ActiveRecord::Migration[7.2]
  def change
    create_table :user_tournaments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tournament, null: false, foreign_key: {on_delete: :cascade}
      t.string :role, null: false, default: "turnier_leiter"

      t.timestamps
    end
    add_index :user_tournaments, [:user_id, :tournament_id, :role],
      unique: true, name: "index_user_tournaments_unique"
  end
end
