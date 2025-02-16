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
  include LocalProtector
  belongs_to :tournament_plan
  belongs_to :discipline

  COLUMN_NAMES = {
    "Discipline" => "disciplines.name",
    "TournamentPlan" => "tournament_plans.name",
    "Points" => "discipline_tournament_plans.points",
    "Innings" => "discipline_tournament_plans.innings",
    "Players" => "discipline_tournament_plans.players",
    "Player Class" => "discipline_tournament_plans.player_class"
  }.freeze

  def self.search_hash(params)
    {
      model: DisciplineTournamentPlan,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: "#{[params[:sSearch], params[:search]].compact.join("&")}",
      column_names: DisciplineTournamentPlan::COLUMN_NAMES,
      raw_sql: "(discipline_tournaments_plans.name ilike :search)
or (tournament_plans.name ilike :search)
or (discipline_tournament_plans.points ilike :isearch)
or (discipline_tournament_plans.innings ilike :isearch)
or (discipline_tournament_plans.players ilike :isearch)
or (discipline_tournament_plans.player_class ilike :search)
",
      joins: %i[discipline tournament_plan]
    }
  end
end
