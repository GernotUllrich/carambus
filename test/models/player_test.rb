# == Schema Information
#
# Table name: players
#
#  id            :bigint           not null, primary key
#  data          :text
#  firstname     :string
#  guest         :boolean          default(FALSE), not null
#  lastname      :string
#  nickname      :string
#  title         :string
#  type          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ba_id         :integer
#  cc_id         :integer
#  club_id       :integer
#  tournament_id :integer
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
