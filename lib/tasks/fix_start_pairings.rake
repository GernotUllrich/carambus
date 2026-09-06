# frozen_string_literal: true

# Datenkorrektur: Startpaarungen im Turnierplan T13 an die Sportordnung angleichen
#
# Befund (2026-08-24, aus dem laufenden 3-Band-Turnier): T13 setzt in beiden Gruppen die
# Paarung 2-3 auf den ersten und 1-4 auf den zweiten Tisch. Die Sportordnung schreibt es
# umgekehrt vor: erster Tisch 1-4, zweiter Tisch 2-3. Sportlich ist der Unterschied
# folgenlos -- gespielt werden dieselben Partien --, aber die Reihenfolge ist geregelt, und
# Abweichungen davon fallen auf.
#
#   vorher   g1: {"t1":"2-3","t2":"1-4"}   g2: {"t3":"2-3","t4":"1-4"}
#   nachher  g1: {"t1":"1-4","t2":"2-3"}   g2: {"t3":"1-4","t4":"2-3"}
#
# Betroffen ist nur die Startrunde r1; die Folgerunden erzeugt "rs":"eae_pg" selbst.
#
# WICHTIG -- anders als bei reinen Local-Backfills:
# TournamentPlan ist ein GLOBALER Record (id < MIN_ID). Die Korrektur gehoert deshalb auf die
# Authority (carambus_api) und wird von dort per PaperTrail-Versions-Sync an die Regional- und
# Location-Server verteilt. Auf einem lokalen Server wuerde LocalProtector den Schreibversuch
# blockieren -- richtig so, dort ist nichts zu tun.
# Aus demselben Grund wird hier bewusst `save!` verwendet und NICHT `update_column`: Ohne
# Version gaebe es nichts zu synchronisieren, und die Korrektur bliebe auf der Authority haengen.
#
# Laufende Turniere sind nicht betroffen: Der Plan wird beim Initialisieren des
# TournamentMonitors ausgewertet; bereits erzeugte Paarungen bleiben, wie sie sind.
#
# Usage:
#   bundle exec rake tournament_plans:fix_t13_start_pairings              # DRY-RUN (Default)
#   bundle exec rake tournament_plans:fix_t13_start_pairings ARMED=true   # LIVE (schreibt)
#
# Auf Produktion nur nach Freigabe und auf der Authority laufen lassen.

namespace :tournament_plans do
  desc "T13: Startpaarungen an die Sportordnung angleichen (ARMED=true zum Schreiben, sonst DRY-RUN)"
  task fix_t13_start_pairings: :environment do
    armed = ENV["ARMED"] == "true"

    # Erwarteter Ist- und Sollzustand je Gruppe. Der Ist-Zustand ist zugleich der Selektor:
    # Nur wer genau so aussieht, wird angefasst -- alles andere ist eine Anomalie und bleibt.
    expected = {
      "g1" => {"t1" => "2-3", "t2" => "1-4"},
      "g2" => {"t3" => "2-3", "t4" => "1-4"}
    }
    target = {
      "g1" => {"t1" => "1-4", "t2" => "2-3"},
      "g2" => {"t3" => "1-4", "t4" => "2-3"}
    }

    puts "Task:  T13 Startpaarungen -> Sportordnung"
    puts "Mode:  #{armed ? "LIVE (ARMED)" : "DRY-RUN (keine Writes)"}"
    puts "Host:  #{ApplicationRecord.local_server? ? "LOCAL SERVER" : "Authority/Region"}"
    puts

    if ApplicationRecord.local_server?
      puts "ABBRUCH: TournamentPlan ist ein globaler Record. Die Korrektur gehoert auf die"
      puts "         Authority (carambus_api) und kommt von dort per Sync hierher."
      next
    end

    plan = TournamentPlan.find_by(name: "T13")
    if plan.nil?
      puts "ABBRUCH: Turnierplan T13 nicht gefunden."
      next
    end

    params = plan.executor_params
    params = JSON.parse(params) if params.is_a?(String)
    params = params.deep_dup

    ist = expected.keys.to_h { |g| [g, params.dig(g, "sq", "r1")] }
    puts "Turnierplan #{plan.id} (#{plan.name}), Ist-Zustand:"
    ist.each { |g, r1| puts "  #{g}.r1: #{r1.inspect}" }
    puts

    if ist == target
      puts "Bereits korrekt -- nichts zu tun."
      next
    end

    unless ist == expected
      puts "ABBRUCH: Ist-Zustand weicht vom erwarteten ab. Erwartet war:"
      expected.each { |g, r1| puts "  #{g}.r1: #{r1.inspect}" }
      puts "Hier wird nichts geraten -- bitte manuell pruefen."
      next
    end

    target.each { |g, r1| params[g]["sq"]["r1"] = r1 }

    puts "Neuer Zustand:"
    target.each { |g, r1| puts "  #{g}.r1: #{r1.inspect}" }
    puts

    unless armed
      puts "DRY-RUN -- nichts geschrieben. Zum Schreiben: ARMED=true"
      next
    end

    # executor_params ist ein text-Feld OHNE Serializer: Der Wert muss als JSON-STRING
    # geschrieben werden (das Modell macht es an anderer Stelle ebenso, `hash.to_json`).
    # Weist man einen Hash zu, serialisiert Rails ihn per to_s zu Ruby-Notation
    # ({"g1"=>{...}}) -- gueltiges Ruby, aber kein JSON, und jeder spaetere JSON.parse
    # scheitert. Genau das ist beim Bau dieses Tasks einmal passiert.
    plan.update!(executor_params: params.to_json)

    plan.reload
    roundtrip = begin
      JSON.parse(plan.read_attribute_before_type_cast(:executor_params))
    rescue JSON::ParserError
      nil
    end

    if roundtrip.nil?
      raise "ABBRUCH: Geschriebener Wert ist kein gueltiges JSON -- bitte pruefen!"
    end

    unless target.all? { |g, r1| roundtrip.dig(g, "sq", "r1") == r1 }
      raise "ABBRUCH: Geschriebener Wert entspricht nicht dem Ziel -- bitte pruefen!"
    end

    version = plan.versions.order(:id).last
    puts "Geschrieben und rueckgelesen (gueltiges JSON, Zielzustand bestaetigt)."
    puts "PaperTrail-Version #{version&.id} (#{version&.event}) -- wird per Sync verteilt."
  end
end
