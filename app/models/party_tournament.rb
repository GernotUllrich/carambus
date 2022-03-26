# == Schema Information
#
# Table name: party_tournaments
#
#  id            :bigint           not null, primary key
#  position      :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  party_id      :integer
#  tournament_id :integer
#
class PartyTournament < ApplicationRecord
  belongs_to :party
  belongs_to :tournament
end
