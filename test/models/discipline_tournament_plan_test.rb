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
require 'test_helper'

class DisciplineTournamentPlanTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
