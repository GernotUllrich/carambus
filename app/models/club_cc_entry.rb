# frozen_string_literal: true

# Listung eines Vereins in der Vereinsliste einer Regional-ClubCloud (cbdet.php): Region + dortige cc_id.
# Ein Verein kann in mehreren CCs gelistet sein (Doppelmitgliedschaft, z. B. ABG Trier-Mosel in BVRP und BVS);
# clubs.region_id/cc_id bleiben die Heimat. Server-lokale Scrape-Metadaten (kein PaperTrail, keine Replikation).
class ClubCcEntry < ApplicationRecord
  belongs_to :club
  belongs_to :region

  # Solange die Heimat-CC den Verein so frisch gelistet hat, ändert eine andere Region seine Stammdaten nicht.
  # Fehlt er dort länger, gilt das als echter Verbandswechsel.
  HOME_FRESH = 7.days

  def self.record!(club, region, cc_id, now: Time.current)
    entry = find_or_initialize_by(region_id: region.id, cc_id: cc_id)
    entry.club_id = club.id
    entry.seen_at = now
    skip_cable_ready_updates { entry.save! } if entry.changed?
    entry
  end

  # Alle Einträge, die in der gerade gelesenen Vereinsliste stehen, als gesehen markieren (ohne Abruf).
  def self.mark_seen!(region, cc_ids, now: Time.current)
    where(region_id: region.id, cc_id: cc_ids).update_all(seen_at: now)
  end

  def self.club_for(region_id, cc_id)
    find_by(region_id: region_id, cc_id: cc_id)&.club
  end

  # Ist `club` in einer anderen Region als `region` beheimatet, deren CC ihn noch listet?
  def self.home_elsewhere?(club, region, now: Time.current)
    return false unless club.persisted? && club.region_id.present? && club.region_id != region.id

    where(club_id: club.id, region_id: club.region_id).where("seen_at > ?", now - HOME_FRESH).exists?
  end
end
