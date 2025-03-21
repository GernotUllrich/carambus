class RankingsController < ApplicationController
  def index
    @regions = Region.having_rankings
                    .includes(:country)
                    .order(:name)
  end

  def show
    @region = Region.find(params[:id])
    @current_season = Season.current_season

    # Get the last 3 seasons in reverse chronological order
    @seasons = Season.where('id <= ?', @current_season.id)
                    .order(id: :desc)
                    .limit(3  )
                    .reverse

    # Initialize @rankings_by_player by grouping rankings by player and discipline, restricted to the region
    @rankings_by_player = PlayerRanking.where(
      season_id: @seasons.pluck(:id),
      region_id: @region.id
    )
    .group_by { |ranking| [ranking.player_id, ranking.discipline_id] }

    # 1. Aggregate discipline counts for games with a valid data["Disziplin"]
    counts_with_data = Game.joins(tournament: :discipline)
                           .where(tournaments: {
                             organizer_type: 'Region',
                             organizer_id: @region.id,
                             season_id: @seasons.pluck(:id)
                           })
                           .where.not(games: { data: nil }) # Ensure data is not nil
                           .where("games.data::jsonb ->> 'Disziplin' != ''") # Ensure Disziplin is not empty
                           .group("LOWER(TRIM(games.data::jsonb ->> 'Disziplin'))")
                           .order(Arel.sql('COUNT(*) DESC'))
                           .count

    # 2. Aggregate discipline counts for games without a valid data["Disziplin"]
    counts_without_data = Game.joins(tournament: :discipline)
                              .where(tournaments: {
                                organizer_type: 'Region',
                                organizer_id: @region.id,
                                season_id: @seasons.pluck(:id)
                              })
                              .where("games.data::jsonb ->> 'Disziplin' IS NULL OR TRIM(games.data::jsonb ->> 'Disziplin') = ''")
                              .group("LOWER(disciplines.name)")
                              .order(Arel.sql('COUNT(*) DESC'))
                              .count

    # 3. Merge the two counts, summing the counts for overlapping disciplines
    discipline_counts = counts_with_data.merge(counts_without_data) do |key, old_count, new_count|
      old_count + new_count
    end

    # Extract the discipline names from the counts
    discipline_names = discipline_counts.keys

    # Fetch Discipline records in bulk matching the normalized discipline names
    disciplines = Discipline.where("LOWER(name) IN (?)", discipline_names)
                            .index_by { |d| d.name.downcase.strip }

    # Sort disciplines based on counts descending
    @disciplines = discipline_counts.sort_by { |name, _count| -_count }
                                   .map { |name, _count| disciplines[name] }
                                   .compact

    # Pre-calculate game data for charts with optimizations to prevent browser hangs
    @chart_data = {}

    # Get only the necessary player and discipline combinations that appear in the rankings
    player_discipline_pairs = @rankings_by_player.keys

    # Bail early if there are too many combinations to prevent browser overload
    if player_discipline_pairs.size > 100
      Rails.logger.warn "Too many player-discipline combinations (#{player_discipline_pairs.size}). Limiting to first 100."
      player_discipline_pairs = player_discipline_pairs.first(100)
    end

    # Use a more efficient query to get all needed game participations in one go
    player_ids = player_discipline_pairs.map(&:first).uniq

    # Fetch all relevant GameParticipations in a single query with limit to prevent memory issues
    game_participations = GameParticipation.joins(game: :tournament)
                                          .where(
                                            tournaments: {
                                              organizer_type: 'Region',
                                              organizer_id: @region.id,
                                              season_id: @seasons.pluck(:id)
                                            },
                                            player_id: player_ids
                                          )
                                          .includes(:player, game: :tournament)
                                          .order('tournaments.date DESC')
                                          .limit(10000) # Safety limit

    # Pre-group GameParticipations by [player_id, tournament_id] to optimize processing
    grouped_game_participations = game_participations.group_by { |gp| [gp.player_id, gp.game.tournament_id] }

    # Process only a reasonable number of tournaments per player to prevent browser hangs
    processed_count = 0
    max_tournaments_per_player = 25  # Limit number of tournaments per player

    grouped_game_participations.each do |(player_id, tournament_id), gps_in_tournament|
      # Skip after a reasonable number of data points
      processed_count += 1
      if processed_count > 1000
        Rails.logger.warn "Reached maximum tournament processing limit (1000). Some charts may be incomplete."
        break
      end

      # Define a local variable for tournament_date based on the tournament_id
      tournament_date = gps_in_tournament.first.game.tournament.date.iso8601

      # Extract disciplines present in this group
      disciplines_in_group = gps_in_tournament.map { |gp_inner| gp_inner.game.data["Disziplin"].to_s.downcase.strip }
                                           .uniq

      disciplines_in_group.each do |discipline_name|
        discipline = @disciplines.find { |d| d.name.downcase.strip == discipline_name }

        # Skip if discipline is not found
        unless discipline.present?
          next
        end

        # Use a string as the key
        key = "#{player_id},#{discipline.id}"

        # Skip if this player-discipline pair isn't in our rankings
        next unless player_discipline_pairs.include?([player_id, discipline.id])

        # Skip if we've already processed enough tournaments for this player-discipline
        if @chart_data[key] && @chart_data[key][:tournaments].size >= max_tournaments_per_player
          next
        end

        @chart_data[key] ||= { individual_games: [], tournaments: [] }

        # Select GameParticipations matching the player, tournament, and discipline
        gps_matching = gps_in_tournament.select do |gp_inner|
          gp_inner.game.data["Disziplin"].to_s.downcase.strip == discipline_name
        end

        # Calculate average_gd for the tournament, handling division by zero
        average_gd = gps_matching.present? ? gps_matching.map(&:gd).compact.sum.to_f / gps_matching.size : 0

        # Add individual game data (limit to avoid browser overload)
        if @chart_data[key][:individual_games].size < 200  # Limit individual games
          gps_matching.each do |gp|
            # Use tournament date instead of game date
            tournament = gp.game.tournament
            @chart_data[key][:individual_games] << [tournament.date.iso8601, gp.gd, tournament.id]
          end
        end

        # Add to tournaments array with the correct tournament_date and ID
        if @chart_data[key][:tournaments].size < max_tournaments_per_player
          @chart_data[key][:tournaments] << {
            id: gps_in_tournament.first.game.tournament_id,
            date: tournament_date,
            average: average_gd
          }
        end
      end
    end

    # Initialize missing @chart_data keys for all player-discipline combinations
    player_discipline_pairs.each do |key_array|
      player_id, discipline_id = key_array
      key = "#{player_id},#{discipline_id}"
      @chart_data[key] ||= { individual_games: [], tournaments: [] }
    end

    # Sort the data chronologically to ensure proper chart display
    @chart_data.each do |_key, data|
      begin
        # Sort individual games by date
        data[:individual_games].sort_by! { |date, _| date } if data[:individual_games].present?

        # Sort tournaments by date
        data[:tournaments].sort_by! { |t| t[:date] } if data[:tournaments].present?

        # Limit data size to prevent browser hangs
        data[:individual_games] = data[:individual_games].last(150) if data[:individual_games].size > 150
        data[:tournaments] = data[:tournaments].last(25) if data[:tournaments].size > 25
      rescue => e
        Rails.logger.error "Error sorting chart data: #{e.message}"
      end
    end
  end

  private

  def calculate_three_year_gd(player_id, discipline_id)
    rankings = @rankings_by_player[[player_id, discipline_id]] || []

    # Map seasons to GD values in chronological order
    gd_values = @seasons.map do |season|
      ranking = rankings.find { |r| r.season_id == season.id }
      [ranking&.gd, ranking&.btg]
    end

    # Calculate effective GD (current || previous || previous-1)
    effective_gd = gd_values[2]&.first || gd_values[1]&.first || gd_values[0]&.first

    {
      gd_values: gd_values,
      effective_gd: effective_gd
    }
  end
  helper_method :calculate_three_year_gd
end
