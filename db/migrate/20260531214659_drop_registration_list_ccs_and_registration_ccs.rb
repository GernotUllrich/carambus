# frozen_string_literal: true

# Plan 23-01 T1b (Seeding-Unification): RL+RC werden gedroppt.
#
# Reihenfolge:
#   1. Spalte tournament_ccs.registration_list_cc_id (alter interner FK) raus —
#      meldeliste_cc_id auf TCc ist seit T1a die kanonische Speicherung.
#   2. Tabelle registration_ccs raus (hatte FK auf registration_list_ccs).
#   3. Tabelle registration_list_ccs raus.
#
# Down-Migration rekonstruiert die Strukturen ohne Daten — die echte
# Rollback-Strategie ist `git revert` der Code-Commits T2/T3a-T3e.
#
# Strong_migrations-konform:
#   - remove_column safe (kein Backfill nötig, Spalte ungeschützt durch Constraints)
#   - drop_table safe (Tests bereinigt, Code-Caller in T2/T3a-T3e entfernt)
#   - keine concurrent-Operation nötig (kein Index zu droppen außerhalb der Tabellen)
class DropRegistrationListCcsAndRegistrationCcs < ActiveRecord::Migration[7.2]
  def up
    safety_assured do
      if column_exists?(:tournament_ccs, :registration_list_cc_id)
        remove_column :tournament_ccs, :registration_list_cc_id
      end
    end
    drop_table :registration_ccs if table_exists?(:registration_ccs)
    drop_table :registration_list_ccs if table_exists?(:registration_list_ccs)
  end

  def down
    create_table :registration_list_ccs do |t|
      t.integer :cc_id
      t.string :context
      t.string :name
      t.integer :branch_cc_id
      t.integer :season_id
      t.integer :discipline_id
      t.integer :category_cc_id
      t.datetime :deadline, precision: nil
      t.datetime :qualifying_date, precision: nil
      t.text :data
      t.string :status
      t.timestamps
    end

    create_table :registration_ccs do |t|
      t.integer :registration_list_cc_id
      t.integer :player_id
      t.string :status
      t.timestamps
      t.index [:player_id, :registration_list_cc_id], unique: true,
        name: "index_registration_ccs_on_player_id_and_registration_list_cc_id"
    end

    add_column :tournament_ccs, :registration_list_cc_id, :integer
  end
end
