# frozen_string_literal: true

module International
  # Controller for international videos
  class VideosController < ApplicationController
    before_action :set_video, only: [:show]

    def index
      @videos = InternationalVideo.includes(:international_source, :discipline, :international_tournament)
                                  .recent
      
      # Filters
      @videos = @videos.by_source(params[:source_id]) if params[:source_id].present?
      @videos = @videos.by_discipline(params[:discipline_id]) if params[:discipline_id].present?
      @videos = @videos.by_tournament(params[:tournament_id]) if params[:tournament_id].present?
      
      # Search
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        @videos = @videos.where('title ILIKE ? OR description ILIKE ?', search_term, search_term)
      end
      
      # Pagination
      @pagy, @videos = pagy(@videos, items: 24)
      
      # For filters
      @sources = InternationalSource.active.order(:name)
      @disciplines = Discipline.where(name: Discipline::KARAMBOL_DISCIPLINE_MAP)
    end

    def show
      @related_videos = InternationalVideo.where(international_tournament_id: @video.international_tournament_id)
                                         .where.not(id: @video.id)
                                         .recent
                                         .limit(6)
    end

    private

    def set_video
      @video = InternationalVideo.includes(:international_source, :discipline, :international_tournament).find(params[:id])
    end
  end
end
