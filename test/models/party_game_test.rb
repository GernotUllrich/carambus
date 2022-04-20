# == Schema Information
#
# Table name: party_games
#
#  id            :bigint           not null, primary key
#  data          :text
#  name          :string
#  seqno         :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  discipline_id :integer
#  party_id      :integer
#  player_a_id   :integer
#  player_b_id   :integer
#  tournament_id :integer
#
require 'test_helper'

class PartyGameTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
