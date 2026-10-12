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

  # Turnierausführung (Teilnehmerliste, Turnierleitung): Disziplin UND Spielort.
  def in_sportwart_scope?(tournament)
    return false unless in_sportwart_discipline_scope?(tournament)

    # D-38: landessportwart → ALLE Locations; plain sportwart → NUR explizite Locations
    # (leere Locations ⇒ kein Match — kein versehentliches „alle" durch Fehleingabe).
    landessportwart? || sportwart_location_ids.include?(tournament.location_id)
  end

  # Meldeliste (2026-09-15, Betreiber-Vorgabe): Ein Sportwart verwaltet die Meldelisten ALLER
  # Turniere der Region in seiner Disziplin — ohne Spielort- und Club-Beschränkung (wie die CC,
  # die nur auf Region + Branch einschränkt). Der Spielort zählt nur für die Turnierausführung.
  # Region: Turniere werden im Regions-Kontext des Servers aufgelöst.
  def in_sportwart_discipline_scope?(tournament)
    return false if tournament.nil?
    return false unless sportwart? # D-38: Mitgliedschaft EXPLIZIT über persona_grants

    disc_ids = sportwart_discipline_ids
    # leer = alle Disziplinen; sonst HIERARCHIE-bewusst: „Karambol"(50) deckt Sub-Disziplinen
    # (z.B. Cadre 35/2, Dreiband) via discipline.root_chain ab.
    disc_ids.empty? || (Array(tournament.discipline&.root_chain).map(&:id) & disc_ids).any?
  end

  # Plan 20-02: Liga-Spieltag — nur die Disziplin der Liga zaehlt, das Spiellokal nicht
  # (Betreiber-Vorgabe 2026-09-19, Muster wie die Meldeliste). Grund: die meisten Spieltage tragen
  # kein Spiellokal, und ein Sportwart soll jeden Spieltag seiner Disziplin leiten koennen.
  def in_sportwart_party_scope?(party)
    return false if party.nil?

    in_sportwart_discipline_scope?(party.league)
  end
end
