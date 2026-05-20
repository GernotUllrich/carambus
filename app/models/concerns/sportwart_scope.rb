# frozen_string_literal: true

# D-14-G5: Sportwart-Wirkbereich.
#
# Gemixt in User. Stellt `in_sportwart_scope?(tournament)` bereit:
# Schnittmenge aus Location-Liste + Disziplin-Liste des Users gegen Tournament.location_id +
# tournament.discipline_id. Leere Wirkbereichs-Listen werden als „kein Sportwart" interpretiert
# (Rückgabe false), nicht als „alle erlaubt".
#
# Edge-Case: User hat *nur* Locations gepflegt → wirkt als „alle Disziplinen erlaubt für diese
# Locations" (und umgekehrt). Beide leer → false.
module SportwartScope
  extend ActiveSupport::Concern

  def in_sportwart_scope?(tournament)
    return false if tournament.nil?
    loc_ids = sportwart_location_ids
    disc_ids = sportwart_discipline_ids
    return false if loc_ids.empty? && disc_ids.empty?

    location_match = loc_ids.empty? || loc_ids.include?(tournament.location_id)
    discipline_match = disc_ids.empty? || disc_ids.include?(tournament.discipline_id)
    location_match && discipline_match
  end
end
