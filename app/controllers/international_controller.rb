# frozen_string_literal: true

# Main controller for international section
class InternationalController < ApplicationController
  def index
    # Official UMB Tournaments (next 6 months only)
    six_months_from_now = 6.months.from_now.to_date
    @umb_tournaments = InternationalTournament.from_umb
                                              .where('date >= ? AND date <= ?', Date.today, six_months_from_now)
                                              .includes(:discipline, :international_source)
                                              .order(date: :asc)
                                              .limit(12)
    
    # Other upcoming international tournaments (non-UMB, next 6 months only)
    @upcoming_tournaments = Tournament.international
                                      .where('date >= ? AND date <= ?', Date.today, six_months_from_now)
                                      .where.not(id: @umb_tournaments.pluck(:id))
                                      .includes(:discipline, :international_source)
                                      .order(date: :asc)
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
