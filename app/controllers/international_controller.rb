# frozen_string_literal: true

# Main controller for international section
class InternationalController < ApplicationController
  def index
    # Upcoming Tournaments (next 6 months, only 3 for landing page)
    six_months_from_now = 6.months.from_now.to_date
    @upcoming_tournaments = Tournament.international
                                      .where('date >= ? AND date <= ?', Date.today, six_months_from_now)
                                      .includes(:discipline, :international_source)
                                      .order(date: :asc)
                                      .limit(3)

    # Recent Tournaments (6 recently finished tournaments)
    @recent_tournaments = Tournament.international
                                    .where('date < ?', Date.today)
                                    .includes(:discipline, :international_source)
                                    .order(date: :desc)
                                    .limit(6)

    # Videos - YouTube and SOOP videos (unassigned or assigned to tournaments)
    @recent_videos = Video.supported_platforms
                          .recent
                          .limit(12)
    @recent_videos = @recent_videos.visible unless current_user&.admin?

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
