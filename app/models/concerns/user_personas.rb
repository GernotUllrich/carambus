# frozen_string_literal: true

# v1.0 Phase 34-01: Persona-/Capability-Ableitung.
#
# Leitet die Personas eines Users ab: role-Enum + EXPLIZITE Sportwart-Persona-Grants
# (D-38: Spalte users.persona_grants, "sportwart"/"landessportwart") + Turnierleitung
# (Tournament.turnier_leiter_user_id ODER UserTournament).
#
# D-38 (Reversal von D-34-2): sportwart? kommt jetzt aus der EXPLIZITEN persona_grants-Spalte
# (nur system_admin setzbar), nicht mehr emergent aus Join-Präsenz. SportwartScope
# (in_sportwart_scope?) bleibt fuer die turnierspezifische Scope-Pruefung zustaendig
# (verfeinert via sportwart_locations/-disciplines); dieser Concern beantwortet "welche Persona?".
#
# CC-Schreibrecht (cc_write_access?) = system_admin ODER Sportwart ODER Turnierleiter
# (D-34-1, User-Entscheidung v1.0). club_admin und reiner player sind NICHT
# schreibberechtigt (im Chat read-only).
module UserPersonas
  extend ActiveSupport::Concern

  # True wenn dem User eine Sportwart-Persona EXPLIZIT zugewiesen wurde (D-38):
  # persona_grants enthält "sportwart" ODER "landessportwart". Beide zählen fürs
  # CC-Schreibrecht (User: „auch der LSW kann Meldungen entgegennehmen").
  # NICHT mehr aus der Join-Präsenz abgeleitet (kein versehentliches Sportwart-Werden).
  def sportwart?
    (Array(persona_grants) & %w[sportwart landessportwart]).any?
  end

  # True wenn der User die region-weite Persona "landessportwart" hat
  # (→ alle Locations der Region; SportwartScope#in_sportwart_scope? wertet das aus).
  def landessportwart?
    Array(persona_grants).include?("landessportwart")
  end

  # True wenn der User turnier_leiter mindestens eines Tournaments ist.
  # Guard gegen id=nil (unsaved User): sonst matcht exists?(turnier_leiter_user_id: nil)
  # alle Tournaments OHNE Turnierleiter und liefert faelschlich true.
  def turnierleiter?
    return @is_turnierleiter if defined?(@is_turnierleiter)
    @is_turnierleiter = id.present? && (
      Tournament.exists?(turnier_leiter_user_id: id) ||
      UserTournament.exists?(user_id: id, role: "turnier_leiter")
    )
  end

  # Abgeleitete Personas als Symbol-Array (für cc_whoami-Anzeige): Basis-Rolle (role) +
  # die EXPLIZITEN persona_grants (:sportwart bzw. :landessportwart) + :turnierleiter,
  # wenn zutreffend. So zeigt der Chat einen LSW als "landessportwart", nicht generisch "sportwart".
  def personas
    list = [role.to_sym]
    list += Array(persona_grants).reject(&:blank?).map(&:to_sym)
    list << :turnierleiter if turnierleiter?
    list.uniq
  end

  # CC-Schreibrecht: Sportwart + Turnierleiter + system_admin (D-34-1).
  # club_admin/player ohne Sportwart-Scope und ohne Turnier-Leitung => false.
  def cc_write_access?
    system_admin? || sportwart? || turnierleiter?
  end

  # Sichtbarkeit + Recht der CC-Datenabgleich-Aktionen (reload-from-cc) auf clubs/leagues:
  # CC-Schreibberechtigte (system_admin/Sportwart/Turnierleiter) PLUS club_admin (User-Entscheid S5 2026-07-07).
  def data_sync_access?
    cc_write_access? || club_admin?
  end
end
