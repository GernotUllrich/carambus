# == Schema Information
#
# Table name: players
#
#  id         :bigint           not null, primary key
#  firstname  :string
#  lastname   :string
#  title      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ba_id      :integer
#  club_id    :integer
#
# Indexes
#
#  index_players_on_ba_id    (ba_id) UNIQUE
#  index_players_on_club_id  (club_id)
#
require 'test_helper'

class PlayerTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
