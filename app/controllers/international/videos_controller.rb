# frozen_string_literal: true

module International
  # Controller for international videos
  class VideosController < ApplicationController
    before_action :set_video, only: [:show, :hide, :unhide]
    before_action :require_admin!, only: [:hide, :unhide]

    def index
      # Use new Video model (YouTube videos)
      @videos = Video.youtube
                     .includes(:international_source, :discipline)
                     .recent
      
      # Show hidden videos only for admins
      @videos = @videos.visible unless current_user&.admin?
      
      # Filters
      @videos = @videos.where(international_source_id: params[:source_id]) if params[:source_id].present?
      @videos = @videos.where(discipline_id: params[:discipline_id]) if params[:discipline_id].present?
      
      # Filter by tournament (polymorphic)
      if params[:tournament_id].present?
        @videos = @videos.where(videoable_type: 'Tournament', videoable_id: params[:tournament_id])
      end
      
      # Tag Filtering
      if params[:tag].present?
        @videos = @videos.with_tag(params[:tag])
      elsif params[:tags].present?
        # Multiple tags with OR/AND logic
        tags = params[:tags].is_a?(Array) ? params[:tags] : [params[:tags]]
        tags = tags.compact.reject(&:blank?)
        
        if tags.any?
          # Check tag_mode: 'and' or 'or' (default: 'or')
          if params[:tag_mode] == 'and'
            @videos = @videos.with_all_tags(tags)
          else
            @videos = @videos.with_any_tag(tags)
          end
        end
      end
      
      # Filter by tag group (e.g., all players from a country)
      if params[:tag_group].present? && params[:tag_group_value].present?
        case params[:tag_group]
        when 'content_type'
          @videos = @videos.with_tag(params[:tag_group_value])
        when 'player_country'
          # Get all players from this country
          country_players = InternationalHelper::WORLD_CUP_TOP_32.select { |_, info| info[:country] == params[:tag_group_value] }
          player_tags = country_players.keys.map(&:downcase)
          @videos = @videos.with_any_tag(player_tags) if player_tags.any?
        when 'quality'
          @videos = @videos.with_tag(params[:tag_group_value])
        end
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
      
      # Tag statistics for filter counts
      @tag_counts = calculate_tag_counts
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
      
      # Filter hidden videos for non-admins
      @related_videos = @related_videos.visible unless current_user&.admin?
    end

    # Admin: Hide video
    def hide
      if @video.hide!
        redirect_to international_video_path(@video), notice: 'Video hidden successfully.'
      else
        redirect_to international_video_path(@video), alert: 'Failed to hide video.'
      end
    end

    # Admin: Unhide video
    def unhide
      if @video.unhide!
        redirect_to international_video_path(@video), notice: 'Video is now visible.'
      else
        redirect_to international_video_path(@video), alert: 'Failed to unhide video.'
      end
    end

    private

    def set_video
      @video = Video.includes(:international_source, :discipline).find(params[:id])
    end

    def require_admin!
      unless current_user&.admin?
        redirect_to root_path, alert: 'Access denied. Admin privileges required.'
      end
    end

    def calculate_tag_counts
      # Get tag counts from all videos (limited scope for performance)
      tag_data = Video.youtube
                      .where("videos.data->'tags' IS NOT NULL")
                      .pluck(Arel.sql("jsonb_array_elements_text(videos.data->'tags')"))
                      .group_by(&:itself)
                      .transform_values(&:count)
      
      # Group by categories
      {
        content_types: InternationalHelper::VIDEO_TAG_GROUPS['Content Type'][:tags]
                         .map { |tag| [tag, tag_data[tag] || 0] }.to_h,
        players: InternationalHelper::WORLD_CUP_TOP_32.keys
                   .map { |tag| [tag.downcase, tag_data[tag.downcase] || 0] }.to_h
                   .select { |_, count| count > 0 }
                   .sort_by { |_, count| -count }
                   .take(20).to_h,
        quality: InternationalHelper::VIDEO_TAG_GROUPS['Quality'][:tags]
                   .map { |tag| [tag, tag_data[tag] || 0] }.to_h
      }
    rescue StandardError => e
      Rails.logger.error("Tag count calculation failed: #{e.message}")
      { content_types: {}, players: {}, quality: {} }
    end
  end
end
