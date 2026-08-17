# frozen_string_literal: true

# Bestandsaufnahme zum Version-Sync (Phase 37-02). BEIDE TASKS SIND READ-ONLY.
#
# HERKUNFT: Der Version-Apply hat ungueltige globale Records still auf ihren Vor-Zustand
# zurueckgesetzt (Phase 37-01, behoben in `17c76f02`). Der Fix wirkt ab jetzt — er repariert NICHT
# rueckwirkend. Diese Tasks messen, wie viel Altbestand in dem Zustand steckt, damit der Nachlauf
# (37-03) eine Menge und eine Zahl hat statt einer Vermutung.
#
# ZWEI VERSCHIEDENE FRAGEN, DESHALB ZWEI TASKS:
#
#   invalid_census — RISIKOFLAECHE. Welche globalen Records sind unter den heutigen Validierungen
#                    ungueltig? Das ist die Menge, die der Apply-Loop vor dem Fix eingefroren HAETTE,
#                    sobald sie eine Aenderung bekommt. Laeuft auf jeder Instanz.
#
#   stale_tracer   — BEWEIS. Der `source_kind`-Backfill (Phase 34-01) hat auf der Authority JEDES
#                    Turnier und JEDE Liga gestempelt, jeder Record bekam eine Version. Ein globaler
#                    Record ohne `source_kind` auf einem Regional-Server kann diese Version also nur
#                    verloren haben. Auf der Authority ist die Menge per Definition leer.
#
# WARUM VOLL-CENSUS UND KEINE STICHPROBE: gemessen 0,023 ms/Record (PartyGame, `find_each`), teuerstes
# Modell der Stichprobe League mit 1,0 ms — 3,17 Mio. globale Records laufen in Minuten durch. Eine
# SQL-Naeherung der Validierungen waere schneller, aber ungenau: bedingte Validierungen wie
# `if: -> { organizer_type == "Region" }` lassen sich nicht verlaesslich uebersetzen.
#
# WARUM DAS MODELL-SET ENTDECKT UND NICHT GEPFLEGT WIRD: eine hartkodierte Liste altert lautlos —
# genau die Fehlerklasse, die diese Phase behandelt. `LocalProtector` markiert die replizierten
# Modelle (auf der Authority deckungsgleich mit `has_paper_trail`): aktuell 50, waehrend nur 17 davon
# bisher ueberhaupt Versionen erzeugt haben. Die restlichen 33 sind nicht harmlos, sie waren nur
# still.
#
# WAS DIE BEIDEN MESS-TASKS NICHT TUN: nichts reparieren, nichts nachliefern, keine Validierung
# lockern und keinen Record anfassen. `valid?` allein aendert nichts.
#
#   redeliver      — SCHREIBT (Phase 37-03). Der Nachlauf: je betroffenem Record eine neue Version,
#                    damit der Sync ihn mit seinem AKTUELLEN Stand auf den Regional-Servern nachzieht.
#                    Der Fix aus 37-01 stoppt den Verlust ab jetzt, repariert aber NICHT rueckwirkend.
#
# Usage:
#   bundle exec rake sync_health:invalid_census                      # alle Modelle
#   bundle exec rake sync_health:invalid_census MODELS=League,Tournament
#   bundle exec rake sync_health:invalid_census IDS=1                # + erste 50 IDs je Meldung
#   bundle exec rake sync_health:stale_tracer
#   bundle exec rake sync_health:redeliver                           # DRY-RUN (Default)
#   bundle exec rake sync_health:redeliver MODELS=League LIMIT=25 ARMED=1
#   bundle exec rake sync_health:redeliver ONLY_IDS=3477,3512 ARMED=1     # gezielter Einzel-Nachlauf
#   bundle exec rake sync_health:redeliver ARMED=1                   # der volle Lauf

namespace :sync_health do
  desc "READ-ONLY Census: globale Records, die unter heutigen Validierungen ungueltig sind"
  task invalid_census: :environment do
    models = SyncHealthCensus.models(ENV["MODELS"])
    with_ids = ENV["IDS"].present?

    puts "== sync_health:invalid_census == READ-ONLY"
    puts "Instanz: #{SyncHealthCensus.instance_label}"
    puts "Modelle: #{models.size} (#{ENV["MODELS"].present? ? "eingeschraenkt per MODELS" : "entdeckt ueber LocalProtector"})"
    puts

    started = Time.current
    total_global = 0
    total_invalid = 0
    clean = []

    models.each do |model|
      result = SyncHealthCensus.scan(model)
      total_global += result[:global]
      total_invalid += result[:invalid]

      if result[:invalid].zero?
        clean << "#{model.name} (#{result[:global]})"
        next
      end

      puts format("%-24s global=%9d  ungueltig=%8d  (%5.1f %%)  %.1fs",
        model.name, result[:global], result[:invalid],
        100.0 * result[:invalid] / [result[:global], 1].max, result[:seconds])

      result[:by_message].sort_by { |_msg, ids| -ids.size }.each do |msg, ids|
        puts format("    %6d  %s", ids.size, msg)
        puts "            IDs: #{ids.first(50).join(", ")}#{"  …" if ids.size > 50}" if with_ids
      end
      puts
    end

    puts "-- ohne Befund (#{clean.size} Modelle): #{clean.join(", ")}" if clean.any?
    puts
    puts format("SUMME  Modelle=%d  global=%d  ungueltig=%d  (%.3f %%)  Dauer=%.1fs",
      models.size, total_global, total_invalid,
      100.0 * total_invalid / [total_global, 1].max, Time.current - started)
  end

  desc "READ-ONLY Tracer: globale Records ohne source_kind — beweisbar zurueckgesetzt"
  task stale_tracer: :environment do
    puts "== sync_health:stale_tracer == READ-ONLY"
    puts "Instanz: #{SyncHealthCensus.instance_label}"
    puts
    puts "Der source_kind-Backfill hat auf der Authority JEDEN dieser Records gestempelt."
    puts "Was hier ohne Wert steht, hat seine Version verloren. Auf der Authority: erwartet 0."
    puts

    total = 0

    [Tournament, League].each do |model|
      scope = model.where("id < ?", ApplicationRecord::MIN_ID).where(source_kind: nil)
      count = scope.count
      total += count

      puts format("%-12s global=%8d  ohne source_kind=%6d",
        model.name, model.where("id < ?", ApplicationRecord::MIN_ID).count, count)

      next if count.zero?

      # Die Schnittmenge ist die interessante: ungueltig UND ohne Tracer bestaetigt den
      # Wirkmechanismus aus 37-01. Ohne Tracer, aber gueltig waere ein ANDERER Befund und gehoerte
      # eigens untersucht.
      invalid_ids = []
      SyncHealthCensus.silence_sql do
        scope.find_each(batch_size: 500) { |r| invalid_ids << r.id unless r.valid? }
      end
      puts format("             davon ungueltig=%6d  (gueltig ohne Wert: %d)",
        invalid_ids.size, count - invalid_ids.size)
      puts "             IDs: #{scope.limit(200).pluck(:id).join(", ")}"
      by_region = scope.group(:region_id).count.sort_by { |_r, c| -c }.first(10)
      puts "             nach region_id: #{by_region.map { |r, c| "#{r || "-"}=#{c}" }.join(" ")}"
      puts
    end

    puts format("SUMME beweisbar zurueckgesetzt: %d", total)
  end

  # SCHREIBENDER TASK (Phase 37-03) — der Nachlauf.
  #
  # GEHOERT AUF DIE AUTHORITY. Nur dort ist PaperTrail aktiv und sind globale Records schreibbar; auf
  # einem Regional-Server blockiert `LocalProtector`, und eine dort erzeugte Version reiste nirgendwohin.
  #
  # WARUM `save_with_version(validate: false)`:
  #   - `touch` erzeugt KEINE Version (Versions-Gate aus Phase 19, `unless:`-Lambda in LocalProtector)
  #   - `update_columns` erzeugt ebenfalls keine
  #   - `save` ohne Option braeche ab — diese Records sind per Definition UNGUELTIG; genau daran ist
  #     der erste ARMED-Lauf in 34-01 gescheitert
  #   - `record_update(force: true)` in save_with_version erzeugt die Version auch OHNE Attributaenderung
  #
  # WAS DIE VERSION TRAEGT: ohne Attributaenderung ist PaperTrails `object` der AKTUELLE Stand und
  # `object_changes` leer ⇒ der Regional-Server schreibt den vollen, korrekten Snapshot. Es braucht
  # also keine kuenstliche Aenderung am Record.
  #
  # WARUM `set_branch_id` AUSGEHAENGT WIRD: der Callback haengt an `before_save` mit der Bedingung
  # `branch_id.nil?` — und die trifft 5 810 der 6 436 globalen Ligen. Ein naives Speichern legte damit
  # eine unbeauftragte Massenaenderung in denselben Sync-Batch (dieselbe Falle wie in 34-01).
  #
  # WARUM DIE REGION NACHGESTEMPELT WIRD (Befund aus der Generalprobe 37-03): `versions.region_id`
  # setzt nicht PaperTrail, sondern der `after_save`-Callback `RegionTaggable#update_version_region_data`
  # — und der steigt bei `previous_changes.blank?` aus. Ein Nachlauf aendert per Definition KEIN
  # Attribut, also bliebe die Version ungetaggt. Folge waere schwerwiegend: der Sync-Filter ist
  # `region_id IS NULL OR region_id = ?` ⇒ eine ungetaggte Version reist an JEDE Instanz, und wo der
  # Record lokal fehlt, LEGT der Apply ihn an — tbv bekaeme so tausende NBV-Ligen. Deshalb traegt der
  # Task die Region des Records selbst nach, genau wie es der Callback bei einer echten Aenderung taete.
  #
  # NICHT IDEMPOTENT: jeder Lauf erzeugt eine WEITERE Version je Record. Den Daten schadet das nicht
  # (derselbe Stand reist erneut), es kostet nur Sync-Last. Einmal-Werkzeug, kein Cron.
  #
  # WAS ER NICHT TUT: keine Datenreparatur. Die Records bleiben ungueltig — die 4 430 Ligen ohne
  # `shortname` und die 2 017 verwaisten Seedings sind ein eigener Strang. Dieser Task LIEFERT AUS.
  desc "SCHREIBT: Nachlauf — je eingefrorenem globalen Record eine neue Version (ARMED=1 zum Schreiben)"
  task redeliver: :environment do
    armed = ENV["ARMED"].present?
    limit = ENV["LIMIT"].presence&.to_i
    # BEWUSST NICHT `IDS`: dort ist es im Census ein Schalter (IDS=1 = IDs mit ausgeben). Derselbe
    # Name mit zwei Bedeutungen im selben File waere eine Falle — `redeliver IDS=1` schriebe dann
    # still nur Record 1, statt gespraechiger zu sein.
    only_ids = ENV["ONLY_IDS"].presence&.split(",")&.map(&:strip)&.map(&:to_i)
    models = SyncHealthCensus.models(ENV["MODELS"].presence || SyncHealthCensus::REDELIVER_MODELS.join(","))

    puts "== sync_health:redeliver == #{armed ? "ARMED (SCHREIBT)" : "DRY-RUN (schreibt nicht)"}"
    puts "Instanz: #{SyncHealthCensus.instance_label}"
    puts "Modelle: #{models.map(&:name).join(", ")}#{"  LIMIT=#{limit} je Modell" if limit}"
    puts

    versions_before = Version.count
    started = Time.current
    total = 0

    SyncHealthCensus.without_branch_tagging(models) do
      SyncHealthCensus.without_broadcasts(models) do
        models.each do |model|
          candidates = SyncHealthCensus.scan(model)[:by_message].values.flatten.sort
          candidates &= only_ids if only_ids
          candidates = candidates.first(limit) if limit
          total += candidates.size

          if candidates.empty?
            puts format("%-24s keine Kandidaten", model.name)
            next
          end

          unless armed
            preview = SyncHealthCensus.preview_changes(model, candidates.first(50))
            puts format("%-24s %6d Records wuerden je eine neue Version bekommen", model.name, candidates.size)
            if preview.any?
              puts "    ⚠ Stichprobe (50): ein Speichern wuerde zusaetzlich aendern → " \
                   "#{preview.map { |a, n| "#{a}×#{n}" }.join(", ")}"
              puts "      Ein Nachlauf soll AUSLIEFERN, nicht aendern. Ursache klaeren, bevor ARMED laeuft."
            end
            next
          end

          # Blast-Radius vor dem Schreiben aussprechen — die Versionen reisen an ALLE Regional-Server.
          puts format("%-24s %6d Records → %d neue Versionen an ALLE Regional-Server …",
            model.name, candidates.size, candidates.size)

          t0 = Time.current
          written = 0
          failed = []
          collateral = Hash.new(0)

          model.where(id: candidates).find_each(batch_size: 200) do |record|
            record.unprotected = true if record.respond_to?(:unprotected=)
            version = record.paper_trail.save_with_version(validate: false)
            SyncHealthCensus.stamp_region!(record, version)
            # Ein Nachlauf soll AUSLIEFERN, nicht aendern. Was fremde `before_save`-Callbacks
            # nebenbei anfassen, wird gezaehlt und gemeldet — statt still im Sync-Batch mitzureisen.
            (record.saved_changes.keys - ["updated_at"]).each { |a| collateral[a] += 1 }
            written += 1
          rescue => e
            failed << [record.id, e.message]
          end

          puts format("%-24s geschrieben=%6d  fehlgeschlagen=%d  %.1fs",
            model.name, written, failed.size, Time.current - t0)
          failed.first(10).each { |id, msg| puts "    FEHLER #{id}: #{msg}" }
          if collateral.any?
            puts "    ⚠ ZUSATZAENDERUNGEN durch fremde Callbacks: " \
                 "#{collateral.map { |a, n| "#{a}×#{n}" }.join(", ")} — sie reisen mit an alle Instanzen"
          end
        end
      end
    end

    puts
    puts format("SUMME  Records=%d  neue Versionen=%d  Dauer=%.1fs",
      total, Version.count - versions_before, Time.current - started)
    puts "DRY-RUN — nichts geschrieben. ARMED=1 fuehrt ihn aus." unless armed
  end
end

# Zaehlwerk fuer beide Tasks. Als Modul im Rake-File, weil es ausserhalb der Bestandsaufnahme keinen
# Aufrufer hat — und der Test greift es hier ab.
module SyncHealthCensus
  module_function

  # Die Modelle mit Befund aus der Bestandsaufnahme 37-02 (Census auf allen vier Instanzen).
  # Bewusst eine feste Liste und NICHT die Entdeckung: der Nachlauf schreibt, und was er anfasst,
  # soll gemessen und benannt sein. Findet ein spaeterer Census weitere Modelle, gehoeren sie hier
  # bewusst ergaenzt — nicht automatisch mitgenommen.
  REDELIVER_MODELS = %w[League Seeding ClubLocation DisciplineCc TournamentPlan].freeze

  # Die replizierten Modelle. ENTDECKT, nicht gepflegt (siehe Kopfkommentar).
  def models(only = nil)
    Rails.application.eager_load!

    all = ApplicationRecord.descendants.select do |klass|
      klass.include?(LocalProtector) && !klass.abstract_class? && klass.table_exists?
    rescue
      false
    end.sort_by(&:name)

    return all if only.blank?

    wanted = only.split(",").map(&:strip)
    all.select { |k| wanted.include?(k.name) }
  end

  def scan(model)
    started = Time.current
    by_message = Hash.new { |h, k| h[k] = [] }
    global = 0
    invalid = 0

    # SQL-Log stumm: im Development schreibt der Logger jede Batch-Query nach stdout — bei 3,17 Mio.
    # Records ertrinkt die Messung in ihrem eigenen Rauschen (gemessen: 10 000 Log-Zeilen in zwei
    # Minuten). Der Zaehlvorgang ist read-only, es gibt hier nichts zu sehen.
    silence_sql do
      model.where("id < ?", ApplicationRecord::MIN_ID).find_each(batch_size: 1000) do |record|
        global += 1
        next if record.valid?

        invalid += 1
        by_message[record.errors.full_messages.sort.join("; ")] << record.id
      end
    end

    {global: global, invalid: invalid, by_message: by_message, seconds: Time.current - started}
  end

  def silence_sql(&block)
    logger = ActiveRecord::Base.logger
    return yield if logger.nil? || !logger.respond_to?(:silence)

    logger.silence(&block)
  end

  def instance_label
    [Rails.env, Carambus.config.carambus_api_url.presence ? "Regional-Server" : "Authority"].join(" / ")
  end

  # Haengt `set_branch_id` fuer die Dauer des Laufs aus (Muster aus source_kind.rake:109, dort fuer
  # denselben Grund). NUR fuer Modelle, die `BranchTaggable` ueberhaupt einbinden — ein pauschales
  # `set_callback` haenge den Callback sonst an Modelle, die ihn nie hatten (Seeding, ClubLocation …)
  # und die die Methode gar nicht kennen.
  def without_branch_tagging(models)
    affected = models.select { |m| m.include?(BranchTaggable) }
    affected.each { |m| m.skip_callback(:save, :before, :set_branch_id, raise: false) }
    yield
  ensure
    affected.to_a.each do |m|
      m.set_callback(:save, :before, :set_branch_id,
        if: -> { will_save_change_to_discipline_id? || branch_id.nil? })
    end
  end

  # Traegt Region und global_context der Version nach — die Aufgabe, die sonst
  # `RegionTaggable#update_version_region_data` uebernimmt, bei einem aenderungsfreien Speichern aber
  # ueberspringt (Guard `previous_changes.present?`). Modelle ohne `region_id` (DisciplineCc,
  # TournamentPlan) sind global und bleiben korrekt ungetaggt.
  def stamp_region!(record, version)
    return if version.blank? || !version.is_a?(ActiveRecord::Base)
    return unless record.respond_to?(:region_id)

    attrs = {region_id: record.region_id}
    attrs[:global_context] = record.global_context if record.respond_to?(:global_context)
    version.update_columns(attrs)
  end

  # Was wuerde ein Speichern anfassen? Echte Callbacks, echte Records — aber in einer Transaktion,
  # die zurueckgerollt wird. Kein Raten, und der Betreiber sieht es VOR dem Prod-Lauf.
  def preview_changes(model, ids)
    changed = Hash.new(0)
    return changed if ids.blank?

    ActiveRecord::Base.transaction do
      model.where(id: ids).find_each do |record|
        record.unprotected = true if record.respond_to?(:unprotected=)
        record.save(validate: false)
        (record.saved_changes.keys - ["updated_at"]).each { |a| changed[a] += 1 }
      end
      raise ActiveRecord::Rollback
    end
    changed
  end

  # Broadcast-frei bei Massenlaeufen (Projekt-Constraint). `skip_cable_ready_updates` ist eine
  # Block-API je Klasse ⇒ ueber die Modelle schachteln.
  def without_broadcasts(models, &block)
    remaining = models.select { |m| m.respond_to?(:skip_cable_ready_updates) }
    return yield if remaining.empty?

    head, *rest = remaining
    head.skip_cable_ready_updates { without_broadcasts(rest, &block) }
  end
end
