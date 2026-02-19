# frozen_string_literal: true

# Main controller for international section
class InternationalController < ApplicationController
  def index
    # Use STI: Tournament with type = 'InternationalTournament'
    @upcoming_tournaments = Tournament.international
                                      .upcoming
                                      .includes(:discipline, :international_source)
                                      .limit(10)
    
    # Videos - YouTube scraped videos (unassigned or assigned to tournaments)
    @recent_videos = Video.youtube
                          .recent
                          .limit(12)
    
    # Recent results from international tournaments via GameParticipation
    recent_tournament_ids = Tournament.international
                                      .where('end_date >= ? OR (end_date IS NULL AND date >= ?)', 
                                             6.months.ago, 6.months.ago)
                                      .pluck(:id)
    
    if recent_tournament_ids.any?
      @recent_results = GameParticipation
                         .joins(:game, :player)
                         .where(games: { tournament_id: recent_tournament_ids })
                         .order('games.ended_at DESC NULLS LAST')
                         .limit(20)
    else
      @recent_results = []
    end
  end
end
