# frozen_string_literal: true

# Reiner Algorithmus zur Spielerverteilung auf Gruppen.
# Extrahiert aus TournamentMonitor als PORO (kein ApplicationService).
#
# Verantwortlichkeiten:
#   - Konstanten DIST_RULES, GROUP_RULES, GROUP_SIZES für NBV-konforme Verteilung
#   - distribute_to_group: Verteilt Spieler auf n Gruppen per Zig-Zag oder Round-Robin
#   - distribute_with_sizes: Verteilt Spieler auf Gruppen mit vorgegebenen Größen
#
# Verwendung:
#   TournamentMonitor::PlayerGroupDistributor.distribute_to_group(players, ngroups)
#   TournamentMonitor::PlayerGroupDistributor.distribute_with_sizes(players, ngroups, sizes)
class TournamentMonitor::PlayerGroupDistributor
  DIST_RULES = {
    6 => [[1, 2], [4, 3], [6, 5]],
    7 => [[1, 2], [4, 3], [5, 6], [0, 7]],
    8 => [[1, 2], [4, 3], [5, 6], [8, 7]],
    9 => [[1, 2, 3], [4, 5, 6], [9, 8, 7]],
    10 => [[1, 2], [4, 3], [5, 6], [7, 8], [10, 9]],
    11 => [[1, 2, 3], [4, 5, 6], [7, 8, 9], [0, 11, 10]],
    12 => [[1, 2, 3], [6, 5, 4], [7, 8, 9], [12, 11, 10]],
    13 => [[1, 2, 3, 4], [8, 6, 7, 5], [9, 12, 10, 11], [13, 0, 0, 0]],
    14 => [[1, 2, 3, 4], [8, 6, 7, 5], [9, 12, 10, 11], [13, 14, 0, 0]],
    15 => [[1, 2, 3, 4], [8, 6, 7, 5], [9, 10, 11, 12], [15, 14, 13, 0]],
    16 => [[1, 2, 3, 4], [8, 6, 7, 5], [9, 10, 11, 12], [16, 15, 14, 13]]
  }.freeze

  GROUP_RULES = {
    6 => [[1, 4, 6], [2, 3, 5]],
    7 => [[1, 4, 5, 0], [2, 3, 6, 7]],
    8 => [[1, 4, 5, 8], [2, 3, 6, 7]],
    9 => [[1, 4, 9], [2, 5, 8], [3, 6, 7]],
    10 => [[1, 4, 5, 7, 10], [2, 3, 6, 8, 9]],
    11 => [[1, 4, 7, 0], [2, 5, 8, 11], [3, 6, 9, 10]],
    12 => [[1, 6, 7, 12], [2, 5, 8, 11], [3, 4, 9, 10]],
    13 => [[1, 8, 9, 13], [2, 6, 12], [3, 7, 10], [4, 5, 11]],
    14 => [[1, 8, 9, 13], [2, 6, 12, 14], [3, 7, 10], [4, 5, 11]],
    15 => [[1, 8, 9, 15], [2, 6, 10, 14], [3, 7, 11, 13], [4, 5, 12]],
    16 => [[1, 8, 9, 16], [2, 6, 10, 15], [3, 7, 11, 14], [4, 5, 12, 13]]
  }.freeze

  GROUP_SIZES = {
    6 => [3, 3],
    7 => [3, 4],
    8 => [4, 4],
    9 => [3, 3, 3],
    10 => [5, 5],
    11 => [3, 4, 4],
    12 => [4, 4, 4],
    13 => [4, 3, 3, 3],
    14 => [4, 4, 3, 3],
    15 => [4, 4, 4, 3],
    16 => [4, 4, 4, 4]
  }.freeze

  def self.distribute_to_group(players, ngroups, group_sizes = nil)
    groups = {}
    (1..ngroups).each do |group_no|
      groups["group#{group_no}"] = []
    end

    # Wenn group_sizes gegeben: Verwende size-aware Algorithmus
    if group_sizes.present? && group_sizes.is_a?(Array)
      return distribute_with_sizes(players, ngroups, group_sizes)
    elsif ngroups == 0 || ngroups == GROUP_SIZES[players.count].count
      group_sizes = GROUP_SIZES[players.count]
      ngroups = group_sizes.count
      return distribute_with_sizes(players, ngroups, group_sizes)
    end

    # NBV-konformer Algorithmus (abhängig von Gruppenzahl)
    # 2 Gruppen: Zig-Zag/Serpentinen (1→G1, 2→G2, 3→G2, 4→G1, 5→G1, ...)
    # 4+ Gruppen: Round-Robin (1→G1, 2→G2, 3→G3, 4→G4, 5→G1, ...)

    if ngroups == 2
      # Zig-Zag für 2 Gruppen (NBV T07, T10, etc.)
      group_ix = 1
      direction_right = true
      players.each do |player|
        player_id = player.is_a?(Integer) ? player : player.id
        groups["group#{group_ix}"] << player_id

        if direction_right
          group_ix += 1
          if group_ix > ngroups
            direction_right = false
            group_ix = ngroups
          end
        else
          group_ix -= 1
          if group_ix <= 0
            direction_right = true
            group_ix = 1
          end
        end
      end
    else
      # Round-Robin für 3+ Gruppen (NBV T14, T27, T28, etc.)
      players.each_with_index do |player, index|
        player_id = player.is_a?(Integer) ? player : player.id
        group_no = (index % ngroups) + 1
        groups["group#{group_no}"] << player_id
      end
    end

    groups
  rescue StandardError => e
    Tournament.logger.info "distribute_to_group(#{players}, #{ngroups}) #{e} #{e.backtrace&.join("\n")}"
    {}
  end

  # Verteilt Spieler auf Gruppen mit spezifischen Gruppengrößen
  # NBV-Algorithmus: Round-Robin, dann größere Gruppen von hinten auffüllen
  def self.distribute_with_sizes(players, ngroups, group_sizes)
    players_count = players.count
    groups = {}
    group_fill_count = {}

    (1..ngroups).each do |group_no|
      groups["group#{group_no}"] = []
      group_fill_count[group_no] = 0
    end

    if group_sizes == GROUP_SIZES[players_count]
      GROUP_RULES[players_count].each_with_index do |group_positions, ix|
        group_positions.each do |pos|
          next if pos == 0 # Skip placeholder positions

          player_id = players[pos - 1].is_a?(Integer) ? players[pos - 1] : players[pos - 1].id
          groups["group#{ix + 1}"] << player_id
        end
      end
      return groups
    end
    # Phase 1: Standard Round-Robin bis alle Gruppen mindestens min_size erreichen
    min_size = group_sizes.min
    players_for_phase1 = min_size * ngroups

    players[0...players_for_phase1].each_with_index do |player, index|
      player_id = player.is_a?(Integer) ? player : player.id
      group_no = (index % ngroups) + 1
      groups["group#{group_no}"] << player_id
      group_fill_count[group_no] += 1
    end

    # Phase 2: Restliche Spieler gehen in größere Gruppen (von hinten nach vorne!)
    remaining_players = players[players_for_phase1..-1] || []

    # Finde Gruppen die noch Platz haben (sortiert nach Gruppe, absteigend!)
    groups_with_space = (1..ngroups).to_a.reverse.select do |gn|
      max_size = group_sizes[gn - 1]
      group_fill_count[gn] < max_size
    end

    remaining_players.each_with_index do |player, index|
      player_id = player.is_a?(Integer) ? player : player.id

      if groups_with_space.any?
        target_group = groups_with_space.shift # Nimm erste verfügbare (von hinten!)
        groups["group#{target_group}"] << player_id
        group_fill_count[target_group] += 1

        # Wenn Gruppe jetzt voll: entferne sie aus der Liste
        max_size = group_sizes[target_group - 1]
        groups_with_space << target_group if group_fill_count[target_group] < max_size
      else
        Tournament.logger.warn "distribute_with_sizes: Konnte Spieler #{players_for_phase1 + index + 1} nicht zuordnen!"
      end
    end

    groups
  end
end
