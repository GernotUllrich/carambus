# == Schema Information
#
# Table name: party_game_ccs
#
#  id            :bigint           not null, primary key
#  data          :text
#  name          :string
#  seqno         :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  cc_id         :integer
#  discipline_id :integer
#  player_a_id   :integer
#  player_b_id   :integer
#
require "test_helper"

class PartyGameCcTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
