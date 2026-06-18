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
# Targets (Mapping D-44-7 Akkreditierung / D-44-8 Mitgliedschaft):
#   :accredit           → akkreditieren   (nur aus :reported_only, via Toggle)
#   :deaccredit         → deakkreditieren (nur aus :accredited, via Toggle)
#   :ensure_participant → Teilnehmer sicherstellen (:not_in_tournament→cc_fast_assign,
#                         :reported_only→Toggle, sonst noop)
#   :remove_participant → Teilnehmer entfernen (:accredited→Toggle, :fast_assigned→cc_remove_tn,
#                         :reported_only→skip [nur gemeldet], :not_in_tournament→noop)
# Liest zuerst den Live-CC-Zustand (accreditation_state) und führt GENAU EINE zustandsabhängige
# atomare CC-Aktion aus — nur wenn nötig (idempotent). Schreibt einen AuditTrail-Eintrag.
# Endpoints/Payloads exakt aus cc_assign/cc_remove/cc_fast_assign wiederverwendet.
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

    action = plan_action(current)
    if action.is_a?(Array) && action.first == :skip
      return skip(action.last, current: current)
    elsif action == :noop
      audit(account, tc, player_cc_id, current, "noop")
      return result(:noop, current: current)
    end

    # action ∈ {:toggle, :fast_assign, :remove_tn} — genau EIN atomarer CC-POST.
    action_name, res, doc = perform_cc_action(action, client, tc, scope, player_cc_id, cookie)

    return cc_failure(account, tc, player_cc_id, current, "http_#{res&.code || "nil"}") if res.nil? || res.code != "200"

    parsed = Assign.parse_cc_error(doc)
    return cc_failure(account, tc, player_cc_id, current, parsed) if parsed && parsed != "(no error)"

    audit(account, tc, player_cc_id, current, "success:#{action_name}")
    result(:pushed, action: action, from: current)
  end

  private

  # Wählt die zustandsabhängige CC-Aktion für (target, current).
  # Rückgabe: :noop | :toggle | :fast_assign | :remove_tn | [:skip, reason]
  # (Mapping D-44-7 für :accredit/:deaccredit, D-44-8 für :ensure_participant/:remove_participant.)
  def plan_action(current)
    case @target
    when :accredit
      return :noop if current == :accredited
      return :toggle if current == :reported_only
      [:skip, :unsupported_state]
    when :deaccredit
      return :noop if current == :reported_only
      return :toggle if current == :accredited
      [:skip, :unsupported_state]
    when :ensure_participant
      return :noop if current == :accredited || current == :fast_assigned
      return :fast_assign if current == :not_in_tournament
      return :toggle if current == :reported_only
      [:skip, :unsupported_state]
    when :remove_participant
      return :toggle if current == :accredited
      return :remove_tn if current == :fast_assigned
      return :noop if current == :not_in_tournament
      return [:skip, :registration_only_not_removed] if current == :reported_only
      [:skip, :unsupported_state]
    else
      [:skip, :unknown_target]
    end
  end

  # Baut Endpoint + Payload zustandsabhängig (exakt wie cc_assign/cc_remove/cc_fast_assign)
  # und sendet GENAU EINEN atomaren POST (mit Reauth-Retry). Rückgabe: [action_name, res, doc].
  def perform_cc_action(action, client, tc, scope, player_cc_id, cookie)
    action_name, payload =
      case action
      when :toggle
        [TOGGLE_ACTION, Assign.base_payload(tc.cc_id, scope).except(:firstEntry).merge(pid: player_cc_id)]
      when :fast_assign
        ["cc_fast_assign", {meisterschaftsId: tc.cc_id, foundpid: player_cc_id, akkpid: "", fedId: scope[:fedId], branchId: scope[:branchId]}]
      when :remove_tn
        ["cc_remove_tn", Assign.base_payload(tc.cc_id, scope).except(:firstEntry).merge(dla: 1, akkpid: player_cc_id)]
      end

    res, doc = client.post(action_name, payload, {armed: true, session_id: cookie})
    if McpServer::CcSession.reauth_if_needed!(doc)
      res, doc = client.post(action_name, payload, {armed: true, session_id: cookie})
    end
    [action_name, res, doc]
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
