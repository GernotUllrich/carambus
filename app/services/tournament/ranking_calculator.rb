# frozen_string_literal: true

# Kapselt die Ranking-Berechnungslogik aus dem Tournament-Modell in einen eigenstaendigen Service.
# Verantwortlichkeiten:
#   - Effektive Rankings fuer alle Spieler berechnen und im data-Hash cachen
#   - Seedings nach Wettkampf neu durchnummerieren (reorder_seedings)
#
# Verwendung:
#   Tournament::RankingCalculator.new(tournament).calculate_and_cache_rankings
#   Tournament::RankingCalculator.new(tournament).reorder_seedings
#
# PORO (kein ApplicationService) gemaess D-02 des Extraktionsplans.
class Tournament::RankingCalculator
  def initialize(tournament)
    @tournament = tournament
  end

  # Berechnet und cached die effektiven Rankings fuer alle Spieler.
  # Wird beim Finalisieren der Seedings aufgerufen (tournament_seeding_finished).
  # Nur fuer lokale Tournaments (id >= MIN_ID), nicht fuer ClubCloud-Records.
  def calculate_and_cache_rankings
    return unless @tournament.organizer.is_a?(Region) && @tournament.discipline.present?
    return unless @tournament.id.present? && @tournament.id >= Tournament::MIN_ID # Nur fuer lokale Tournaments

    Tournament.logger.info "[calculate_and_cache_rankings] for local tournament #{@tournament.id}"

    # Berechne Rankings basierend auf effective_gd (wie in define_participants)
    current_season = Season.current_season
    seasons = Season.where("id <= ?", current_season.id).order(id: :desc).limit(3).reverse

    # Lade alle Rankings fuer die Disziplin und Region
    all_rankings = PlayerRanking.where(
      discipline_id: @tournament.discipline_id,
      season_id: seasons.pluck(:id),
      region_id: @tournament.organizer_id
    ).to_a

    # Gruppiere nach Spieler
    rankings_by_player = all_rankings.group_by(&:player_id)

    # Berechne effective_gd fuer jeden Spieler (neueste Saison zuerst)
    player_effective_gd = {}
    rankings_by_player.each do |player_id, rankings|
      gd_values = seasons.map do |season|
        ranking = rankings.find { |r| r.season_id == season.id }
        ranking&.gd
      end
      # effective_gd = aktuellste Saison || Saison davor || Saison davor-1
      effective_gd = gd_values[2] || gd_values[1] || gd_values[0]
      player_effective_gd[player_id] = effective_gd if effective_gd.present?
    end

    # Sortiere Spieler nach effective_gd (absteigend) und ermittle Rang
    sorted_players = player_effective_gd.sort_by { |player_id, gd| -gd }
    player_rank = {}
    sorted_players.each_with_index do |(player_id, gd), index|
      player_rank[player_id] = index + 1
    end

    # Speichere in data Hash
    @tournament.data_will_change!
    @tournament.data ||= {}
    @tournament.data["player_rankings"] = player_rank
    @tournament.save!

    Tournament.logger.info "[calculate_and_cache_rankings] cached #{player_rank.size} player rankings"
  end

  def reorder_seedings
    l_seeding_ids = @tournament.seeding_ids
    l_seeding_ids.each_with_index do |seeding_id, ix|
      Seeding.find_by_id(seeding_id).update_columns(position: ix + 1)
    end
    @tournament.reload
  end
end
