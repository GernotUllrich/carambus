# frozen_string_literal: true

# Lokale Kontaktdaten zu einem Spieler.
#
# ⚠️ BEWUSST eine eigene Tabelle statt einer Spalte auf `players`: `players` ist eine GLOBALE
# Tabelle (id < MIN_ID), die von der Authority gesynct wird — eine Adresse dort landete beim
# naechsten Sync auf allen Servern, und `LocalProtector` verhindert lokale Aenderungen an
# globalen Records ohnehin.
#
# Diese Tabelle bleibt strukturell lokal: der Sync ist ein reiner PULL von der Authority
# (`Version.get_from_carambus_api`), und das Modell traegt `ApiProtector` — auf der Authority
# rollt dessen after_save-Guard jeden Schreibvorgang zurueck. Die Tabelle existiert dort nach
# dieser Migration zwar, bleibt aber garantiert leer.
#
# Vorbild: `table_locals` (ortsgebundene Tischkonfiguration, gleiches Muster).
class CreatePlayerLocals < ActiveRecord::Migration[7.2]
  def change
    create_table :player_locals do |t|
      # Genau ein Datensatz je Spieler — der Unique-Index ist das atomare Gegenstueck zur
      # Modell-Validierung.
      t.references :player, null: false, foreign_key: true, index: {unique: true}

      t.string :email

      # Einwilligung in die Vereinskommunikation, mit Widerruf. Zwei Zeitpunkte statt eines
      # Boolean: so bleibt belegbar, WANN zugestimmt bzw. widerrufen wurde — ein Flag verliert
      # diese Information beim Umschalten.
      t.datetime :consent_given_at
      t.datetime :consent_revoked_at

      t.timestamps
    end

    # Lokale Records fuehren IDs >= MIN_ID — dieselbe Konvention wie `table_locals` (dessen
    # Sequence steht ebenfalls auf 50_000_000). Hier ist das Konvention, kein Schutzmechanismus:
    # ⚠️ der Schreibschutz haengt NICHT an der ID, sondern an der Rolle des Servers
    # (`PlayerLocal#nur_auf_lokalem_server`). Ein ID-basierter Guard waere zerbrechlich, weil
    # der Startwert einer Sequence nicht in `schema.rb` steht und ein `db:schema:load` ihn auf
    # 1 zuruecksetzt.
    #
    # MIN_ID literal statt `Seeding::MIN_ID`: eine Migration soll nicht von Modellcode abhaengen,
    # der sich spaeter aendern kann.
    # `reversible`, weil ein blankes `execute` in `change` nicht zurueckrollbar ist. Ein `down`
    # braucht es nicht: beim Rollback faellt die Tabelle und mit ihr die Sequence.
    reversible do |dir|
      dir.up do
        execute "SELECT setval(pg_get_serial_sequence('player_locals', 'id'), 50000000, true)"
      end
    end
  end
end
