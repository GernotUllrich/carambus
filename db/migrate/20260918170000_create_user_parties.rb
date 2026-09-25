# frozen_string_literal: true

# Plan 20-02: Begegnungsleiter — lokale Zuordnung User x Party, analog user_tournaments.
# Party ist ein globaler Record (aus der ClubCloud), der PartyMonitor entsteht erst beim Start;
# der Sportwart soll den Leiter schon vor dem Spieltag einsetzen koennen.
class CreateUserParties < ActiveRecord::Migration[7.2]
  def up
    create_table :user_parties do |t|
      t.references :user, null: false, foreign_key: true
      t.references :party, null: false, foreign_key: {on_delete: :cascade}
      t.string :role, null: false, default: "party_leiter"
      t.bigint :granted_by_user_id, index: true

      t.timestamps
    end
    add_index :user_parties, [:user_id, :party_id, :role],
      unique: true, name: "index_user_parties_unique"
    # Lokale Records: IDs ab MIN_ID (wie Version.sequence_reset es fuer alle Tabellen setzt).
    safety_assured { execute "SELECT setval(pg_get_serial_sequence('user_parties', 'id'), 50000000, false)" }
  end

  def down
    drop_table :user_parties
  end
end
