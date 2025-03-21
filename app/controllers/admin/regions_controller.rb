module Admin
  class RegionsController < Admin::ApplicationController
    def show
      @region = Region.find(params[:id])
      @current_season = Season.current_season
      @disciplines = Discipline.all
      @dashboard = RegionDashboard.new

      # Get the last 3 seasons in reverse chronological order
      @seasons = Season.where('id <= ?', @current_season.id)
                      .order(id: :desc)
                      .limit(3)
                      .reverse

      # Prepare rankings for each discipline
      @rankings_by_discipline = @disciplines.each_with_object({}) do |discipline, hash|
        rankings = PlayerRanking.where(
          region: @region,
          discipline: discipline,
          season_id: @seasons.map(&:id)
        ).includes(player: :season_participations)

        # Group rankings by player
        player_rankings = rankings.group_by(&:player_id).map do |_, player_rankings|
          latest_ranking = player_rankings.max_by { |r| r.season_id }
          player = latest_ranking.player

          # Get player's current club through season participation
          current_club = player.season_participations
                              .find_by(season: @current_season)
                              &.club

          # Map seasons to GD values
          gd_values = @seasons.map do |season|
            ranking = player_rankings.find { |r| r.season_id == season.id }
            ranking&.gd
          end

          # Calculate effective GD (current || previous || previous-1)
          effective_gd = gd_values[2] || gd_values[1] || gd_values[0]

          {
            player: player,
            club: current_club,
            gd_values: gd_values,
            effective_gd: effective_gd
          }
        end

        # Sort by effective_gd and add rank
        sorted_rankings = player_rankings
          .reject { |r| r[:effective_gd].nil? }
          .sort_by { |r| -r[:effective_gd] }
          .each_with_index { |r, i| r[:rank] = i + 1 }

        hash[discipline] = sorted_rankings
      end
    end

    private

    def dashboard
      @dashboard ||= RegionDashboard.new
    end
    helper_method :dashboard
  end
end
