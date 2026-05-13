# frozen_string_literal: true

# v0.3 Plan 13-05 (D-13-01-D Multi-User-Filtering):
# DB-Persistent-Audit-Trail-Tabelle für MCP-Multi-User-Hosting.
# Ergänzt Plan-10-05.1 JSON-Lines-File-Audit-Trail (Defense-in-Depth).
class CreateMcpAuditTrails < ActiveRecord::Migration[7.2]
  def change
    create_table :mcp_audit_trails do |t|
      t.references :user, null: true, foreign_key: {on_delete: :nullify}
      t.string :operator, null: false, default: "unknown"
      t.string :tool_name, null: false
      t.jsonb :payload, null: false, default: {}
      t.jsonb :pre_validation_results, default: []
      t.string :read_back_status
      t.string :result, null: false
      t.timestamps
    end

    add_index :mcp_audit_trails, :tool_name
    add_index :mcp_audit_trails, :created_at
  end
end
