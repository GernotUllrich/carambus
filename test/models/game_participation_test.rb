# == Schema Information
#
# Table name: game_participations
#
#  id         :bigint           not null, primary key
#  data       :text
#  gd         :float
#  gname      :string
#  hs         :integer
#  innings    :integer
#  points     :integer
#  result     :integer
#  role       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  game_id    :integer
#  player_id  :integer
#
# Indexes
#
#  index_game_participations_on_foreign_keys  (game_id,player_id,role) UNIQUE
#
require 'test_helper'

class GameParticipationTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
