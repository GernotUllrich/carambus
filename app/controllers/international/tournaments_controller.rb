# frozen_string_literal: true

module International
  # Controller for international tournaments
  class TournamentsController < ApplicationController
    before_action :set_tournament, only: [:show]

    def index
      # Use STI: Tournament.international
      six_months_from_now = 6.months.from_now.to_date
      
      tournaments_query = Tournament.international
                                    .includes(:discipline, :international_source, :videos)
      
      # Filter by time period
      if params[:filter] == 'past'
        # Only past tournaments
        tournaments_query = tournaments_query.where('date < ?', Date.today)
                                            .order(date: :desc)
      elsif params[:filter] == 'upcoming'
        # Only upcoming tournaments (max 6 months)
        tournaments_query = tournaments_query.where('date >= ? AND date <= ?', Date.today, six_months_from_now)
                                            .order(date: :asc)
      else
        # Default: All tournaments (but future limited to 6 months)
        tournaments_query = tournaments_query.where('date < ? OR (date >= ? AND date <= ?)', 
                                                    Date.today, Date.today, six_months_from_now)
                                            .order(date: :desc)
      end
      
      # SQL Filters (can use database)
      # Handle discipline filter (including group filters)
      if params[:discipline_id].present?
        if params[:discipline_id].start_with?('group:')
          # Group filter: extract group name and get all discipline IDs
          group_name = params[:discipline_id].sub('group:', '')
          discipline_ids = InternationalHelper.discipline_ids_for_group(group_name)
          tournaments_query = tournaments_query.where(discipline_id: discipline_ids) if discipline_ids.any?
        else
          # Individual discipline filter
          tournaments_query = tournaments_query.where(discipline_id: params[:discipline_id])
        end
      end
      
      tournaments_query = tournaments_query.in_year(params[:year])
      
      # Load all tournaments for Ruby filtering (data is serialized TEXT, not JSONB)
      all_tournaments = tournaments_query.to_a
      
      # Ruby Filters (for serialized data field)
      if params[:type].present?
        all_tournaments = all_tournaments.select { |t| t.try(:tournament_type) == params[:type] }
      end
      
      if params[:official_umb] == '1'
        all_tournaments = all_tournaments.select { |t| t.try(:official_umb?) }
      end
      
      # View mode
      @view_mode = params[:view] || 'grid'
      
      # Pagination using pagy with array (pagy >= 6.0)
      items_per_page = @view_mode == 'table' ? 50 : 20
      
      # Manual pagination for array
      page = params[:page]&.to_i || 1
      total_count = all_tournaments.count
      total_pages = (total_count.to_f / items_per_page).ceil
      offset = (page - 1) * items_per_page
      
      @pagy = Pagy.new(count: total_count, page: page, items: items_per_page)
      @tournaments = all_tournaments[offset, items_per_page] || []
      
      # For filters
      @tournament_types = InternationalTournament::TOURNAMENT_TYPES
      @disciplines = Discipline.all.order(:name)
    end

    def show
      # Videos - polymorphe Association
      @videos = @tournament.videos.recent
      
      # Videos von Games des Turniers
      game_ids = @tournament.games.pluck(:id)
      @game_videos = Video.where(videoable_type: 'Game', videoable_id: game_ids)
                          .recent if game_ids.any?
      
      # Phase Games (without "Match" in name)
      @phase_games = @tournament.games
                                .where("gname NOT LIKE ?", "%Match%")
                                .order(:id)
      
      # Match Games grouped by phase
      # Note: data is serialized TEXT, not JSONB, so we filter in Ruby
      @matches_by_phase = {}
      all_matches = @tournament.games
                               .where("gname LIKE ?", "%Match%")
                               .includes(game_participations: :player)
                               .to_a
      
      @phase_games.each do |phase_game|
        # Filter matches by phase_game_id in Ruby (since data is serialized)
        matches = all_matches.select do |match|
          match.data.is_a?(Hash) && match.data['phase_game_id'] == phase_game.id
        end
        @matches_by_phase[phase_game.id] = matches.sort_by { |m| [m.group_no.to_s, m.id] }
      end
      
      # Rangliste: Aggregate participations by player
      # Sum up: result (points), innings, calculate average GD, max HS
      participations = GameParticipation
                        .joins(:game, :player)
                        .where(games: { tournament_id: @tournament.id })
                        .select(
                          'game_participations.player_id',
                          'SUM(game_participations.result) as total_points',
                          'SUM(game_participations.innings) as total_innings',
                          'AVG(game_participations.gd) as avg_gd',
                          'MAX(game_participations.hs) as max_hs',
                          'COUNT(*) as games_played'
                        )
                        .group('game_participations.player_id')
                        .order('total_points DESC, avg_gd DESC')
      
      # Load players and build ranking objects
      @all_participations = participations.map do |p|
        player = Player.find(p.player_id)
        OpenStruct.new(
          player: player,
          result: p.total_points,
          innings: p.total_innings,
          gd: p.avg_gd,
          hs: p.max_hs,
          games_played: p.games_played
        )
      end
    end

    private

    def set_tournament
      @tournament = Tournament.international
                              .includes(:discipline, :international_source)
                              .find(params[:id])
    end
  end
end
