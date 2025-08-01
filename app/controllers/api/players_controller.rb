# frozen_string_literal: true

module Api
  class PlayersController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :set_cache_headers

    def autocomplete
      query = params[:q]
      return render json: [] if query.blank? || query.length < 2

      players = Player.where(type: nil)
                     .where("players.firstname ILIKE ? OR players.lastname ILIKE ? OR players.fl_name ILIKE ?", 
                           "%#{query}%", "%#{query}%", "%#{query}%")
                     .includes(:season_participations => :club)
                     .limit(10)

      suggestions = players.map do |player|
        club_name = player.season_participations.joins(:club)
                          .where(season: Season.current_season)
                          .first&.club&.shortname || "No Club"
        
        {
          value: player.fl_name,
          label: "#{player.fl_name} (#{club_name})",
          id: player.id
        }
      end

      render json: suggestions
    end

    private

    def set_cache_headers
      response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
    end
  end
end 