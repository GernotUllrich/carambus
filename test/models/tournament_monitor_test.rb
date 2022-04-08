# == Schema Information
#
# Table name: tournament_monitors
#
#  id                        :bigint           not null, primary key
#  allow_follow_up           :boolean          default(TRUE), not null
#  allow_overflow            :boolean
#  balls_goal                :integer
#  color_remains_with_set    :boolean          default(TRUE), not null
#  data                      :text
#  fixed_display_left        :string
#  innings_goal              :integer
#  kickoff_switches_with_set :boolean          default(TRUE), not null
#  sets_to_play              :integer          default(1), not null
#  sets_to_win               :integer          default(1), not null
#  state                     :string
#  team_size                 :integer          default(1), not null
#  timeout                   :integer          default(0), not null
#  timeouts                  :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  tournament_id             :integer
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
