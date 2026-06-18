# frozen_string_literal: true

# Plan 44-03 (Phase 44 — atomarer lokal→CC-Sync): Finalisiert die CC-Meldeliste
# (releaseMeldeliste), wenn der TL die Teilnehmerliste lokal abschließt (finish_seeding).
# MCP-frei (aufrufbar aus Job), unter Per-User-CC-Identität (Phase 39).
#
# Verwendung:
#   Tournament::CcSync::FinalizePush.call(tournament: tournament, acting_user: user)
#
# Sendet GENAU EINEN releaseMeldeliste-POST (Payload + Endpoint exakt aus
# cc_finalize_teilnehmerliste gespiegelt). Bereits-finalisiert / CC-Fehler werden
# tolerant als {status: :error, reason:} zurückgegeben (kein Crash; lokaler State führt).
#
# Rückgabe-Hash {status:, reason?}:
#   :finalized  releaseMeldeliste gesendet (HTTP 200, kein CC-Fehler)
#   :skipped    nicht ausführbar (reason: :no_tournament_cc / :no_meldeliste / :no_cc_credentials)
#   :error      CC-Fehler (reason: Detail) — auch „bereits finalisiert"
class Tournament::CcSync::FinalizePush < ApplicationService
  FINALIZE_ACTION = "releaseMeldeliste"
  Assign = McpServer::Tools::AssignPlayerToTeilnehmerliste

  def initialize(kwargs = {})
    @tournament = kwargs[:tournament]
    @acting_user = kwargs[:acting_user]
  end

  def call
    tc = @tournament&.tournament_cc
    return skip(:no_tournament_cc) if tc.nil?

    meldeliste_cc_id = tc.meldeliste_cc_id
    return skip(:no_meldeliste) if meldeliste_cc_id.blank?

    account = McpServer::CcAccountResolver.resolve(user: @acting_user, tournament: @tournament)
    return skip(:no_cc_credentials) unless account.resolved?

    scope = Assign.resolve_scope_filters(tc.cc_id, nil, nil, tc.season.presence, "*", "*", server_context: nil)
    client = McpServer::CcSession.client_for(nil)
    cookie = McpServer::CcSession.cookie_for(account)

    payload = {
      branchId: scope[:branchId],
      fedId: scope[:fedId],
      season: scope[:season],
      meldelisteId: meldeliste_cc_id,
      release: ""
    }
    res, doc = client.post(FINALIZE_ACTION, payload, {armed: true, session_id: cookie})
    if McpServer::CcSession.reauth_if_needed!(doc)
      res, doc = client.post(FINALIZE_ACTION, payload, {armed: true, session_id: cookie})
    end

    return cc_failure(account, tc, meldeliste_cc_id, "http_#{res&.code || "nil"}") if res.nil? || res.code != "200"

    parsed = Assign.parse_cc_error(doc)
    return cc_failure(account, tc, meldeliste_cc_id, parsed) if parsed && parsed != "(no error)"

    audit(account, tc, meldeliste_cc_id, "success")
    result(:finalized)
  end

  private

  def result(status, **extra)
    {status: status}.merge(extra)
  end

  def skip(reason, **extra)
    result(:skipped, reason: reason, **extra)
  end

  def cc_failure(account, tc, meldeliste_cc_id, detail)
    audit(account, tc, meldeliste_cc_id, "cc-error")
    result(:error, reason: detail)
  end

  def audit(account, tc, meldeliste_cc_id, outcome)
    McpServer::AuditTrail.write_entry(
      tool_name: "cc_sync.finalize_push",
      operator: account.login_username,
      payload: {tournament_cc_id: tc.cc_id, meldeliste_cc_id: meldeliste_cc_id},
      pre_validation_results: [{name: "finalize", ok: true}],
      read_back_status: :skipped,
      result: outcome,
      user_id: account.acting_user_id
    )
  rescue => e
    Rails.logger.warn "[FinalizePush] audit failed (defensive): #{e.class}: #{e.message}"
  end
end
