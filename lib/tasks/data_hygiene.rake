# frozen_string_literal: true

# Datenhygiene-Werkzeuge (Phase 38-04) — bereinigt EINEN benannten Altbestand,
# bewusst kein generisches Dubletten-Werkzeug mit Löschgewalt.
#
#   club_location_duplicates — SCHREIBT bei ARMED=1. Entfernt die mehrfach angelegten
#     ClubLocation-Kopien und behält je (club_id, location_id) den ÄLTESTEN Record.
#
#   temporary_season_participations — SCHREIBT bei ARMED=1. Entfernt ALLE SeasonParticipation
#     im Status "temporary" (Betreiber-Entscheidung 2026-08-24, "Regel b"). Rollenbewusst:
#     auf der Authority mit Version (die Loeschung repliziert nach unten), auf lokalen Servern
#     versionslos die Drift, die dort nie eine Authority-Entsprechung hatte.
#
#   table_local_duplicates — SCHREIBT bei ARMED=1. Entfernt die mehrfach angelegten TableLocal
#     je Tisch und behaelt den AELTESTEN Record; rettet vorher dessen leere Konfigurationsfelder
#     (ip_address, tpl_ip_address, locale) aus den juengeren Zwillingen. Lokale Entitaet
#     (`ApiProtector`) — nichts repliziert, die Bereinigung ist auf JEDER Instanz einzeln zu fahren.
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
#   bundle exec rake data_hygiene:temporary_season_participations         # DRY-RUN (Default)
#   bundle exec rake data_hygiene:temporary_season_participations ARMED=1 # schreibt
#   bundle exec rake data_hygiene:table_local_duplicates              # DRY-RUN (Default)
#   bundle exec rake data_hygiene:table_local_duplicates ARMED=1      # schreibt
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

  # Phase 39-01. Befund aus 38-03, Folgenfrage am 2026-08-20 beantwortet, Regel am 2026-08-24
  # entschieden. Der Erzeuger war `Season#copy_season_participations_to_next_season` — mit diesem
  # Plan stillgelegt, damit die Bereinigung kein Einmaleffekt bleibt.
  #
  # WARUM ueberhaupt: `Player#club` (player.rb:202) nimmt `season_participations.order(:season_id).last`
  # OHNE Status-Filter. Damit gewinnt der "temporary"-Record der juengsten Saison immer und
  # erscheint auf der oeffentlichen Vereins- und Spielerseite als Tatsache — obwohl ihn nie
  # jemand belegt hat.
  #
  # ZWEI MENGEN, ZWEI MECHANISMEN (gemessen 2026-08-24):
  #   * Authority (local_server? == false): PaperTrail ist hier aktiv, `.destroy` erzeugt die
  #     destroy-Version, die die Loeschung an alle Regional-Server weitergibt. EIN Eingriff
  #     raeumt die dort gespiegelte Menge ueberall mit.
  #   * lokale Server: tragen zusaetzlich Records, die es auf der Authority NICHT (mehr) gibt —
  #     nichts koennte deren Loeschung replizieren. Die muessen lokal weg. PaperTrail ist dort
  #     fuer dieses Modell abgeschaltet ⇒ keine Version, keine Rueckreplikation.
  #
  # REIHENFOLGE: erst Authority, Sync abwarten, dann die lokalen Server. Dann raeumt der lokale
  # Lauf nur noch die Drift. Umgekehrt ist nicht schaedlich (eine destroy-Version fuer einen
  # lokal bereits fehlenden Record laeuft folgenlos ins Leere), nur unnoetig.
  #
  # Ausschliesslich `.destroy`, nie `delete`/`delete_all` — versionsloses Loeschen auf der
  # Authority hat genau diesen Befund erzeugt (38-03).
  desc "SCHREIBT bei ARMED=1: alle SeasonParticipation im Status 'temporary' entfernen (Regel b)"
  task temporary_season_participations: :environment do
    armed = ENV["ARMED"] == "1"
    authority = !ApplicationRecord.local_server?
    rolle = authority ? "AUTHORITY (Loeschung repliziert nach unten)" : "local Server (versionslos)"
    puts "== data_hygiene:temporary_season_participations == #{armed ? "ARMED (SCHREIBT)" : "DRY-RUN (schreibt nicht)"}"
    puts "Rolle: #{rolle}"

    count_before = SeasonParticipation.count
    versions_before = Version.where(item_type: "SeasonParticipation", event: "destroy").count

    scope = SeasonParticipation.where(status: "temporary")
    total = scope.count
    if total.zero?
      puts "Keine Records im Status 'temporary' — nichts zu tun (idempotent)."
      next
    end

    puts "\n#{total} Record(s) im Status 'temporary':"
    scope.joins(:season).group("seasons.name").count.sort.each do |season, n|
      puts "  #{season}: #{n}"
    end
    global = scope.where("id < ?", 50_000_000).count
    puts "  davon global (id < 50 Mio): #{global} | lokal: #{total - global}"

    # Folgenabschaetzung: was zeigt `Player#club` nach der Loeschung? Drei Klassen —
    # unveraendert, anderer Verein, oder gar keiner mehr. Die dritte ist der einzige echte
    # Verlust und war beim Planen ausdruecklich akzeptiert: eine fehlende Zuordnung ist
    # ehrlicher als eine erfundene.
    temp_ids = scope.pluck(:id)
    pids = scope.distinct.pluck(:player_id).compact
    juengster_temp = {}
    SeasonParticipation.where(id: temp_ids).order(:season_id).each { |sp| juengster_temp[sp.player_id] = sp }
    juengster_rest = {}
    SeasonParticipation.where(player_id: pids).where.not(id: temp_ids).order(:season_id)
      .each { |sp| juengster_rest[sp.player_id] = sp }

    gleich = anders = ohne = 0
    juengster_temp.each do |pid, alt|
      neu = juengster_rest[pid]
      if neu.nil?
        ohne += 1
      elsif neu.club_id == alt.club_id
        gleich += 1
      else
        anders += 1
      end
    end
    puts "\nWirkung auf Player#club (#{pids.size} betroffene Spieler):"
    puts "  gleicher Verein (Loeschung unsichtbar): #{gleich}"
    puts "  anderer Verein (der zuletzt belegte):   #{anders}"
    puts "  KEIN Verein mehr (Player#club -> nil):  #{ohne}"

    unless armed
      puts "\nDRY-RUN beendet — nichts geaendert. Mit ARMED=1 ausfuehren."
      puts "SeasonParticipation.count unveraendert: #{SeasonParticipation.count == count_before}"
      next
    end

    unless authority
      puts "\nℹ️  Reihenfolge-Hinweis: laeuft dieser Server VOR der Authority, loescht er auch die " \
           "Records, die die Authority ohnehin per destroy-Version mitgenommen haette. Folgenlos, " \
           "aber die Authority zuerst zu fahren ist der kuerzere Weg."
    end

    destroyed = 0
    failed = []
    # Bulk ⇒ broadcast-frei (PROJECT.md-Constraint): tausende CableReady-Updates fuer eine
    # Bereinigung haben keinen Empfaenger und wuerden nur die Leitung fluten.
    SeasonParticipation.skip_cable_ready_updates do
      SeasonParticipation.where(id: temp_ids).find_each do |rec|
        # Alle Kandidaten sind global. Auf einem local Server blockt `before_destroy`
        # (LocalProtector#disallow_saving_global_records) genau das — hier ist der Eingriff
        # gewollt und belegt, also ausdruecklich entsperren. Auf der Authority ist der Guard
        # ohnehin inaktiv; das Flag bleibt dort ungesetzt, damit der Rollenunterschied im
        # Code sichtbar bleibt statt in einem pauschalen `unprotected = true` zu verschwinden.
        rec.unprotected = true unless authority
        if rec.destroy
          destroyed += 1
        else
          failed << [rec.id, rec.errors.full_messages.join("; ")]
        end
      rescue => e
        failed << [rec.id, "#{e.class}: #{e.message}"]
      end
    end

    versions_after = Version.where(item_type: "SeasonParticipation", event: "destroy").count
    new_versions = versions_after - versions_before

    puts "\n== Ergebnis =="
    puts "  geloescht:                  #{destroyed} von #{total}"
    puts "  destroy-Versionen:          #{new_versions}"
    puts "  SeasonParticipation.count:  #{count_before} -> #{SeasonParticipation.count}"
    puts "  Rest im Status temporary:   #{SeasonParticipation.where(status: "temporary").count}"
    failed.each { |id, msg| puts "  FEHLER id=#{id}: #{msg}" }

    # Dieselbe Probe wie bei club_location_duplicates, aus demselben Grund: auf der Authority
    # IST die Version der Zweck. Auf einem local Server sind 0 Versionen korrekt (LocalProtector
    # aktiviert has_paper_trail nur, wenn carambus_api_url NICHT gesetzt ist) — die Probe dort
    # zu fahren erzeugt einen Fehlalarm, der wie Datenverlust aussieht.
    if !authority
      puts "  ℹ️  local Server — PaperTrail ist hier per LocalProtector deaktiviert, " \
           "0 Versionen sind erwartet"
    elsif new_versions == destroyed
      puts "  ✅ jede Loeschung hat eine Version erzeugt — die Replikation ist gesichert"
    else
      puts "  ⚠️  #{destroyed - new_versions} Loeschung(en) OHNE Version — diese Records bleiben " \
           "auf den Regional-Servern liegen (genau der Fehler aus 38-03)"
    end
  end

  # Phase 40-01 (Folgebefund 2026-08-25). Dasselbe Muster wie 38-04 bei den ClubLocations:
  # `table_locals` hat KEINEN Index auf `table_id` — schon gar keinen Unique-Index. Damit ist
  # `Table has_one :table_local` bei mehreren Records je Tisch nicht deterministisch. Belegt in
  # der Test-DB: `table.table_local` und `table_monitor.table.table_local` lieferten im selben
  # Test VERSCHIEDENE Records — der Wert, den man setzt, ist nicht der, den man ausliest.
  #
  # ERZEUGER, beide nicht atomar:
  #   * `table.rb:53` — `table_local.presence || create_table_local(...)` in jedem der 17
  #     LOCAL_METHODS-Setter. Heizungs-Schleife und Scoreboard sehen gleichzeitig `nil` und
  #     legen beide an. Genau die Lücke, die 38-04 bei `club_locations` hatte.
  #   * `TableLocalsController#create` — Scaffold ohne jede Eindeutigkeitsprüfung.
  #
  # BETROFFEN ist nicht nur `locale` (40-01), sondern die bestehende Konfiguration:
  # ip_address/tpl_ip_address (Scoreboard, Tischheizung) und event_id/event_start/event_end
  # (Kalenderanbindung).
  #
  # REGEL — älteste id gewinnt, wie bei den ClubLocations. MIT EINEM UNTERSCHIED, der hier
  # zählt: eine ClubLocation ist ein reines FK-Paar ohne Nutzlast, ein TableLocal trägt
  # Konfiguration. Deshalb werden vor dem Löschen die KONFIGURATIONS-Felder (ip_address,
  # tpl_ip_address, locale) auf dem Behalter nachgetragen, wo er leer ist und ein jüngerer
  # Zwilling einen Wert hat — sonst verliert ein Tisch beim Aufräumen still seine Heizungs-IP.
  # Die ZUSTANDS-Felder (heater*, scoreboard*, event*) werden bewusst NICHT gemischt: ein aus
  # zwei Records zusammengesetzter Heizungszustand wäre schlechter als ein leerer, den die
  # nächste Schaltung ohnehin neu setzt.
  #
  # TableLocal ist eine LOKALE Entität (`ApiProtector`) — es gibt hier nichts zu replizieren,
  # die Probe „jede Löschung eine Version" aus 38-04 ist deshalb sinnlos. `unprotected = true`
  # ist trotzdem nötig: `disallow_saving_local_records` rollt auf der Authority jedes Schreiben
  # eines Records mit `id > MIN_ID` zurück.
  desc "SCHREIBT bei ARMED=1: mehrfache TableLocals je Tisch entfernen (aeltesten behalten)"
  task table_local_duplicates: :environment do
    armed = ENV["ARMED"] == "1"
    puts "== data_hygiene:table_local_duplicates == #{armed ? "ARMED (SCHREIBT)" : "DRY-RUN (schreibt nicht)"}"

    count_before = TableLocal.count
    groups = TableLocal.where.not(table_id: nil).group(:table_id).having("count(*) > 1").count

    if groups.empty?
      puts "Keine Mehrfachanlage je table_id gefunden — nichts zu tun (idempotent)."
      puts "TableLocal.count: #{count_before}"
      next
    end

    config_fields = %w[ip_address tpl_ip_address locale]
    to_destroy = []
    merges = []
    rejected = 0

    puts "#{groups.size} Tisch(e) mit mehr als einem TableLocal:"
    groups.sort.each do |table_id, n|
      recs = TableLocal.where(table_id: table_id).order(:id).to_a
      keep = recs.first # aelteste id = urspruenglicher Eintrag (Regel aus 38-04)
      drop = recs - [keep]
      to_destroy.concat(drop)

      puts "  table=#{table_id} (#{n} Records)"
      puts "    BEHALTEN id=#{keep.id} (created #{keep.created_at&.to_date})"
      drop.each { |r| puts "    loeschen  id=#{r.id} (created #{r.created_at&.to_date})" }

      config_fields.each do |field|
        next if keep.send(field).present?

        donor = drop.reverse.find { |r| r.send(field).present? } # juengster Zwilling mit Wert
        next if donor.nil?

        # Der Wert wird schon hier zugewiesen, damit der DRY-RUN genau das zeigt, was ARMED
        # dann speichert — inklusive der Werte, die eine Validierung ablehnt.
        vorher = keep.send(field)
        keep.send(:"#{field}=", donor.send(field))
        if keep.valid?
          merges << [keep, field, donor.send(field), donor.id]
          puts "    nachtragen #{field}=#{donor.send(field).inspect} (aus id=#{donor.id})"
        else
          # Ein ungueltiger Wert (z.B. `locale: "fr"` aus einer alten Konfiguration) ist nichts
          # wert — er darf aber auch nicht die ganze Bereinigung blockieren.
          puts "    ⚠️  #{field}=#{donor.send(field).inspect} (aus id=#{donor.id}) NICHT uebernommen: " \
               "#{keep.errors.full_messages.join("; ")}"
          keep.send(:"#{field}=", vorher)
          rejected += 1
        end
      end
    end

    puts "\nSumme: #{to_destroy.size} Record(s) zu loeschen, #{groups.size} bleiben, " \
         "#{merges.size} Konfigurationsfeld(er) nachzutragen#{", #{rejected} abgelehnt" if rejected.positive?}."

    unless armed
      puts "\nDRY-RUN beendet — nichts geaendert. Mit ARMED=1 ausfuehren."
      puts "TableLocal.count unveraendert: #{TableLocal.count == count_before}"
      next
    end

    # Erst nachtragen, dann loeschen — in dieser Reihenfolge ist ein Abbruch dazwischen
    # folgenlos: der Behalter hat die Werte schon, die Zwillinge stehen noch da, ein zweiter
    # Lauf raeumt sie ab. Umgekehrt waere ein Abbruch Datenverlust.
    merges.group_by(&:first).each do |keep, _entries|
      keep.unprotected = true
      keep.save! # die Werte stehen bereits am Objekt, geprueft beim Sammeln oben
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

    rest = TableLocal.where.not(table_id: nil).group(:table_id).having("count(*) > 1").count.size

    puts "\n== Ergebnis =="
    puts "  nachgetragen:       #{merges.size} Feld(er)#{" (#{rejected} als ungueltig abgelehnt)" if rejected.positive?}"
    puts "  geloescht:          #{destroyed} von #{to_destroy.size}"
    puts "  TableLocal.count:   #{count_before} -> #{TableLocal.count}"
    puts "  Rest mit Dublette:  #{rest}"
    failed.each { |id, msg| puts "  FEHLER id=#{id}: #{msg}" }

    if rest.zero? && failed.empty?
      puts "  ✅ je Tisch genau ein TableLocal — der Unique-Index (Migration) kann gesetzt werden"
    else
      puts "  ⚠️  noch nicht eindeutig — die Migration wuerde hier mit PG::UniqueViolation scheitern"
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
