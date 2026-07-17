# frozen_string_literal: true

require "digest"

# Change-Detection-Fingerprint einer gescrapten Ressource (gestaffelte Hashes, „Scrape- & Sync-
# Effizienz"). Ebene C = Standings je League: solange der normalisierte digest gleich bleibt, gab es
# keine neuen Ergebnisse → der teure Deep-Scrape (Begegnungen/Spielberichte) ist überspringbar.
#
# SERVER-LOKALE Scrape-Metadata: KEIN PaperTrail, KEINE Replikation an Regional-Server (jeder Server
# hat seinen eigenen Scrape-Zustand), broadcast-frei.
#
# Nutzung im Scraper/Importer:
#   fp = ScrapeFingerprint.for(league, "standings")
#   if fp.stale?(content)   # content = normalisierte Standings (nur ergebnis-tragende Zellen!)
#     ... deep scrape ...
#     fp.commit!(content)   # digest + changed_at festschreiben (NACH Erfolg)
#   else
#     fp.touch_checked!     # nur Prüfzeitpunkt fortschreiben
#   end
class ScrapeFingerprint < ApplicationRecord
  belongs_to :fingerprintable, polymorphic: true

  def self.digest_for(content)
    Digest::SHA256.hexdigest(content.to_s)
  end

  # Fingerprint-Handle für (Ressource, scope) — bestehend oder neu (unpersistiert).
  def self.for(record, scope)
    find_or_initialize_by(fingerprintable: record, scope: scope)
  end

  # Weicht der Inhalt vom gespeicherten digest ab (oder ist der Fingerprint neu)? → Deep-Scrape nötig.
  def stale?(content)
    !persisted? || digest != self.class.digest_for(content)
  end

  # Nach erfolgreichem Deep-Scrape: digest + Zeitstempel festschreiben. changed_at nur, wenn der
  # digest wirklich kippt (bzw. beim Erstanlegen). Broadcast-frei.
  def commit!(content)
    new_digest = self.class.digest_for(content)
    now = Time.current
    self.changed_at = now if new_record? || digest != new_digest
    self.digest = new_digest
    self.checked_at = now
    self.class.skip_cable_ready_updates { save! }
  end

  # Unverändert: nur den Prüfzeitpunkt fortschreiben (version-/broadcast-frei via update_column).
  def touch_checked!
    update_column(:checked_at, Time.current) if persisted?
  end
end
