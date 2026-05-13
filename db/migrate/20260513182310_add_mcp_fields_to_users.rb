# frozen_string_literal: true

class AddMcpFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    # MCP Multi-User-Hosting (v0.3, Plan 13-02, D-13-01-D Option-B-Override).
    # Separates `mcp_role`-Feld neben existierendem Carambus-`role`-Enum
    # (player/club_admin/system_admin) — keine Vermischung der Auth-Layer.
    add_column :users, :mcp_role, :integer, default: 0, null: false
    add_column :users, :cc_region, :string
    add_column :users, :cc_credentials, :text # encrypted at rest via Rails 7 `encrypts` (D-13-01-E DSGVO minimal-pragmatic)

    # NOTE: Index auf mcp_role deferred zu separater Migration mit `disable_ddl_transaction! + algorithm: :concurrently`
    # (strong_migrations-Konvention); für v0.3 dev/staging mit kleiner users-Tabelle keine Performance-Notwendigkeit.
  end
end
