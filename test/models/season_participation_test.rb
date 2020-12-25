# == Schema Information
#
# Table name: season_participations
#
#  id         :bigint           not null, primary key
#  data       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  club_id    :integer
#  player_id  :integer
#  season_id  :integer
#
# Indexes
#
#  index_season_participations_on_foreign_keys  (player_id,club_id,season_id) UNIQUE
#
require 'test_helper'

class SeasonParticipationTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
