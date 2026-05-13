# frozen_string_literal: true

# v0.3 Plan 13-05 (D-13-01-D Multi-User-Filtering):
# DB-Persistent-Audit-Trail für jeden armed:true Tool-Call.
# Ersetzt JSON-Lines-only-Pattern aus Plan 10-05.1 (D-10-04-D) durch
# Defense-in-Depth: DB-Insert + parallel JSON-Lines-File-Write.
#
# 8-Feld-Schema (erweitert um user_id für HTTP-Multi-User-Filterung):
#   - user_id (HTTP-Pfad → User.id; Stdio-Pfad → nil)
#   - operator (CC-Login-User aus cc_session.cc_login_user)
#   - tool_name, payload, pre_validation_results, read_back_status, result
class McpAuditTrail < ApplicationRecord
  belongs_to :user, optional: true

  scope :for_user, ->(user) { where(user_id: user.is_a?(User) ? user.id : user) }
  scope :for_tool, ->(name) { where(tool_name: name) }
  scope :recent, ->(limit = 100) { order(created_at: :desc).limit(limit) }
  scope :armed_writes, -> { where("payload->>'armed' = ?", "true") }
end
