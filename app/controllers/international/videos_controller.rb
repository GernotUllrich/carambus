# frozen_string_literal: true

module International
  # Controller for international videos
  class VideosController < ApplicationController
    before_action :set_video, only: [:show]

    def index
      # Use new Video model (YouTube videos)
      @videos = Video.youtube
                     .includes(:international_source)
                     .recent
      
      # Filters
      @videos = @videos.where(international_source_id: params[:source_id]) if params[:source_id].present?
      @videos = @videos.where(discipline_id: params[:discipline_id]) if params[:discipline_id].present?
      
      # Filter by tournament (polymorphic)
      if params[:tournament_id].present?
        @videos = @videos.where(videoable_type: 'Tournament', videoable_id: params[:tournament_id])
      end
      
      # Search
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        @videos = @videos.where('title ILIKE ? OR description ILIKE ?', search_term, search_term)
      end
      
      # Pagination
      @pagy, @videos = pagy(@videos, items: 24)
      
      # For filters
      @sources = InternationalSource.youtube.active.order(:name)
      @tournaments = Tournament.international.order(date: :desc).limit(50)
      @disciplines = Discipline.all.order(:name)
    end

    def show
      # Related videos from same tournament
      @related_videos = []
      
      if @video.videoable_type == 'Tournament'
        @related_videos = Video.where(videoable_type: 'Tournament', videoable_id: @video.videoable_id)
                               .where.not(id: @video.id)
                               .recent
                               .limit(6)
      elsif @video.videoable_type == 'Game'
        # Videos from same tournament via game
        game = Game.find(@video.videoable_id)
        if game&.tournament
          @related_videos = Video.where(videoable_type: 'Tournament', videoable_id: game.tournament_id)
                                 .recent
                                 .limit(6)
        end
      end
      
      # Fallback: Videos from same source
      if @related_videos.empty?
        @related_videos = Video.where(international_source_id: @video.international_source_id)
                               .where.not(id: @video.id)
                               .recent
                               .limit(6)
      end
    end

    private

    def set_video
      @video = Video.includes(:international_source).find(params[:id])
    end
  end
end
