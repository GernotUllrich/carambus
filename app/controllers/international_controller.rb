# frozen_string_literal: true

# Main controller for international section
class InternationalController < ApplicationController
  def index
    @upcoming_tournaments = InternationalTournament.upcoming
                                                   .includes(:discipline, :international_source)
                                                   .limit(10)
    @recent_videos = InternationalVideo.recent.limit(12)
    @recent_results = InternationalResult.includes(:international_tournament, :player)
                                        .joins(:international_tournament)
                                        .where('international_tournaments.end_date >= ?', 6.months.ago)
                                        .order('international_tournaments.end_date DESC')
                                        .limit(20)
  end
end
