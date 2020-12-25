# == Schema Information
#
# Table name: tournament_plan_games
#
#  id                 :bigint           not null, primary key
#  data               :text
#  name               :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  tournament_plan_id :integer
#
# Foreign Keys
#
#  fk_rails_...  (tournament_plan_id => tournament_plans.id)
#
require 'test_helper'

class TournamentPlanGameTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
