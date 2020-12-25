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
#  player_id             :integer
#  playing_discipline_id :integer
#  tournament_id         :integer
#
# Indexes
#
#  index_seedings_on_foreign_keys  (player_id,tournament_id) UNIQUE
#
require 'test_helper'

class SeedingTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
