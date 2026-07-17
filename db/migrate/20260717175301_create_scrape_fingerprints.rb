# frozen_string_literal: true

# Scrape-Fingerprints: normalisierte Inhalts-Hashes je gescrapter Ressource, zur Change-Detection
# (gestaffelte Hashes, „Scrape- & Sync-Effizienz"). Ebene C = Standings je League: unveränderter
# digest ⇒ keine neuen Ergebnisse ⇒ Deep-Scrape (Begegnungen/Spielberichte) überspringbar.
# Polymorph, damit später auch Ebene A/B (Saison-Selektor/Ligen-Liste) und andere Quellen andocken.
class CreateScrapeFingerprints < ActiveRecord::Migration[7.2]
  def change
    create_table :scrape_fingerprints do |t|
      t.references :fingerprintable, polymorphic: true, null: false, index: false
      t.string :scope, null: false          # z. B. "standings"
      t.string :digest, null: false         # SHA256-Hex des normalisierten Inhalts
      t.datetime :checked_at, null: false    # letzter Prüfzeitpunkt (adaptive Kadenz)
      t.datetime :changed_at                 # wann der digest zuletzt kippte
      t.timestamps
    end

    # Ein Fingerprint je (Ressource, scope). Index auf der frisch erstellten (leeren) Tabelle → safe.
    add_index :scrape_fingerprints,
      [:fingerprintable_type, :fingerprintable_id, :scope],
      unique: true, name: "idx_scrape_fingerprints_owner_scope"
  end
end
