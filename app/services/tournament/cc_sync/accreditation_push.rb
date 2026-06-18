# frozen_string_literal: true

# Plan 44-01 (Phase 44 — atomarer lokal→CC-Sync): Schreibt eine lokale TL-Akkreditierungs-
# Änderung atomar und idempotent in die ClubCloud zurück. MCP-frei — aufrufbar aus Job/Reflex
# (KEINE MCP::Tool::Response, KEINE LLM-Prosa, KEIN armed-Dry-Run).
#
# Verwendung:
#   Tournament::CcSync::AccreditationPush.call(
#     tournament: tournament, player: player, target: :accredit, acting_user: user
#   )
#
# Mapping (D-44-7):
#   target :accredit   → Spieler soll Teilnehmer sein   (CC-Zustand :accredited)
#   target :deaccredit → Spieler soll nur gemeldet sein (CC-Zustand :reported_only)
# Umgesetzt über den bestehenden atomaren showMeldeliste_teilnahme-Toggle (HAR-Goldvorlage,
# wiederverwendet aus cc_assign/cc_remove). Liest zuerst den Live-CC-Zustand und togglet NUR,
# wenn Ist ≠ Ziel (idempotent). Schreibt einen AuditTrail-Eintrag.
#
# Identität (Phase 39): die effektive CC-Identität wird über CcAccountResolver aufgelöst
# (:own / :tl_inherited); ohne eigene/vererbte Credentials (:none) wird NICHT geschrieben.
#
# Rückgabe-Hash {status:, ...}:
#   :pushed   Toggle gesendet         · :noop    bereits im Zielzustand (kein POST)
#   :skipped  nicht ausführbar (reason: :no_tournament_cc / :no_player_cc_id /
#             :no_cc_credentials / :unsupported_state)
#   :error    CC-Fehler (reason: Detail)
class Tournament::CcSync::AccreditationPush < ApplicationService
  TOGGLE_ACTION = "showMeldeliste_teilnahme"
  Assign = McpServer::Tools::AssignPlayerToTeilnehmerliste

  def initialize(kwargs = {})
    @tournament = kwargs[:tournament]
    @player = kwargs[:player]
    @target = kwargs[:target]&.to_sym
    @acting_user = kwargs[:acting_user]
  end

  def call
    tc = @tournament&.tournament_cc
    return skip(:no_tournament_cc) if tc.nil?

    player_cc_id = @player&.cc_id
    return skip(:no_player_cc_id) if player_cc_id.blank?

    account = McpServer::CcAccountResolver.resolve(user: @acting_user, tournament: @tournament)
    return skip(:no_cc_credentials) unless account.resolved?

    scope = Assign.resolve_scope_filters(tc.cc_id, nil, nil, tc.season.presence, "*", "*", server_context: nil)
    client = McpServer::CcSession.client_for(nil)
    cookie = McpServer::CcSession.cookie_for(account)

    info = Assign.accreditation_state(client, tc.cc_id, scope, player_cc_id)
    return result(:error, reason: info[:error]) if info[:error]
    current = info[:state]

    case toggle_decision(current)
    when :noop
      audit(account, tc, player_cc_id, current, "noop")
      return result(:noop, current: current)
    when :unsupported
      return skip(:unsupported_state, current: current)
    end

    # :toggle — genau EIN atomarer Toggle-POST (spiegelt cc_assign/cc_remove, Plan 33-01).
    payload = Assign.base_payload(tc.cc_id, scope).except(:firstEntry).merge(pid: player_cc_id)
    res, doc = client.post(TOGGLE_ACTION, payload, {armed: true, session_id: cookie})
    if McpServer::CcSession.reauth_if_needed!(doc)
      res, doc = client.post(TOGGLE_ACTION, payload, {armed: true, session_id: cookie})
    end

    return cc_failure(account, tc, player_cc_id, current, "http_#{res&.code || "nil"}") if res.nil? || res.code != "200"

    parsed = Assign.parse_cc_error(doc)
    return cc_failure(account, tc, player_cc_id, current, parsed) if parsed && parsed != "(no error)"

    audit(account, tc, player_cc_id, current, "success")
    result(:pushed, from: current, to: desired_state)
  end

  private

  def desired_state
    (@target == :accredit) ? :accredited : :reported_only
  end

  # Nur die zwei sauberen Toggle-Richtungen togglen; alles andere noop (bereits am Ziel)
  # oder unsupported (:fast_assigned / :not_in_tournament — Sonderpfade = 44-02).
  def toggle_decision(current)
    return :noop if current == desired_state
    if (@target == :accredit && current == :reported_only) ||
        (@target == :deaccredit && current == :accredited)
      :toggle
    else
      :unsupported
    end
  end

  def result(status, **extra)
    {status: status, target: @target}.merge(extra)
  end

  def skip(reason, **extra)
    result(:skipped, reason: reason, **extra)
  end

  def cc_failure(account, tc, player_cc_id, current, detail)
    audit(account, tc, player_cc_id, current, "cc-error")
    result(:error, reason: detail)
  end

  def audit(account, tc, player_cc_id, current, outcome)
    McpServer::AuditTrail.write_entry(
      tool_name: "cc_sync.accreditation_push",
      operator: account.login_username,
      payload: {tournament_cc_id: tc.cc_id, player_cc_id: player_cc_id, target: @target, from_state: current},
      pre_validation_results: [{name: "live_state_read", ok: true, from: current}],
      read_back_status: :skipped,
      result: outcome,
      user_id: account.acting_user_id
    )
  rescue => e
    Rails.logger.warn "[AccreditationPush] audit failed (defensive): #{e.class}: #{e.message}"
  end
end
