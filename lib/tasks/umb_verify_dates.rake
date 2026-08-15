# frozen_string_literal: true

namespace :umb do
  desc "Vergleicht Turnierdaten mit der UMB-Detailseite — meldet Abweichungen, korrigiert mit FIX=1"
  task verify_dates: :environment do
    # Anlass (2026-08-10): "UMB 3-Cushion World Masters" stand mit Datum
    # 2026-03-31 im Bestand, waehrend UMB zu derselben external_id 2020-03-31
    # und den Ort "CANCELLED / BOGOTA" liefert — ein abgesagtes Turnier von 2020.
    # Weil sein falsches Datum ins Zeitfenster fiel, zog es im Video-Matcher 21
    # Videos eines ganz anderen Turniers an (Blankenberge 2026).
    #
    #   bin/rails umb:verify_dates          # nur melden
    #   bin/rails umb:verify_dates FIX=1    # Datum auf den UMB-Wert setzen
    #   bin/rails umb:verify_dates ALL=1    # gesamten Bestand statt Matcher-Fenster
    #
    # Ein Request je Turnier — der Standardlauf beschraenkt sich deshalb auf das
    # Fenster, das der Video-Matcher ueberhaupt betrachtet (2 Jahre rueckwaerts).
    fix = ENV["FIX"].present? && ENV["FIX"] != "0"
    alle = ENV["ALL"].present?
    toleranz = 1 # Tag — Zeitzonen-Rundungen sollen nicht als Abweichung gelten

    src = InternationalSource.find_by(source_type: "umb")
    abort "UMB-Quelle nicht gefunden." if src.nil?

    scope = InternationalTournament.where(international_source: src).where.not(external_id: nil)
    scope = scope.where("date >= ?", 2.years.ago) unless alle
    scope = scope.order(:date)

    puts "\n" + "=" * 78
    puts fix ? "UMB-DATEN ABGLEICHEN (FIX — schreibt!)" : "UMB-DATEN ABGLEICHEN — nur melden"
    puts "=" * 78
    puts "Pruefe #{scope.count} Turniere mit external_id#{alle ? " (gesamter Bestand)" : " im Matcher-Fenster"}..."
    puts

    details = Umb::DetailsScraper.new
    abweichungen = 0
    korrigiert = 0
    unbekannt = 0

    scope.find_each do |t|
      data = details.send(:fetch_tournament_basic_data, t.external_id.to_i)
      if data.nil?
        unbekannt += 1
        next
      end

      umb_datum = Umb::DateHelpers.parse_single_date(data[:start_date])
      next if umb_datum.nil?

      diff = (t.date.to_date - umb_datum.to_date).to_i
      next if diff.abs <= toleranz

      abweichungen += 1
      puts "id=#{t.id} ext=#{t.external_id}   DB=#{t.date.to_date}   UMB=#{umb_datum.to_date}   (#{diff} Tage)"
      puts "   #{t.title[0, 50]}"
      puts "   UMB-Ort: #{data[:location].inspect}"

      # Ein "CANCELLED"/"POSTPONED" im Ortsfeld ist die Erklaerung fuer viele
      # Abweichungen — UMB fuehrt den Status dort, nicht in einem eigenen Feld.
      if data[:location].to_s.match?(/CANCELLED|POSTPONED/i)
        puts "   HINWEIS: UMB markiert das Turnier als abgesagt/verschoben."
      end

      if fix
        ende = Umb::DateHelpers.parse_single_date(data[:end_date])
        t.update_columns(date: umb_datum, end_date: ende || t.end_date)
        korrigiert += 1
        puts "   -> Datum auf #{umb_datum.to_date} gesetzt"
      end
      puts
    end

    puts "-" * 78
    puts "Abweichungen (> #{toleranz} Tag): #{abweichungen}"
    puts "Detailseite nicht abrufbar: #{unbekannt}" if unbekannt > 0
    if fix
      puts "Korrigiert: #{korrigiert}"
    elsif abweichungen > 0
      puts "Es wurde NICHTS geschrieben — mit FIX=1 korrigieren."
    end
    puts "=" * 78
  end
end
