# frozen_string_literal: true

namespace :videos do
  desc "Trockenlauf der Video-Turnier-Zuordnung — rechnet nur, schreibt NICHTS (LIMIT=, THRESHOLD=, TOURNAMENT_ID=)"
  task match_tournaments_dry_run: :environment do
    # Gegenstueck zu videos:match_tournaments — identische Rechnung, aber ohne
    # video.update. Gedacht als Blick vor dem Sprung: der echte Lauf ordnet
    # zehntausende Videos automatisch zu, und eine Fehlzuordnung faellt spaeter
    # kaum auf.
    #
    #   bin/rails videos:match_tournaments_dry_run
    #   bin/rails videos:match_tournaments_dry_run LIMIT=2000 THRESHOLD=0.80
    #   bin/rails videos:match_tournaments_dry_run TOURNAMENT_ID=17921
    limit = ENV["LIMIT"].presence&.to_i
    threshold = (ENV["THRESHOLD"].presence || Video::TournamentMatcher::CONFIDENCE_THRESHOLD).to_f
    only_tournament = ENV["TOURNAMENT_ID"].presence&.to_i

    matcher = Video::TournamentMatcher.new

    tournaments = InternationalTournament.where("date >= ?", 2.years.ago).includes(seedings: :player).to_a
    tournaments = tournaments.select { |t| t.id == only_tournament } if only_tournament

    mit_seedings = tournaments.count { |t| t.seedings.any? }

    scope = Video.where(videoable_id: nil).where.not(published_at: nil)
    gesamt = scope.count
    scope = scope.limit(limit) if limit

    puts "\n" + "=" * 78
    puts "TROCKENLAUF Video → InternationalTournament   (schreibt nichts)"
    puts "=" * 78
    puts "Schwelle:   #{threshold}"
    puts "Turniere:   #{tournaments.size} im Zeitfenster, davon #{mit_seedings} mit Seedings"
    puts "Videos:     #{limit ? "#{limit} von #{gesamt}" : gesamt} unzugeordnet mit published_at"
    if mit_seedings < tournaments.size
      puts
      puts "  HINWEIS: #{tournaments.size - mit_seedings} Turniere haben keine Seedings. Fuer die kann das"
      puts "  Spieler-Signal (Gewicht #{Video::TournamentMatcher::PLAYER_WEIGHT}) nichts beitragen — ohne es liegt das"
      puts "  Maximum bei #{Video::TournamentMatcher::DATE_WEIGHT + Video::TournamentMatcher::TITLE_WEIGHT}."
      puts "  Erst `bin/rails umb:update` (parse_pdfs) fuellt die Teilnehmerlisten."
    end
    puts

    # Ohne Datumsueberlappung ist das erreichbare Maximum PLAYER_WEIGHT +
    # TITLE_WEIGHT. Liegt die Schwelle darueber, koennen solche Paare die Schwelle
    # nicht reissen und werden uebersprungen — das Ergebnis bleibt identisch,
    # der Lauf aber deutlich kuerzer.
    max_ohne_datum = Video::TournamentMatcher::PLAYER_WEIGHT + Video::TournamentMatcher::TITLE_WEIGHT
    datums_vorfilter = threshold > max_ohne_datum

    treffer = []
    knapp = []
    mehrdeutig = []
    geprueft = 0

    scope.find_each(batch_size: 500) do |video|
      geprueft += 1
      metadata = Video::MetadataExtractor.new(video).extract_all
      detected = Array(metadata[:players]).uniq

      kandidaten = tournaments
      if datums_vorfilter
        tag = video.published_at.to_date
        kandidaten = kandidaten.select do |t|
          next false if t.date.blank?
          ende = t.end_date || (t.date + 7.days)
          (t.date.to_date..(ende.to_date + 3.days)).cover?(tag)
        end
      end
      next if kandidaten.empty?

      # Maßgeblich ist confidence_score des echten Matchers — die Rechnung wird
      # hier bewusst NICHT nachgebaut, sonst koennten Trockenlauf und echter Lauf
      # auseinanderlaufen. Die Teilwerte dienen nur der Diagnose.
      bewertet = kandidaten.map { |t|
        score = matcher.confidence_score(video, t, metadata)
        teile = {
          date: matcher.send(:date_overlap_score, video, t),
          player: matcher.send(:player_intersection_score, detected, t),
          title: matcher.send(:title_similarity_score, video.title, t.title)
        }
        [score, t, teile]
      }.sort_by { |s, _, _| -s }

      best_score, best_t, teile = bewertet.first
      next if best_score < threshold

      zweit = bewertet[1]&.first || 0.0
      eintrag = {score: best_score, runner_up: zweit, video: video, tournament: best_t, teile: teile}
      treffer << eintrag
      knapp << eintrag if best_score < threshold + 0.05
      mehrdeutig << eintrag if (best_score - zweit) < 0.05
    end

    puts "-" * 78
    puts "ERGEBNIS"
    puts "-" * 78
    puts "geprueft:            #{geprueft}"
    puts "wuerden zugeordnet:  #{treffer.size}  (#{geprueft.zero? ? 0 : (100.0 * treffer.size / geprueft).round(1)} %)"
    puts "davon knapp (< #{(threshold + 0.05).round(2)}): #{knapp.size}"
    puts "davon mehrdeutig:    #{mehrdeutig.size}  — Abstand zum zweitbesten Turnier < 0.05"
    puts

    if treffer.any?
      puts "Schwellen-Sensitivitaet (auf denselben Kandidaten):"
      [0.65, 0.70, 0.75, 0.80, 0.85, 0.90].each do |t|
        next if t < threshold
        puts format("   >= %.2f : %d", t, treffer.count { |e| e[:score] >= t })
      end
      puts

      je_turnier = treffer.group_by { |e| e[:tournament] }.transform_values(&:size).sort_by { |_, c| -c }
      puts "Verteilung je Turnier (Top 8) — ein Ausreisser deutet auf Fehlzuordnung:"
      je_turnier.first(8).each do |t, c|
        puts format("   %4d Videos  %s (%s)", c, t.title.to_s[0, 42], t.date&.to_date)
      end
      puts

      # Teilscores mit ausgeben: ein Treffer, der fast nur aus Datum + Spielern
      # besteht (Titel nahe 0), stammt haeufig aus einem PARALLEL laufenden
      # Wettbewerb — Spitzenspieler treten in derselben Woche in Liga und World
      # Cup an. Solche Faelle sieht man nur an der Aufschluesselung.
      anzeige = ENV["SHOW_ALL"].present? ? treffer.size : 10
      zusatz = (anzeige < treffer.size) ? ", Top #{anzeige} — alle mit SHOW_ALL=1" : ""
      puts "Treffer (hoechste Scores#{zusatz})   [D=Datum P=Spieler T=Titel]:"
      treffer.sort_by { |e| -e[:score] }.first(anzeige).each do |e|
        puts format("   %.3f  D%.2f P%.2f T%.2f  %s  ->  %s",
          e[:score], e[:teile][:date], e[:teile][:player], e[:teile][:title],
          e[:video].title.to_s[0, 40], e[:tournament].title.to_s[0, 24])
      end

      schwacher_titel = treffer.count { |e| e[:teile][:title] < 0.2 }
      if schwacher_titel > 0
        puts
        puts "  ACHTUNG: #{schwacher_titel} Treffer haben eine Titel-Aehnlichkeit < 0.20 —"
        puts "  getragen also fast nur von Datum und Spielernamen. Stichprobe pruefen:"
        puts "  ein Ligaspiel derselben Woche sieht fuer den Matcher aus wie das Turnier."
      end

      if mehrdeutig.any?
        puts
        puts "Mehrdeutige Faelle (bester und zweitbester Treffer fast gleichauf):"
        mehrdeutig.first(10).each do |e|
          puts format("   %.3f / %.3f  %s  ->  %s",
            e[:score], e[:runner_up], e[:video].title.to_s[0, 40], e[:tournament].title.to_s[0, 24])
        end
      end
    end

    puts
    puts "=" * 78
    puts "Es wurde NICHTS geschrieben. Der echte Lauf: bin/rails videos:match_tournaments"
    puts "=" * 78
  end
end
