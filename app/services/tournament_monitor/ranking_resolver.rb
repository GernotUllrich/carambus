# frozen_string_literal: true

# Löst Spieler-IDs aus Ranking-Regelstrings auf.
# Extrahiert aus TournamentMonitor als PORO (kein ApplicationService), per D-04.
#
# Verantwortlichkeiten:
#   - player_id_from_ranking: Wertet Ranking-Regelstrings aus (sl.rk, g, rule, KO-Ausdrücke)
#   - ko_ranking: Löst KO-Bracket-Referenzen auf (sl.rk, fg, g, qf, hf, fin, ...)
#   - group_rank: Löst Gruppenrang-Referenzen auf (g1.2 → 2. Spieler in Gruppe 1)
#   - random_from_group_ranks: Zufällige Auswahl aus gruppenübergreifenden Ranglisten
#   - rank_from_group_ranks: Deterministischer Rang aus gruppenübergreifenden Ranglisten
#
# Querverweis (D-05): group_rank ruft PlayerGroupDistributor.distribute_to_group
# direkt auf — kein Umweg über TournamentMonitor.distribute_to_group.
#
# Verwendung:
#   TournamentMonitor::RankingResolver.new(tournament_monitor).player_id_from_ranking(rule_str, opts)
class TournamentMonitor::RankingResolver
  def initialize(tournament_monitor)
    @tournament_monitor = tournament_monitor
  end

  # §4.4.2 NBV-Ordnung: Platzierung bei Turnieren jeder gegen jeden (ebenso bei Gruppen)
  # nach Punkten, dann GD (bzw. gd_pct bei Handicap), dann BED, dann Höchstserie.
  # "Direkter Vergleich" (Stufe 3 der Ordnung) ist hier bewusst NICHT enthalten — er lässt
  # sich nicht als zusätzlicher Sortierschlüssel ausdrücken (gilt nur relativ zu genau den
  # gerade gleichauf liegenden Spielern), siehe Plan 03-02.
  def group_standing_order
    if @tournament_monitor.tournament.handicap_tournier?
      %i[points gd_pct bed hs]
    else
      %i[points gd bed hs]
    end
  end

  # §4.4.2 fuer die Cross-Gruppen-Rangfolge: nach welcher Ordnung Spieler aus VERSCHIEDENEN
  # Gruppen gegeneinander gereiht werden (Regelstrings der Form "(g1.rk4 + g2.rk4).rk2" —
  # "der Zweitbeste unter den Gruppenvierten"). Betreiber-Entscheidung 2026-09-04:
  # §4.4.2 gilt auch hier, also Punkte -> GD -> BED -> Hoechstserie.
  #
  # Bei `gd_has_prio?` sind die ersten beiden Stufen bewusst VERTAUSCHT (GD vor Punkten) —
  # eine Turnier-Option, kein Versehen. BED und HS werden in beiden Faellen angehaengt.
  #
  # "Direkter Vergleich" (Stufe 3 der Ordnung) fehlt hier ABSICHTLICH, anders als in
  # group_standing_ranking: head_to_head_winner sucht die gemeinsame Partie ueber
  # `gname LIKE "{prefix}{group_no}:%"`, also innerhalb EINER Gruppe. Cross-Gruppen-
  # Nachruecker haben per Definition in verschiedenen Gruppen gespielt — es gibt dort in
  # aller Regel keine gemeinsame Partie, die Stufe liefe ins Leere. Der Unterschied zur
  # Gruppenwertung ist damit belegt und keine Inkonsistenz (Plan 07-01).
  def inter_group_order
    if @tournament_monitor.tournament.gd_has_prio?
      @tournament_monitor.tournament.handicap_tournier? ? %i[gd_pct points bed hs] : %i[gd points bed hs]
    else
      @tournament_monitor.tournament.handicap_tournier? ? %i[points gd_pct bed hs] : %i[points gd bed hs]
    end
  end

  # Findet die gemeinsame(n) Partie(n) zweier Spieler innerhalb einer Gruppe (oder
  # Endspielgruppe) und summiert ihre Punkte über alle Begegnungen (Doppelrunden-sicher:
  # gname trägt bei repeats>1 ein "/{rp}"-Suffix, das hier keine Rolle spielt, weil wir über
  # den group_prefix+group_no-Präfix suchen, nicht den exakten gname).
  # Gibt player_a_id/player_b_id (unveraendert, wie uebergeben) des Siegers zurueck, oder
  # nil bei fehlender Partie oder Gleichstand.
  #
  # player_a_id/player_b_id kommen bei den eigentlichen Aufrufstellen aus
  # @tournament_monitor.data["rankings"]... — nach dem JSON-Rundtrip der data-Spalte sind
  # das STRING-Keys, waehrend GameParticipation#player_id ein Integer ist. Fuer den
  # DB-Abgleich wird deshalb intern auf Integer normalisiert (pa/pb); der Rueckgabewert
  # echot player_a_id/player_b_id UNVERAENDERT zurueck, damit ein Aufrufer wie
  # group_standing_ranking per einfachem `case winner when id_a` typkonsistent vergleichen
  # kann, ohne selbst erneut konvertieren zu muessen.
  def head_to_head_winner(group_prefix, group_no, player_a_id, player_b_id)
    pa, pb = player_a_id.to_i, player_b_id.to_i

    # Kein zusaetzlicher id>=MIN_ID-Filter: @tournament_monitor.tournament.games ist bereits
    # ueber die Tournament-FK auf genau dieses (lokale) Turnier begrenzt.
    games = @tournament_monitor.tournament.games
      .where("games.gname LIKE ?", "#{group_prefix}#{group_no}:%")
      .includes(:game_participations)
      .select { |g| g.game_participations.map(&:player_id).sort == [pa, pb].sort }

    return nil if games.empty?

    points_a = games.sum { |g| g.game_participations.find { |gp| gp.player_id == pa }&.points.to_i }
    points_b = games.sum { |g| g.game_participations.find { |gp| gp.player_id == pb }&.points.to_i }

    return player_a_id if points_a > points_b
    return player_b_id if points_b > points_a

    nil
  end

  # §4.4.2 vollständig: Punkte -> GD/gd_pct -> direkter Vergleich (nur bei exakt 2 Gleichen,
  # Entscheidung 2026-09-03) -> BED -> Höchstserie. Ersetzt die reine order:-Weitergabe an
  # TournamentMonitor.ranking aus Plan 03-01, weil "direkter Vergleich" sich nicht als
  # zusätzlicher Sortierschlüssel in eine gewichtete Summe einfügen lässt — er gilt nur
  # relativ zu genau den Spielern, die nach Punkten+GD gleichauf liegen.
  def group_standing_ranking(hash, group_prefix, group_no)
    primary_order = @tournament_monitor.tournament.handicap_tournier? ? %i[points gd_pct] : %i[points gd]
    primary = TournamentMonitor.ranking(hash, order: primary_order)

    # Punkte/GD werden im Code durchgaengig auf 2 Nachkommastellen gerundet gespeichert
    # (format("%.2f", ...).to_f, siehe ResultProcessor#add_result_to) — auf dieselbe
    # Praezision runden statt blankem Float-== (Lint/FloatComparison), sonst koennten
    # Rundungsartefakte echte Gleichstaende verdecken oder vortaeuschen.
    clusters = primary.chunk_while do |(_, a), (_, b)|
      primary_order.all? { |k| a[k.to_s].to_f.round(2) == b[k.to_s].to_f.round(2) }
    end

    clusters.flat_map do |cluster|
      if cluster.size == 2
        id_a, id_b = cluster[0][0], cluster[1][0]
        winner = head_to_head_winner(group_prefix, group_no, id_a, id_b)
        case winner
        when id_a then cluster
        when id_b then cluster.reverse
        else TournamentMonitor.ranking(cluster.to_h, order: %i[bed hs])
        end
      elsif cluster.size == 1
        cluster
      else
        TournamentMonitor.ranking(cluster.to_h, order: %i[bed hs])
      end
    end
  end

  def player_id_from_ranking(rule_str, opts = {})
    ordered_ranking_nos = opts[:ordered_ranking_nos]
    if (mm = rule_str.match(/\((.*)\)\.rk(\d+)$/).presence)
      # rule_str: "(g1.rk4 + g2.rk4 +g3.rk4).rk2"
      rank_from_group_ranks(mm, opts)
    elsif (mm = rule_str.match(/\((.*)\)\.rk-rand-(\d+)-(\d+)$/).presence)
      # rule_str: "(g1.rk4 + g2.rk4 +g3.rk4).rk-rand-1-4"
      random_from_group_ranks(mm, ordered_ranking_nos, rule_str)
    elsif (mm = rule_str.match(/g(\d+).(\d+)$/).presence)
      group_rank(mm)
    elsif (mm = rule_str.match(/(rule\d+)/)).presence
      player_id_from_ranking(opts[:executor_params]["rules"][mm[1]], opts)
    else
      ko_ranking(rule_str)
    end
  rescue StandardError => e
    Tournament.logger.info "player_id_from_ranking(#{rule_str}) #{e} #{e.backtrace&.join("\n")}"
    nil
  end

  private

  def ko_ranking(rule_str)
    match_result = rule_str.match(/^(?:(?:fg|g)(\d+)|sl|rule|64f|32f|16f|8f|vf|hf|af|qf|fin|p<\d+(?:\.\.|-)\d+>)(\d+)?\.rk(\d+)$/)
    return nil unless match_result

    g_no, _game_no, rk_no = match_result[1..3]
    if g_no.present?
      case rule_str
      when /^sl/
        @tournament_monitor.tournament.seedings.where("id > #{Seeding::MIN_ID}").to_a[rk_no.to_i - 1]&.player_id
      when /^fg/
        group_standing_ranking(@tournament_monitor.data["rankings"]["endgames"]["group#{g_no}"],
          "fg", g_no)[rk_no.to_i - 1].andand[0]
      when /^g/
        group_standing_ranking(@tournament_monitor.data["rankings"]["groups"]["group#{g_no}"],
          "group", g_no)[rk_no.to_i - 1].andand[0]
      else
        nil
      end
    elsif (m = rule_str.match(/^(64f|32f|16f|8f|vf|hf|rule|af|qf|fin|p<\d+(?:-|\.\.)\d+>)(\d+)?/))
      # Bracket-Ebene ohne Gruppenpaarung (gname hat kein ":{i1}-{i2}"-Format) — kein
      # direkter Vergleich moeglich/sinnvoll hier, siehe Plan 03-02 Boundaries. Bleibt bei
      # der einfachen order:-Sortierung aus Plan 03-01 (Punkte/GD/BED/HS).
      TournamentMonitor.ranking(@tournament_monitor.data["rankings"]["endgames"]["#{m[1]}#{m[2]}"],
                                order: group_standing_order)[rk_no.to_i - 1].andand[0]

    elsif /^sl/.match?(rule_str)
      @tournament_monitor.tournament.seedings.where("id > #{Seeding::MIN_ID}").to_a[rk_no.to_i - 1]&.player_id
    end
  end

  def group_rank(match)
    group_no = match[1]
    seeding_index = match[2].to_i
    # Plan 32-03: effective_seedings (lokale bevorzugen, sonst ClubCloud) statt dupliziertem has_local-Idiom
    # D-05: Direkter Aufruf von PlayerGroupDistributor — kein Umweg über TournamentMonitor.distribute_to_group
    groups = TournamentMonitor::PlayerGroupDistributor.distribute_to_group(
      @tournament_monitor.tournament.effective_seedings.order(:position).map(&:player),
      @tournament_monitor.tournament.tournament_plan.ngroups,
      @tournament_monitor.tournament.tournament_plan.group_sizes # NEU: Gruppengrößen aus executor_params
    )
    # distribute_to_group now returns player IDs directly, not player objects
    groups["group#{group_no}"][seeding_index - 1]
  end

  def random_from_group_ranks(match, ordered_ranking_nos, rule_str)
    ordered_ranking_nos[rule_str] ||= (match[2].to_i..match[3].to_i).to_a.shuffle
    players = match[1]
    rank = ordered_ranking_nos[rule_str].pop
    subset = {}
    members = players.split(/\s*\+\s*/)
    members.each do |member|
      g_no, _game_no, rk_no = member.match(/^(?:(?:fg|g)(\d+)|sl|rule|64f|32f|16f|8f|vf|hf|af|qf|fin
|p<\d+(?:\.\.|-)\d+>)(\d+)?\.rk(\d)$/)[1..3]
      rk =
        case member
        when /^sl/
          @tournament_monitor.tournament.seedings.where("id > #{Seeding::MIN_ID}").to_a[rk_no.to_i - 1].player_id
        when /^fg/
          group_standing_ranking(@tournament_monitor.data["rankings"]["endgames"]["group#{g_no}"],
            "fg", g_no)[rk_no.to_i - 1]
        when /^g/
          group_standing_ranking(@tournament_monitor.data["rankings"]["groups"]["group#{g_no}"],
            "group", g_no)[rk_no.to_i - 1]
        else
          nil
        end
      subset.merge!(Hash[*rk])
    end
    TournamentMonitor.ranking(subset, order: inter_group_order)[rank.to_i - 1].andand[0]
  end

  def rank_from_group_ranks(match, opts = {})
    players = match[1]
    rank = match[2]
    subset = {}
    members = players.split(/\s*\+\s*/)
    members.each do |member|
      member += ".rk1" if /rule\d/.match?(member)
      g_no, _game_no, rk_no = member.match(/^(?:(?:fg|g)(\d+)|sl|64f|32f|16f|8f|vf|hf|af|qf|rule|fin|p<\d+(?:\.\.|-)\d+>)(\d+)?\.rk(\d)$/)[1..3]
      rk =
        case member
        when /^sl/
          @tournament_monitor.tournament.seedings.where("id > #{Seeding::MIN_ID}").to_a[rk_no.to_i - 1].player_id
        when /^fg/
          group_standing_ranking(@tournament_monitor.data["rankings"]["endgames"]["group#{g_no}"],
            "fg", g_no)[rk_no.to_i - 1]
        when /^g/
          group_standing_ranking(@tournament_monitor.data["rankings"]["groups"]["group#{g_no}"],
            "group", g_no)[rk_no.to_i - 1]
        when /^rule/
          player_id = player_id_from_ranking(opts[:executor_params]["rules"][member.split(".")[0]], opts)
          [player_id, @tournament_monitor.data["rankings"]["groups"]["total"][player_id]]
        else
          next
        end
      subset.merge!(Hash[*rk])
    end
    TournamentMonitor.ranking(subset, order: inter_group_order)[rank.to_i - 1].andand[0]
  end
end
