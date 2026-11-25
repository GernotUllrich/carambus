# frozen_string_literal: true

# Ein Verein kann in mehreren Regional-ClubClouds gelistet sein (z. B. ABG Trier-Mosel in BVRP und BVS, je mit
# eigener cc_id). clubs hat aber nur eine region_id/cc_id — der nächtliche Vereins-Scrape schrieb sie darum jede
# Nacht zwischen den Regionen hin und her, und der Liga-Scrape fand den Verein in der jeweils anderen Region
# nicht (Team übersprungen). club_cc_entries hält jede Listung fest. Server-lokale Scrape-Metadaten wie
# scrape_fingerprints: kein PaperTrail, keine Replikation.
#
# Befüllung aus dem heutigen Stand: clubs.region_id/cc_id = Heimat. Bei alten Dubletten auf (Region, cc_id)
# gewinnt der Verein, dessen source_url schon auf cbdet.php zeigt, sonst der zuletzt geänderte.
class CreateClubCcEntries < ActiveRecord::Migration[7.2]
  def up
    create_table :club_cc_entries do |t|
      t.references :club, null: false, index: true
      t.references :region, null: false, index: false
      t.integer :cc_id, null: false
      t.datetime :seen_at, null: false
      t.timestamps
    end
    add_index :club_cc_entries, [:region_id, :cc_id], unique: true

    # cc_id bevorzugt aus source_url (cbdet.php?a=…), die der Vereins-Scrape zusammen mit region_id setzt:
    # clubs.cc_id kann eine Fremd-cc_id tragen, die der Liga-Scrape der anderen Region hineingeschrieben hat
    # (2026-11-25: SV Motor Babelsberg, Region BBBV, cc_id 11201 = BVB-Nummer).
    safety_assured do
      execute <<~SQL
        INSERT INTO club_cc_entries (club_id, region_id, cc_id, seen_at, created_at, updated_at)
        SELECT DISTINCT ON (x.region_id, x.cc_id) x.id, x.region_id, x.cc_id, now(), now(), now()
        FROM (
          SELECT y.id, y.region_id, y.updated_at, (y.url_cc_id IS NOT NULL AND y.cbdet) AS via_cbdet,
                 coalesce(y.url_cc_id, y.cc_id) AS cc_id
          FROM (
            SELECT c.id, c.region_id, c.updated_at, c.cc_id,
                   c.source_url LIKE '%/cbdet.php?a=%' AS cbdet,
                   CASE WHEN substring(c.source_url FROM '^https?://([^/]+)') = substring(r.public_cc_url_base FROM '^https?://([^/]+)')
                        THEN coalesce(substring(c.source_url FROM '/cbdet\\.php\\?a=(\\d+)'),
                                      substring(c.source_url FROM '/verein-details\\.php\\?p=[^|]*\\|\\|\\|(\\d+)'))::integer
                   END AS url_cc_id
            FROM clubs c
            JOIN regions r ON r.id = c.region_id
            WHERE coalesce(r.public_cc_url_base, '') <> ''
          ) y
        ) x
        WHERE x.cc_id > 0
        ORDER BY x.region_id, x.cc_id, x.via_cbdet DESC, x.updated_at DESC
      SQL
    end
  end

  def down
    drop_table :club_cc_entries
  end
end
