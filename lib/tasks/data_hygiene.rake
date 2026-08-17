# frozen_string_literal: true

# Datenhygiene-Werkzeuge (Phase 38-04) — bereinigt EINEN benannten Altbestand,
# bewusst kein generisches Dubletten-Werkzeug mit Löschgewalt.
#
#   club_location_duplicates — SCHREIBT bei ARMED=1. Entfernt die mehrfach angelegten
#     ClubLocation-Kopien und behält je (club_id, location_id) den ÄLTESTEN Record.
#
#   invalid_stammdaten — READ-ONLY. Meldet DisciplineCc ohne Disziplin und TournamentPlan
#     ohne Tische. Bewusst NUR meldend (Betreiber-Entscheidung 2026-08-17): Stammdaten
#     ohne Kenntnis ihrer Fachbedeutung zu löschen ist riskanter als sie stehen zu lassen.
#
# Herkunft des Befundes: 37-02-Census. Struktur beim Planen von 38-04 gemessen —
# 34 ungültige ClubLocations sind **6 Kombinationen mit je 5–6 Kopien**, nicht 34 Einzelfälle
# (bei einer Uniqueness-Verletzung sind alle Beteiligten ungültig). Angelegt 2025-07-06 bis
# 2025-07-17 im Tagesrhythmus, seither keine neue.
#
# WICHTIG — ausschliesslich `.destroy`, nie `delete`/`delete_all`/`update_all`:
# 38-03 hat belegt, dass versionslose Löschungen auf den Regional-Servern für immer liegen
# bleiben (dort 3 317 überzählige SeasonParticipations). Nur `.destroy` erzeugt die
# PaperTrail-Version, die die Löschung repliziert.
#
# Aufruf:
#   bundle exec rake data_hygiene:club_location_duplicates            # DRY-RUN (Default)
#   bundle exec rake data_hygiene:club_location_duplicates ARMED=1    # schreibt
#   bundle exec rake data_hygiene:invalid_stammdaten                  # read-only
namespace :data_hygiene do
  desc "SCHREIBT bei ARMED=1: mehrfach angelegte ClubLocations entfernen (aeltesten behalten)"
  task club_location_duplicates: :environment do
    armed = ENV["ARMED"] == "1"
    puts "== data_hygiene:club_location_duplicates == #{armed ? "ARMED (SCHREIBT)" : "DRY-RUN (schreibt nicht)"}"

    count_before = ClubLocation.count
    versions_before = Version.where(item_type: "ClubLocation", event: "destroy").count

    groups = ClubLocation.group(:club_id, :location_id).having("count(*) > 1").count
    if groups.empty?
      puts "Keine mehrfach angelegten Kombinationen gefunden — nichts zu tun (idempotent)."
      next
    end

    puts "#{groups.size} Kombination(en) mit Mehrfachanlage:"
    to_destroy = []

    groups.each do |(club_id, location_id), n|
      recs = ClubLocation.where(club_id: club_id, location_id: location_id).order(:id).to_a
      keep = recs.first # aelteste id = urspruenglicher Eintrag (Betreiber-Entscheidung)
      drop = recs - [keep]
      to_destroy.concat(drop)

      puts "  club=#{club_id} location=#{location_id} (#{n} Kopien)"
      puts "    BEHALTEN id=#{keep.id} (created #{keep.created_at&.to_date})"
      drop.each { |r| puts "    loeschen  id=#{r.id} (created #{r.created_at&.to_date})" }
    end

    puts "\nSumme: #{to_destroy.size} Record(s) zu loeschen, #{groups.size} bleiben."

    unless armed
      puts "\nDRY-RUN beendet — nichts geaendert. Mit ARMED=1 ausfuehren."
      puts "ClubLocation.count unveraendert: #{ClubLocation.count == count_before}"
      next
    end

    destroyed = 0
    failed = []
    to_destroy.each do |rec|
      rec.unprotected = true
      if rec.destroy
        destroyed += 1
      else
        failed << [rec.id, rec.errors.full_messages.join("; ")]
      end
    rescue => e
      failed << [rec.id, "#{e.class}: #{e.message}"]
    end

    versions_after = Version.where(item_type: "ClubLocation", event: "destroy").count
    new_versions = versions_after - versions_before

    puts "\n== Ergebnis =="
    puts "  geloescht:            #{destroyed} von #{to_destroy.size}"
    puts "  destroy-Versionen:    #{new_versions}"
    puts "  ClubLocation.count:   #{count_before} -> #{ClubLocation.count}"
    failed.each { |id, msg| puts "  FEHLER id=#{id}: #{msg}" }

    # Die Probe aus 38-03: jede Loeschung MUSS eine Version erzeugt haben, sonst bleibt der
    # Record auf den Regional-Servern fuer immer liegen.
    #
    # NUR auf der Authority sinnvoll: `LocalProtector` aktiviert `has_paper_trail` ausdruecklich
    # nur, wenn `carambus_api_url` NICHT gesetzt ist. Auf einem local Server entstehen also
    # korrekterweise KEINE Versionen (er empfaengt sie, er erzeugt sie nicht) — die Probe dort
    # zu fahren erzeugt einen Fehlalarm, der wie Datenverlust aussieht. Aufgefallen 2026-08-17
    # beim Lauf auf dem carambus-Checkout (38 Loeschungen, 0 Versionen, alles korrekt).
    if ApplicationRecord.local_server?
      puts "  ℹ️  local Server — PaperTrail ist hier per LocalProtector deaktiviert, " \
           "0 Versionen sind erwartet (die Loeschung kommt ohnehin von der Authority)"
    elsif new_versions == destroyed
      puts "  ✅ jede Loeschung hat eine Version erzeugt — die Replikation ist gesichert"
    else
      puts "  ⚠️  #{destroyed - new_versions} Loeschung(en) OHNE Version — diese Records bleiben " \
           "auf den Regional-Servern liegen (genau der Fehler aus 38-03)"
    end
  end

  desc "READ-ONLY: ungueltige Stammdaten melden (DisciplineCc ohne Disziplin, TournamentPlan ohne Tische)"
  task invalid_stammdaten: :environment do
    puts "== data_hygiene:invalid_stammdaten == READ-ONLY"
    count_before = DisciplineCc.count + TournamentPlan.count

    [DisciplineCc, TournamentPlan].each do |klass|
      bad = klass.where("id < ?", 50_000_000).reject(&:valid?)
      puts "#{klass.name}: #{bad.size} ungueltig von #{klass.where("id < ?", 50_000_000).count} global"
      bad.each { |r| puts "  id=#{r.id}: #{r.errors.full_messages.join("; ")}" }
    end

    puts "\nBewusst NUR gemeldet (Betreiber-Entscheidung 2026-08-17): eine fachliche Zuordnung " \
         "dieser Stammdaten steht aus. Read-only belegt: #{DisciplineCc.count + TournamentPlan.count == count_before}"
  end
end
