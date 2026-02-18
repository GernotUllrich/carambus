# frozen_string_literal: true

module International
  # Controller for international tournaments
  class TournamentsController < ApplicationController
    before_action :set_tournament, only: [:show]

    def index
      @tournaments = InternationalTournament.includes(:discipline, :international_source)
                                           .order(start_date: :desc)
      
      # Filters
      @tournaments = @tournaments.by_type(params[:type]) if params[:type].present?
      @tournaments = @tournaments.by_discipline(params[:discipline_id]) if params[:discipline_id].present?
      @tournaments = @tournaments.in_year(params[:year]) if params[:year].present?
      @tournaments = @tournaments.official_umb if params[:official_umb] == '1'
      
      # Pagination
      @pagy, @tournaments = pagy(@tournaments, items: 20)
      
      # For filters
      @tournament_types = InternationalTournament::TOURNAMENT_TYPES
      @disciplines = Discipline.where(name: Discipline::KARAMBOL_DISCIPLINE_MAP)
    end

    def show
      # Results via GameParticipation (ersetzt international_results)
      @results = GameParticipation
                  .joins(:game, :player)
                  .where(games: { tournament_id: @tournament.id })
                  .order('games.ended_at DESC NULLS LAST, game_participations.points DESC')
      
      # Videos - polymorphe Association (Tournament + seine Games)
      @videos = @tournament.videos.recent
      
      # Optional: Auch Videos von Games des Turniers
      @game_videos = Video.for_games
                          .where(videoable_id: @tournament.games.pluck(:id))
                          .recent
    end

    private

    def set_tournament
      @tournament = InternationalTournament.includes(:discipline, :international_source).find(params[:id])
    end
  end
end
