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
class TournamentPlanGame < ApplicationRecord
  belongs_to :tournament_plan
end
