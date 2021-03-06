# == Schema Information
#
# Table name: discipline_tournament_plans
#
#  id                 :bigint           not null, primary key
#  innings            :integer
#  player_class       :string
#  players            :integer
#  points             :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  discipline_id      :integer
#  tournament_plan_id :integer
#
class DisciplineTournamentPlan < ApplicationRecord
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
