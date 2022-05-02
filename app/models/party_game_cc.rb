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
#  party_cc_id   :integer
#  player_a_id   :integer
#  player_b_id   :integer
#
class PartyGameCc < ApplicationRecord
  belongs_to :party_cc
  belongs_to :party_game
  delegate :discipline, to: :party_game
  delegate :fedId, :branchId, :subBranchId, :season_id,  to: :party_cc
end
