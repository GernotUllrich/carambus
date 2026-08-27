# frozen_string_literal: true

# Phase 40-01 (Folgebefund 2026-08-25), dasselbe Muster wie 38-04 bei `club_locations`:
# `table_locals` hatte gar keinen Index auf `table_id`. `Table has_one :table_local` liefert
# damit bei mehreren Records je Tisch einen beliebigen — gemessen in der Test-DB, wo zwei
# Zugriffe im selben Test verschiedene Records lieferten. Betroffen ist die gesamte
# ortsgebundene Konfiguration: Scoreboard-IP, Tischheizung (tpl_ip_address, heater_*),
# Kalender-Event (event_*) und seit 40-01 die Grundsprache (locale).
#
# Die Anlegepfade prüfen zwar (`table.rb:53` per `table_local.presence ||`), aber nicht atomar —
# und `TableLocalsController#create` prüft gar nicht. Der Index schliesst die Lücke auf DB-Ebene.
#
# ⚠️ REIHENFOLGE: Diese Migration scheitert, solange Duplikate vorhanden sind. Auf jeder Instanz
# gehört vorher `rake data_hygiene:table_local_duplicates ARMED=1`. `table_locals` ist LOKAL
# (`ApiProtector`) und wird NICHT repliziert — anders als bei 38-04 räumt kein Sync die anderen
# Instanzen mit, jede muss einzeln bereinigt werden.
class AddUniqueIndexToTableLocals < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  INDEX_NAME = "index_table_locals_on_table_id"

  def up
    # Ein fehlgeschlagenes CREATE INDEX CONCURRENTLY laesst in PostgreSQL einen INVALIDEN Index
    # zurueck (pg_index.indisvalid = false). Der blockiert den naechsten Versuch mit
    # "relation already exists" und verdeckt die eigentliche Ursache (Duplikate). Aufgefallen
    # 2026-08-17 bei der gleichlautenden Migration fuer club_locations.
    remove_index :table_locals, name: INDEX_NAME, algorithm: :concurrently if index_name_exists?(:table_locals, INDEX_NAME)

    # Die Duplikate selbst entfernen, statt an ihnen zu scheitern — aus demselben Grund wie in
    # 38-04: der Standard-Deploy-Einzeiler enthaelt ein lokales `rails db:migrate`, und eine
    # Migration, die Handarbeit in rund zehn Checkouts mit je eigener Entwicklungs-DB verlangt,
    # ist keine Migration.
    #
    # ZWEI Schritte, anders als bei club_locations: ein ClubLocation ist ein FK-Paar ohne
    # Nutzlast, ein TableLocal traegt Konfiguration. Wer hier nur loescht, nimmt einem Tisch
    # still seine Heizungs-IP. Also erst retten, dann loeschen — dieselbe Regel wie im
    # Rake-Task (`data_hygiene:table_local_duplicates`), hier bewusst als reines SQL ohne
    # Modell und ohne Callbacks (Migrationen duerfen sich nicht auf den Modellstand verlassen).
    #
    # Nur die KONFIGURATIONS-Felder werden zusammengefuehrt. Die Zustandsfelder (heater_*,
    # scoreboard_*, event_*) bleiben, wie sie beim aeltesten Record stehen: ein aus zwei
    # Records gemischter Heizungszustand waere schlechter als ein leerer.
    #
    # `safety_assured`, weil strong_migrations nicht in ein `execute` hineinsieht. Vertretbar:
    # beide Statements sind auf exakte Duplikate derselben `table_id` begrenzt, behalten je
    # Tisch einen Eintrag, laufen je in einem Statement und sind idempotent (zweiter Lauf
    # trifft 0 Zeilen). `table_locals` hat auf keiner Instanz mehr als eine Handvoll Zeilen.
    safety_assured do
      execute(<<~SQL)
        UPDATE table_locals k
        SET ip_address     = COALESCE(NULLIF(k.ip_address, ''), d.ip_address),
            tpl_ip_address = COALESCE(NULLIF(k.tpl_ip_address, ''), d.tpl_ip_address),
            locale         = COALESCE(NULLIF(k.locale, ''), d.locale)
        FROM (
          SELECT table_id,
                 (array_remove(array_agg(NULLIF(ip_address, '')     ORDER BY id DESC), NULL))[1] AS ip_address,
                 (array_remove(array_agg(NULLIF(tpl_ip_address, '') ORDER BY id DESC), NULL))[1] AS tpl_ip_address,
                 (array_remove(array_agg(NULLIF(locale, '')         ORDER BY id DESC), NULL))[1] AS locale
          FROM table_locals
          WHERE table_id IS NOT NULL
          GROUP BY table_id
          HAVING count(*) > 1
        ) d
        WHERE k.table_id = d.table_id
          AND k.id = (SELECT min(m.id) FROM table_locals m WHERE m.table_id = k.table_id)
      SQL
    end

    deleted = safety_assured do
      execute(<<~SQL).cmd_tuples
        DELETE FROM table_locals a
        USING table_locals b
        WHERE a.table_id = b.table_id
          AND a.table_id IS NOT NULL
          AND a.id > b.id
      SQL
    end
    say "#{deleted} doppelte table_locals entfernt (aeltester Eintrag je Tisch bleibt)" if deleted.to_i.positive?

    # `table_id` ist NULL-bar; PostgreSQL laesst in einem Unique-Index beliebig viele NULLs zu.
    # Ein TableLocal ohne Tisch ist ohnehin funktionslos, aber nicht Gegenstand dieser Migration.
    add_index :table_locals, :table_id,
      unique: true,
      algorithm: :concurrently,
      name: INDEX_NAME
  end

  def down
    remove_index :table_locals, name: INDEX_NAME, algorithm: :concurrently if index_name_exists?(:table_locals, INDEX_NAME)
  end
end
