# frozen_string_literal: true

# Main controller for international section
class InternationalController < ApplicationController
  def index
    @upcoming_tournaments = InternationalTournament.upcoming
                                                   .includes(:discipline, :international_source)
                                                   .limit(10)
    
    # Videos - polymorphe Association
    @recent_videos = Video.for_tournaments
                          .where(videoable_type: 'Tournament')
                          .where("videoable_id IN (?)", InternationalTournament.pluck(:id))
                          .recent
                          .limit(12)
    
    # Recent results via GameParticipation
    recent_tournament_ids = InternationalTournament
                             .where('end_date >= ? OR (end_date IS NULL AND date >= ?)', 
                                    6.months.ago, 6.months.ago)
                             .pluck(:id)
    
    @recent_results = GameParticipation
                       .joins(:game, :player)
                       .where(games: { tournament_id: recent_tournament_ids })
                       .order('games.ended_at DESC NULLS LAST')
                       .limit(20)
  end
end
