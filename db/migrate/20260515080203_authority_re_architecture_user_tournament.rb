class AuthorityReArchitectureUserTournament < ActiveRecord::Migration[7.2]
  def up
    # D-14-G6 + D-14-G3: v0.4-Early-Phase, kein Live-Datensatz, kein concurrent-Index nötig (kleine DB).
    # safety_assured rechtfertigt Hard-DROP + Single-Transaction-Migration.
    safety_assured do
      remove_column :users, :mcp_role
      remove_column :users, :cc_credentials
      remove_column :users, :cc_region

      add_reference :tournaments, :turnier_leiter_user,
        foreign_key: {to_table: :users, on_delete: :nullify},
        null: true,
        index: true

      create_table :sportwart_locations do |t|
        t.references :user, null: false, foreign_key: {on_delete: :cascade}
        t.references :location, null: false, foreign_key: {on_delete: :cascade}
        t.timestamps
        t.index [:user_id, :location_id], unique: true, name: "idx_sportwart_locations_unique"
      end

      create_table :sportwart_disciplines do |t|
        t.references :user, null: false, foreign_key: {on_delete: :cascade}
        t.references :discipline, null: false, foreign_key: {on_delete: :cascade}
        t.timestamps
        t.index [:user_id, :discipline_id], unique: true, name: "idx_sportwart_disciplines_unique"
      end
    end
  end

  def down
    safety_assured do
      drop_table :sportwart_disciplines
      drop_table :sportwart_locations
      remove_foreign_key :tournaments, column: :turnier_leiter_user_id
      remove_index :tournaments, :turnier_leiter_user_id if index_exists?(:tournaments, :turnier_leiter_user_id)
      remove_column :tournaments, :turnier_leiter_user_id
      add_column :users, :cc_region, :string
      add_column :users, :cc_credentials, :text
      add_column :users, :mcp_role, :integer, default: 0, null: false
    end
  end
end
