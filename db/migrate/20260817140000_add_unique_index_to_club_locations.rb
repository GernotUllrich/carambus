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

  INDEX_NAME = "index_club_locations_on_club_id_and_location_id"

  def up
    # Ein fehlgeschlagenes CREATE INDEX CONCURRENTLY laesst in PostgreSQL einen INVALIDEN Index
    # zurueck (pg_index.indisvalid = false). Der blockiert den naechsten Versuch mit
    # "relation already exists" — ein Folgefehler, der die eigentliche Ursache (Duplikate)
    # verdeckt. Aufgefallen 2026-08-17 auf dem carambus-Checkout.
    remove_index :club_locations, name: INDEX_NAME, algorithm: :concurrently if index_name_exists?(:club_locations, INDEX_NAME)

    add_index :club_locations, %i[club_id location_id],
      unique: true,
      algorithm: :concurrently,
      name: INDEX_NAME
  end

  def down
    remove_index :club_locations, name: INDEX_NAME, algorithm: :concurrently if index_name_exists?(:club_locations, INDEX_NAME)
  end
end
