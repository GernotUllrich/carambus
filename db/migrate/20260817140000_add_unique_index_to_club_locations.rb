# frozen_string_literal: true

# Phase 38-04: Die Eindeutigkeit von (club_id, location_id) hing bisher allein an der
# Rails-Validierung in ClubLocation. Alle drei Anlegepfade (region.rb:376, region.rb:796,
# location.rb:139) pruefen per `find_by` bzw. `find_or_create_by` — beides ist NICHT atomar.
# Zwischen Juli 2025 (6.–17.) sind so 6 Kombinationen mit je 5–6 Kopien entstanden; dass
# seither keine neue dazukam, liegt am ausbleibenden wiederholten Import-Lauf, nicht an
# einer Reparatur. Der Index schliesst die Luecke auf DB-Ebene.
#
# ⚠️ REIHENFOLGE: Diese Migration scheitert, solange Duplikate vorhanden sind. Auf jeder
# Instanz muss zuerst `rake data_hygiene:club_location_duplicates ARMED=1` gelaufen sein —
# auf der Authority direkt, auf den Regional-Servern ueber den Sync (die Loeschungen
# replizieren per PaperTrail-destroy-Version). Wer hier auf "PG::UniqueViolation" laeuft,
# hat eine Instanz vor sich, die die Bereinigung noch nicht bekommen hat.
class AddUniqueIndexToClubLocations < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :club_locations, %i[club_id location_id],
      unique: true,
      algorithm: :concurrently,
      name: "index_club_locations_on_club_id_and_location_id"
  end
end
