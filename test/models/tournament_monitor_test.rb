# == Schema Information
#
# Table name: tournament_monitors
#
#  id            :bigint           not null, primary key
#  balls_goal    :integer
#  data          :text
#  initial_tc    :integer
#  innings_goal  :integer
#  state         :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  tournament_id :integer
#
# Foreign Keys
#
#  fk_rails_...  (tournament_id => tournaments.id)
#
require 'test_helper'

class TournamentMonitorTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
