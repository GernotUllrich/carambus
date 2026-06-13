# frozen_string_literal: true

# D-14-G5: Sportwart-Wirkbereich.
#
# Gemixt in User. Stellt `in_sportwart_scope?(tournament)` bereit.
#
# D-38: Mitgliedschaft ist EXPLIZIT (sportwart? aus persona_grants), nicht aus Listen-Präsenz.
# - Kein Sportwart (persona_grants leer) → false.
# - `landessportwart` → ALLE Locations (region-weit); plain `sportwart` → NUR die explizit
#   gepflegten sportwart_locations (leere Locations ⇒ kein Scope — kein versehentliches „alle").
# - Disziplinen: leer = alle; sonst HIERARCHIE-bewusst via discipline.root_chain
#   („Karambol" deckt seine Sub-Disziplinen ab).
module SportwartScope
  extend ActiveSupport::Concern

  def in_sportwart_scope?(tournament)
    return false if tournament.nil?
    return false unless sportwart? # D-38: Mitgliedschaft EXPLIZIT über persona_grants

    disc_ids = sportwart_discipline_ids

    # D-38: landessportwart → ALLE Locations; plain sportwart → NUR explizite Locations
    # (leere Locations ⇒ kein Match — kein versehentliches „alle" durch Fehleingabe).
    location_match = landessportwart? || sportwart_location_ids.include?(tournament.location_id)
    # leer = alle Disziplinen; sonst HIERARCHIE-bewusst: „Karambol"(50) deckt Sub-Disziplinen
    # (z.B. Cadre 35/2, Dreiband) via discipline.root_chain ab.
    discipline_match = disc_ids.empty? ||
      (Array(tournament.discipline&.root_chain).map(&:id) & disc_ids).any?

    location_match && discipline_match
  end
end
