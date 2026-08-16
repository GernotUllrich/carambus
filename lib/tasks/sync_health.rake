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
# WAS DIESE TASKS NICHT TUN: nichts reparieren, nichts nachliefern, keine Validierung lockern und
# keinen Record anfassen. `valid?` allein aendert nichts.
#
# Usage:
#   bundle exec rake sync_health:invalid_census                      # alle Modelle
#   bundle exec rake sync_health:invalid_census MODELS=League,Tournament
#   bundle exec rake sync_health:invalid_census IDS=1                # + erste 50 IDs je Meldung
#   bundle exec rake sync_health:stale_tracer

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
end

# Zaehlwerk fuer beide Tasks. Als Modul im Rake-File, weil es ausserhalb der Bestandsaufnahme keinen
# Aufrufer hat — und der Test greift es hier ab.
module SyncHealthCensus
  module_function

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
end
