# frozen_string_literal: true

# D-14-G4 + D-14-G5: Authority-Layer-Policy für Tournament-Sub-Operationen.
#
# Vier Predicates:
# - `assign_leiter?` — Sportwart (im Wirkbereich) kann TL für „sein" Turnier benennen
# - `update_deadline?` — TL für sein Turnier ODER Sportwart im Wirkbereich
# - `manage_teilnehmerliste?` — TL für sein Turnier ODER Sportwart im Wirkbereich
# - `enter_results?` — nur TL für sein Turnier (Sportwart darf KEINE Ergebnisse eintragen)
#
# 14-G.2 nutzt diese Policy in BaseTool-Authorization-Layer.
class TournamentPolicy < ApplicationPolicy
  # Plan 14-G.3 / F3-C: admin?-Bypass für assign_leiter? + update_deadline? +
  # manage_teilnehmerliste?. enter_results? bleibt strict (sysadmin schreibt
  # keine Ergebnisse via MCP — konzeptuell falsch).
  def assign_leiter?
    return false if user.nil?
    user.admin? || user.in_sportwart_scope?(record)
  end

  def update_deadline?
    tl_or_sportwart_or_admin?
  end

  def manage_teilnehmerliste?
    tl_or_sportwart_or_admin?
  end

  def enter_results?
    return false if user.nil?
    record.leiter?(user)
  end

  # Phase 42 Re-Plan-Spike (2026-06-16): cc_prepare_tournament — Tool synct
  # die Teilnehmerliste über Version.update_from_carambus_api und übergibt
  # dem Sportwart einen Link auf die Carambus-Web-Turniervorbereitung
  # (finalize_modus). KEIN direkter CC-Touch, KEIN destruktiver Pfad.
  def prepare_tournament?
    tl_or_sportwart_or_admin?
  end

  private

  def tl_or_sportwart_or_admin?
    return false if user.nil?
    user.admin? || record.leiter?(user) || user.in_sportwart_scope?(record)
  end
end
