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

    # Die Duplikate selbst entfernen, statt an ihnen zu scheitern.
    #
    # Grund (2026-08-17): Der Standard-Deploy-Einzeiler enthaelt ein lokales `rails db:migrate`.
    # Scheitert das an Duplikaten, kommt der Deploy nie zustande — und zwar in JEDEM der rund
    # zehn Checkouts einzeln, jeder mit eigener Entwicklungs-DB und eigener Historie (gemessen:
    # 9 Gruppen in carambus, 6 in carambus_api, 5 in carambus_nbv). Eine Migration, die
    # Handarbeit auf zehn Maschinen verlangt, ist keine Migration.
    #
    # Bewusst reines SQL: kein ActiveRecord-Modell (Migrationen duerfen sich nicht auf den
    # jeweils aktuellen Modellstand verlassen), keine Callbacks, ein Statement. Die Regel ist
    # dieselbe wie in `data_hygiene:club_location_duplicates`: je (club_id, location_id) bleibt
    # die KLEINSTE id — der urspruengliche Eintrag, die spaeteren sind Import-Artefakte.
    #
    # Auf der Authority ist das ein No-op: dort wurde bereits per `.destroy` bereinigt (mit
    # PaperTrail-Versionen, die die Loeschung an die Regional-Server replizieren). Instanzen,
    # die den Sync bekommen, sind daher ebenfalls schon sauber; hier greift es nur bei DBs
    # ausserhalb des Sync-Wegs — also den lokalen Entwicklungs-Datenbanken.
    # `safety_assured`, weil strong_migrations nicht in ein `execute` hineinsehen kann. Vertretbar:
    # das DELETE ist auf exakte Duplikate derselben (club_id, location_id) begrenzt, behaelt je
    # Kombination einen Eintrag, laeuft in einem Statement und ist idempotent (zweiter Lauf trifft
    # 0 Zeilen). Ein Tabellen-Lock entsteht nur fuer die wenigen betroffenen Zeilen.
    deleted = safety_assured do
      execute(<<~SQL).cmd_tuples
        DELETE FROM club_locations a
        USING club_locations b
        WHERE a.club_id = b.club_id
          AND a.location_id = b.location_id
          AND a.id > b.id
      SQL
    end
    say "#{deleted} doppelte club_locations entfernt (aeltester Eintrag je Kombination bleibt)" if deleted.to_i.positive?

    add_index :club_locations, %i[club_id location_id],
      unique: true,
      algorithm: :concurrently,
      name: INDEX_NAME
  end

  def down
    remove_index :club_locations, name: INDEX_NAME, algorithm: :concurrently if index_name_exists?(:club_locations, INDEX_NAME)
  end
end
