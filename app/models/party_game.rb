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
#  party_id      :integer
#  player_a_id   :integer
#  player_b_id   :integer
#  tournament_id :integer
#
class PartyGame < ApplicationRecord
  belongs_to :party
  belongs_to :player_a, class_name: "Player"
  belongs_to :player_b, class_name: "Player"
  belongs_to :tournament, optional: true

  serialize :data, Hash

  def name
    "#{party.league_team_a.shortname.presence||party.league_team_a.name}-#{seqno} - #{party.league_team_b.shortname.presence||party.league_team_b.name}-#{seqno}"
  end
end
