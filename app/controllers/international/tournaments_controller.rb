# frozen_string_literal: true

module International
  # Controller for international tournaments
  class TournamentsController < ApplicationController
    before_action :set_tournament, only: [:show]

    def index
      @tournaments = InternationalTournament.includes(:discipline)
                                           .order(start_date: :desc)
      
      # Filters
      @tournaments = @tournaments.by_type(params[:type]) if params[:type].present?
      @tournaments = @tournaments.by_discipline(params[:discipline_id]) if params[:discipline_id].present?
      @tournaments = @tournaments.in_year(params[:year]) if params[:year].present?
      
      # Pagination
      @pagy, @tournaments = pagy(@tournaments, items: 20)
      
      # For filters
      @tournament_types = InternationalTournament::TOURNAMENT_TYPES
      @disciplines = Discipline.where(name: Discipline::KARAMBOL_DISCIPLINE_MAP)
    end

    def show
      @results = @tournament.international_results.includes(:player).ordered
      @videos = @tournament.international_videos.recent
    end

    private

    def set_tournament
      @tournament = InternationalTournament.includes(:discipline, :international_source).find(params[:id])
    end
  end
end
