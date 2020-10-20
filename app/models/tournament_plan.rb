class TournamentPlan < ActiveRecord::Base
  has_many :discipline_tournament_plans
  has_many :tournament_plan_games
  has_many :tournaments


end
