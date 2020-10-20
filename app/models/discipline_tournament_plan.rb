class DisciplineTournamentPlan < ActiveRecord::Base
  belongs_to :tournament_plan
  belongs_to :discipline

  COLUMN_NAMES = {
      "Discipline" => "disciplines.name",
      "TournamentPlan" => "tournament_plans.name",
      "Points" => "discipline_tournament_plans.points",
      "Innings" => "discipline_tournament_plans.innings",
      "Players" => "discipline_tournament_plans.players",
      "Player Class" => "discipline_tournament_plans.player_class",
  }
end
