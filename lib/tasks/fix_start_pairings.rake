# frozen_string_literal: true

# Datenkorrektur: Startpaarungen in Turnierplaenen an die Sportordnung angleichen
#
# Befund (2026-08-24, aus dem laufenden 3-Band-Turnier): Mehrere Plaene setzen in einer
# Vierergruppe die Paarung 2-3 auf den ersten und 1-4 auf den zweiten Tisch. Die Sportordnung
# schreibt es umgekehrt vor: erst 1-4, dann 2-3. Sportlich folgenlos -- es sind dieselben
# Partien --, aber die Reihenfolge ist geregelt, und Abweichungen fallen auf.
#
# Dass 1-4 zuerst die Norm ist, belegen die Daten selbst: Die Mehrheit der Vierergruppen
# (T10, T15, T24, T25, T21, T23, ...) haelt es bereits so. Bei T29 ist sogar innerhalb
# desselben Plans die zweite Iteration korrekt (r4: 1-4/2 vor 2-3/2) und nur die erste
# vertauscht -- der Plan widerspricht sich also selbst.
#
# Der Task tauscht ausschliesslich das exakte Muster: eine Runde mit GENAU zwei Tischen in
# einer Gruppe mit GENAU vier Spielern, deren Paarungen (nach Tischnummer sortiert)
# ["2-3", "1-4"] lauten. Alles andere bleibt unberuehrt -- hier wird nichts geraten.
# Iterations-Suffixe wandern mit ("2-3/1" -> Tisch des vormaligen "1-4/1").
#
# Getauscht wird nur die Zuordnung Paarung->Tisch innerhalb derselben Runde. Reihenfolge und
# Ablauf aendern sich nicht.
#
# WICHTIG: TournamentPlan ist ein GLOBALER Record (id < MIN_ID). Die Korrektur gehoert auf die
# Authority (carambus_api) und wird von dort per PaperTrail-Versions-Sync an die Regional- und
# Location-Server verteilt. Auf einem lokalen Server wuerde LocalProtector blockieren.
# Deshalb `update!` (mit Version) und NICHT `update_column` -- ohne Version gaebe es nichts
# zu synchronisieren.
#
# Laufende Turniere sind nicht betroffen: Der Plan wird beim Initialisieren des
# TournamentMonitors ausgewertet; bereits erzeugte Paarungen bleiben.
#
# Usage:
#   bundle exec rake tournament_plans:fix_start_pairings              # DRY-RUN (Default)
#   bundle exec rake tournament_plans:fix_start_pairings ARMED=true   # LIVE (schreibt)
#   bundle exec rake tournament_plans:fix_start_pairings PLANS=T14,T29     # nur diese
#   bundle exec rake tournament_plans:fix_start_pairings EXCLUDE=T17,T03    # diese auslassen
#
# EXCLUDE ist auf "T17" vorbelegt (nicht mehr in der Sportordnung). Bewusst als Ausschluss
# statt als Positivliste, damit spaeter hinzugekommene Plaene mit demselben Fehler
# automatisch erfasst werden.
#
# Auf Produktion nur nach Freigabe und auf der Authority laufen lassen.

namespace :tournament_plans do
  desc "Startpaarungen 2-3/1-4 an die Sportordnung angleichen (ARMED=true zum Schreiben, sonst DRY-RUN)"
  task fix_start_pairings: :environment do
    armed = ENV["ARMED"] == "true"
    only = ENV["PLANS"].to_s.split(",").map(&:strip).reject(&:empty?)
    # T17 bleibt bewusst unveraendert: Der Plan kommt in der Sportordnung nicht mehr vor
    # (Betreiber, 2026-08-24). An seiner Stelle steht T16neu -- der ist bereits korrekt.
    skip = ENV.fetch("EXCLUDE", "T17").split(",").map(&:strip).reject(&:empty?)

    # Konstanten im Rake-Block landen im globalen Namensraum -> lokale Variable.
    wrong_order = %w[2-3 1-4].freeze

    puts "Task:  Startpaarungen -> Sportordnung (1-4 vor 2-3)"
    puts "Mode:  #{armed ? "LIVE (ARMED)" : "DRY-RUN (keine Writes)"}"
    puts "Filter: #{only.any? ? only.join(", ") : "alle Plaene"}"
    puts "Ausgenommen: #{skip.any? ? skip.join(", ") : "keine"}"
    puts

    if ApplicationRecord.local_server?
      puts "ABBRUCH: TournamentPlan ist ein globaler Record. Die Korrektur gehoert auf die"
      puts "         Authority (carambus_api) und kommt von dort per Sync hierher."
      next
    end

    scope = TournamentPlan.order(:name)
    scope = scope.where(name: only) if only.any?
    scope = scope.where.not(name: skip) if skip.any?

    geaendert = 0
    geprueft = 0

    scope.each do |plan|
      raw = plan.read_attribute_before_type_cast(:executor_params)
      params = begin
        JSON.parse(raw)
      rescue JSON::ParserError, TypeError
        nil
      end
      next unless params.is_a?(Hash)

      geprueft += 1
      treffer = []

      params.each do |gkey, group|
        next unless gkey =~ /\Ag\d+\z/ && group.is_a?(Hash)
        next unless group["pl"].to_i == 4

        rounds = group["sq"]
        next unless rounds.is_a?(Hash)

        rounds.each do |rkey, round|
          next unless round.is_a?(Hash) && round.size == 2

          tables = round.keys.sort
          # Suffix (Iteration) abtrennen, aber beim Tausch mitfuehren
          pairs = tables.map { |t| round[t].to_s.split("/", 2) }
          next unless pairs.map(&:first) == wrong_order

          a, b = tables
          round[a], round[b] = round[b], round[a]
          treffer << "#{gkey}.#{rkey}: #{tables.map { |t| "#{t}=#{round[t]}" }.join(" ")}"
        end
      end

      next if treffer.empty?

      geaendert += 1
      puts "#{plan.name} (id=#{plan.id}):"
      treffer.each { |t| puts "  neu  #{t}" }

      next unless armed

      plan.update!(executor_params: params.to_json)
      plan.reload

      # executor_params ist ein text-Feld OHNE Serializer: Der Wert MUSS als JSON-String
      # geschrieben werden. Eine Hash-Zuweisung serialisiert Rails per to_s zu Ruby-Notation
      # ({"g1"=>{...}}) -- gueltiges Ruby, aber kein JSON, womit jeder spaetere JSON.parse
      # scheitert. Deshalb hier zurueckgelesen und geprueft.
      roundtrip = begin
        JSON.parse(plan.read_attribute_before_type_cast(:executor_params))
      rescue JSON::ParserError
        nil
      end
      raise "ABBRUCH bei #{plan.name}: geschriebener Wert ist kein gueltiges JSON!" if roundtrip.nil?
      raise "ABBRUCH bei #{plan.name}: Rueckgelesenes weicht ab!" unless roundtrip == params

      version = plan.versions.order(:id).last
      puts "  geschrieben, Version #{version&.id} (#{version&.event}) -- wird per Sync verteilt"
    end

    puts
    puts "Geprueft: #{geprueft} Plaene, betroffen: #{geaendert}"
    puts(armed ? "Fertig." : "DRY-RUN -- nichts geschrieben. Zum Schreiben: ARMED=true")
  end
end
