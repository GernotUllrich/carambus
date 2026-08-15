module TournamentsHelper
end

module TournamentsHelper
  # Erkennt Gruppen-/Vorrunden-Spiele (kein K.-o.), die NICHT in den Baum gehören.
  KO_GROUP_RE = /\A(Gruppe|Vorrunde|Zwischenrunde|Qualifikation|Setzrunde|Endrunde|Poule)/i
  # Platzierungsspiele (Platz 3 etc.) — als separater Abschnitt, nicht im Haupt-Baum.
  KO_PLACE_RE = /(Platz|Plätze|kleines Finale)/i
  # Trostrunden (Gewinner-/Verliererrunde) — nur nachrangig in den Haupt-Baum.
  KO_CONSOL_RE = /(Verlierer|Gewinner|Trost|\bVR\b|\bGR\b)/i
  # Kanonische Rundennamen je Rundengröße, verankert am (normalisierten) Namensanfang,
  # damit "Halbfinale", "1/2 Finale" oder "Einzug Finale GwR" NICHT den Finale-Slot treffen.
  # Bruchschreibweise (1/2, 1/4, 1/8, 1/16) wird der jeweils richtigen Rundengröße zugeordnet.
  KO_CANON = {
    1 => %r{\A(finale|f)\b}i,
    2 => %r{\A(halbfinale|hf|1/2[\s-]*finale)}i,
    4 => %r{\A(viertelfinale|vf|1/4[\s-]*finale)}i,
    8 => %r{\A(achtelfinale|af|hauptrunde|hr|1/8[\s-]*finale)}i,
    16 => %r{\A(sechzehntelfinale|sechzehntel|hauptrunde|hr|1/16[\s-]*finale)}i,
    32 => %r{\A(hauptrunde|hr)}i
  }.freeze

  # Baut aus den Ergebniszeilen (Games) eines regionalen Turniers die K.-o.-Struktur.
  # Der Haupt-Baum wird sprachunabhängig über die Spielanzahl als Halbierungskette ab
  # "Finale" (1 → 2 → 4 → 8 …) erkannt; Labels ergeben sich aus der Rundengröße.
  # Zusätzlich: Platzierungsspiele und übrige K.-o.-Runden (Trostrunden) als Extras.
  #
  # @return [Hash, nil] { tree: [[label, [Game,…]], …], extras: [[label, [Game,…]], …] } oder nil
  def regional_ko_bracket(tournament)
    # Internationale Turniere haben ihr eigenes Diagramm (international/tournaments/show)
    return nil if tournament.is_a?(InternationalTournament)

    games = tournament.games.includes(game_participations: :player).to_a
    return nil if games.empty?

    non_group = games.reject { |g| g.gname.to_s.match?(KO_GROUP_RE) }
    place_games = non_group.select { |g| g.gname.to_s.match?(KO_PLACE_RE) }
    ko_games = non_group - place_games
    return nil if ko_games.empty?

    by_name = ko_games.group_by { |g| g.gname.to_s }
    counts = by_name.transform_values(&:size)

    # Halbierungskette ab Finale (Größe 1) aufbauen
    tree = []
    used = []
    size = 1
    loop do
      candidates = counts.select { |n, c| c == size && used.exclude?(n) }.keys
      break if candidates.empty?

      # Bei mehreren Runden gleicher Größe: kanonischen Namen bevorzugen, Trostrunde zurückstufen.
      # Tie-Break deterministisch: höchster Score, dann kürzester Name (schlichtes "Finale" vor
      # "Finale, Gruppensieger"), dann alphabetisch — nie mehr die Array-Reihenfolge.
      name = candidates.min_by { |n| [-ko_round_score(n, size), ko_normalize(n).length, n] }
      tree.unshift([ko_round_label(size), sort_ko_games(by_name[name])])
      used << name
      size *= 2
    end
    return nil if tree.size < 2

    # Extras: Platzierungsspiele + nicht verwendete K.-o.-Runden (Trostrunden)
    extras = []
    extras << ["Spiel um Platz 3", sort_ko_games(place_games)] if place_games.any?
    by_name.each do |name, gs|
      extras << [name, sort_ko_games(gs)] if used.exclude?(name)
    end

    { tree: tree, extras: extras }
  end

  # Bewertet einen gname als Haupt-Baum-Runde einer Größe: kanonisch (3) > neutral (1) > Trostrunde (0).
  def ko_round_score(name, round_size)
    norm = ko_normalize(name)
    return 3 if KO_CANON[round_size]&.match?(norm)
    return 0 if norm.match?(KO_CONSOL_RE)

    1
  end

  # Normalisiert einen gname für den kanonischen Abgleich: führende Anführungszeichen und
  # Leerzeichen entfernen (CC liefert teils `"Finale`), damit die \A-Anker greifen.
  def ko_normalize(name)
    name.to_s.sub(/\A[\s"']+/, "")
  end

  # Deutsches Rundenlabel aus der Spielanzahl der Runde.
  def ko_round_label(round_size)
    { 1 => "Finale", 2 => "Halbfinale", 4 => "Viertelfinale",
      8 => "Achtelfinale", 16 => "Sechzehntelfinale", 32 => "1/32-Finale" }[round_size] ||
      "Runde der letzten #{round_size * 2}"
  end

  # Sortiert die Spiele einer Runde stabil (seqno, dann id).
  def sort_ko_games(games)
    games.sort_by { |g| [g.seqno.to_i, g.id] }
  end

  # Ermittelt die Gewinner-Rolle eines K.-o.-Spiels aus den Ergebnissen (höheres result).
  # @return [GameParticipation, nil]
  def ko_game_winner(game)
    parts = game.game_participations.to_a
    return nil if parts.size < 2 || parts.any? { |p| p.result.nil? }

    parts.max_by { |p| p.result.to_i } if parts.map(&:result).uniq.size > 1
  end

  # Verliererrunden eines Doppel-K.-o. (Gewinner-/Verlierer-Bracket).
  DKO_LB_RE = /(Verlierer|VerlR|\bVR\b)/i

  # Baut aus den Ergebniszeilen eines Doppel-K.-o.-Turniers Gewinner-Baum, Verlierer-Baum,
  # Finale und die exakten Kanten (aus dem Spielerfluss: wer aus welchem Spiel weiterzieht).
  # sprachunabhängig über seqno; kein Vorgänger-Link in den Daten nötig.
  #
  # @return [Hash, nil] { wb: [[label, [Game,…]], …], lb: […], final: Game|nil,
  #                       edges: [{from:, to:, kind: "win"|"loss"}, …] } — nil wenn kein Doppel-K.-o.
  def regional_dko_bracket(tournament)
    return nil if tournament.is_a?(InternationalTournament)

    games = tournament.games.includes(game_participations: :player).to_a
    ko = games.reject { |g| g.gname.to_s.match?(KO_GROUP_RE) }.sort_by { |g| g.seqno.to_i }
    return nil if ko.size < 4

    lb = ko.select { |g| g.gname.to_s.match?(DKO_LB_RE) }
    return nil if lb.empty? # kein Doppel-K.-o.

    non_lb = ko - lb
    final = non_lb.select { |g| dko_grand_final?(g) }.max_by { |g| g.seqno.to_i }
    wb = non_lb - [final].compact
    return nil if wb.empty?

    { wb: dko_rounds(wb), lb: dko_rounds(lb), final: final, edges: dko_edges(ko) }
  end

  # Grand Final = zusammenführendes Endspiel (exakter Finale-Name, kein "Einzug Finale …").
  def dko_grand_final?(game)
    norm = ko_normalize(game.gname)
    norm.match?(/\A(finale|f)\b/i) && !norm.match?(/Einzug/i)
  end

  # Gruppiert Spiele zu Runden (nach gname), geordnet nach frühester seqno.
  def dko_rounds(games)
    games.group_by { |g| g.gname.to_s }
      .sort_by { |_, gs| gs.map { |g| g.seqno.to_i }.min }
      .map { |name, gs| [ko_normalize(name), sort_ko_games(gs)] }
  end

  # Rekonstruiert die Bracket-Kanten über den Spielerfluss: für jeden Spieler die in seqno
  # aufeinanderfolgenden Spiele; kind = "win" (gewann Quellspiel, zog weiter) / "loss" (verlor,
  # fiel in die Verliererrunde). Jede Kante (a→b) gehört genau einem Spieler.
  def dko_edges(games)
    by_player = Hash.new { |h, k| h[k] = [] }
    games.each { |g| g.game_participations.each { |gp| by_player[gp.player_id] << g if gp.player_id } }

    seen = {}
    edges = []
    by_player.each do |pid, gs|
      gs.sort_by! { |g| g.seqno.to_i }
      gs.each_cons(2) do |a, b|
        next if seen[[a.id, b.id]]

        seen[[a.id, b.id]] = true
        winner = ko_game_winner(a)
        kind = winner && winner.player_id == pid ? "win" : "loss"
        edges << { from: a.id, to: b.id, kind: kind, player_id: pid }
      end
    end
    edges
  end

  def hash_diff(first, second)
    first
      .dup
      .delete_if { |k, v| second[k] == v }
      .merge!(second.dup.delete_if { |k, _v| first.has_key?(k) })
  end

  # Prüft ob Turnier läuft oder abgeschlossen ist
  def tournament_active_or_finished?(tournament)
    tournament.tournament_started || 
    %w[playing_groups playing_finals finals_finished results_published].include?(tournament.state)
  end

  # Gibt Tournament Monitor zurück falls vorhanden
  def tournament_monitor_for_status(tournament)
    tournament.tournament_monitor
  end

  # Berechnet Gruppen für Status-Anzeige
  def tournament_groups_for_status(tournament)
    return nil unless tournament.tournament_plan.present?
    
    tournament_monitor = tournament.tournament_monitor
    return nil unless tournament_monitor.present?
    
    # Versuche Gruppen aus Tournament Monitor zu holen
    if tournament_monitor.data['groups'].present?
      tournament_monitor.data['groups']
    else
      # Berechne Gruppen neu (Plan 32-03: effective_seedings statt dupliziertem has_local-Idiom)
      TournamentMonitor.distribute_to_group(
        tournament.effective_seedings.where.not(state: "no_show").order(:position).map(&:player),
        tournament.tournament_plan.ngroups,
        tournament.tournament_plan.group_sizes
      )
    end
  end

  # Gibt aktuelle Runde zurück
  def tournament_current_round(tournament)
    tournament.tournament_monitor&.current_round
  end

  # Gibt Anzahl gespielter vs. gesamt Spiele zurück
  def tournament_games_progress(tournament)
    game_scope = tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").count > 0 ? 
                 "games.id >= #{Game::MIN_ID}" : 
                 "games.id < #{Game::MIN_ID}"
    
    total_games = tournament.games.where(game_scope).count
    finished_games = tournament.games.where(game_scope).where.not(ended_at: nil).count
    
    { finished: finished_games, total: total_games }
  end

  # Prüft ob User Spielleiter ist (club_admin)
  def tournament_director?(user)
    user&.club_admin? || user&.system_admin?
  end

  # Plan 26-01: Vereinsauswahl für die Meldeliste eines Region-Turniers.
  #
  # Liefert [[label, id], ...] für ein select — Vereine der ausrichtenden Region, "die wichtigsten
  # zuerst", ohne neue Datenhaltung und ohne Konfiguration:
  #   1. Vereine, aus denen bereits Teilnehmer DIESES Turniers gemeldet sind (wächst mit der Meldung)
  #   2. Verein(e) des Austragungsorts
  #   3. alle übrigen alphabetisch
  # Ist keine Region bestimmbar, bleibt die Liste leer — der Helfer errät nichts.
  def entry_list_clubs_for(tournament)
    region = tournament.region || (tournament.organizer if tournament.organizer.is_a?(Region))
    return [] if region.blank?

    clubs = Club.where(region_id: region.id).order(:name).to_a
    return [] if clubs.empty?

    # Vereinszugehörigkeit über SeasonParticipation der TURNIERSAISON — dieselbe Quelle wie
    # TournamentsController#players_by_club. (Player hat zwar eine club_id-Spalte, aber kein
    # belongs_to :club; maßgeblich ist season_participations.club_id.)
    seeded_player_ids = tournament.seedings.pluck(:player_id).compact
    seeded_club_ids = if seeded_player_ids.any?
      SeasonParticipation
        .where(player_id: seeded_player_ids, season_id: tournament.season_id)
        .pluck(:club_id).compact.to_set
    else
      Set.new
    end
    # Location hat KEIN belongs_to :club (club_id ist ignored_column) — der Bezug läuft über
    # club_locations, es können mehrere Vereine an einem Spielort sein.
    location_club_ids = Array(tournament.location&.clubs&.map(&:id)).to_set

    ranked, rest = clubs.partition { |c| seeded_club_ids.include?(c.id) || location_club_ids.include?(c.id) }
    # Innerhalb der Vorauswahl: Vereine mit Meldungen vor reinen Austragungsort-Vereinen.
    ranked.sort_by! { |c| [seeded_club_ids.include?(c.id) ? 0 : 1, c.name.to_s] }

    ranked.map { |c| [c.name, c.id] } + rest.map { |c| [c.name, c.id] }
  end
end
