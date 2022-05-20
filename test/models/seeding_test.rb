# == Schema Information
#
# Table name: seedings
#
#  id                    :bigint           not null, primary key
#  ba_state              :string
#  balls_goal            :integer
#  data                  :text
#  position              :integer
#  rank                  :integer
#  state                 :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  league_team_id        :integer
#  player_id             :integer
#  playing_discipline_id :integer
#  tournament_id         :integer
#
require 'test_helper'

class SeedingTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
