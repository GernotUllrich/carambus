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
        TournamentMonitor.ranking(@tournament_monitor.data["rankings"]["endgames"]["group#{g_no}"],
                                  order: (
                                    if @tournament_monitor.tournament.handicap_tournier?
                                      %i[points
                                         gd_pct]
                                    else
                                      %i[points
                                         gd]
                                    end))[rk_no.to_i - 1].andand[0]
      when /^g/
        TournamentMonitor.ranking(@tournament_monitor.data["rankings"]["groups"]["group#{g_no}"],
                                  order: (
                                    if @tournament_monitor.tournament.handicap_tournier?
                                      %i[points
                                         gd_pct]
                                    else
                                      %i[points
                                         gd]
                                    end))[rk_no.to_i - 1].andand[0]
      else
        nil
      end
    elsif (m = rule_str.match(/^(64f|32f|16f|8f|vf|hf|rule|af|qf|fin|p<\d+(?:-|\.\.)\d+>)(\d+)?/))
      TournamentMonitor.ranking(@tournament_monitor.data["rankings"]["endgames"]["#{m[1]}#{m[2]}"],
                                order: (
                                  if @tournament_monitor.tournament.handicap_tournier?
                                    %i[points
                                       gd_pct]
                                  else
                                    %i[points
                                       gd]
                                  end))[rk_no.to_i - 1].andand[0]

    elsif /^sl/.match?(rule_str)
      @tournament_monitor.tournament.seedings.where("id > #{Seeding::MIN_ID}").to_a[rk_no.to_i - 1]&.player_id
    end
  end

  def group_rank(match)
    group_no = match[1]
    seeding_index = match[2].to_i
    seeding_scope = if @tournament_monitor.tournament
                       .seedings
                       .where("seedings.id >= #{Seeding::MIN_ID}")
                       .count.positive?
                      "seedings.id >= #{Seeding::MIN_ID}"
                    else
                      "seedings.id< #{Seeding::MIN_ID}"
                    end
    # D-05: Direkter Aufruf von PlayerGroupDistributor — kein Umweg über TournamentMonitor.distribute_to_group
    groups = TournamentMonitor::PlayerGroupDistributor.distribute_to_group(
      @tournament_monitor.tournament.seedings.where(seeding_scope).order(:position).map(&:player),
      @tournament_monitor.tournament.tournament_plan.ngroups,
      @tournament_monitor.tournament.tournament_plan.group_sizes # NEU: Gruppengrößen aus executor_params
    )
    # distribute_to_group now returns player IDs directly, not player objects
    groups["group#{group_no}"][seeding_index - 1]
  end

  def random_from_group_ranks(match, ordered_ranking_nos, rule_str)
    ordered_ranking_nos[rule_str] ||= (match[2].to_i..match[3].to_i).to_a.shuffle
    inter_group_order = if @tournament_monitor.tournament.gd_has_prio?
                          @tournament_monitor.tournament.handicap_tournier? ? %i[gd_pct points] : %i[gd points]
                        else
                          (@tournament_monitor.tournament.handicap_tournier? ? %i[points gd_pct] : %i[points gd])
                        end
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
          TournamentMonitor.ranking(@tournament_monitor.data["rankings"]["endgames"]["group#{g_no}"],
                                    order: (
                                      if @tournament_monitor.tournament.handicap_tournier?
                                        %i[points
                                           gd_pct]
                                      else
                                        %i[points gd]
                                      end))[rk_no.to_i - 1]
        when /^g/
          TournamentMonitor.ranking(@tournament_monitor.data["rankings"]["groups"]["group#{g_no}"],
                                    order: (
                                      if @tournament_monitor.tournament.handicap_tournier?
                                        %i[points
                                           gd_pct]
                                      else
                                        %i[points gd]
                                      end))[rk_no.to_i - 1]
        else
          nil
        end
      subset.merge!(Hash[*rk])
    end
    TournamentMonitor.ranking(subset, order: inter_group_order)[rank.to_i - 1].andand[0]
  end

  def rank_from_group_ranks(match, opts = {})
    inter_group_order = if @tournament_monitor.tournament.gd_has_prio?
                          @tournament_monitor.tournament.handicap_tournier? ? %i[gd_pct points] : %i[gd points]
                        else
                          (@tournament_monitor.tournament.handicap_tournier? ? %i[points gd_pct] : %i[points gd])
                        end
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
          TournamentMonitor.ranking(@tournament_monitor.data["rankings"]["endgames"]["group#{g_no}"],
                                    order: (
                                      if @tournament_monitor.tournament.handicap_tournier?
                                        %i[points
                                           gd_pct]
                                      else
                                        %i[points gd]
                                      end))[rk_no.to_i - 1]
        when /^g/
          TournamentMonitor.ranking(@tournament_monitor.data["rankings"]["groups"]["group#{g_no}"],
                                    order: (
                                      if @tournament_monitor.tournament.handicap_tournier?
                                        %i[points
                                           gd_pct]
                                      else
                                        %i[points gd]
                                      end))[rk_no.to_i - 1]
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
