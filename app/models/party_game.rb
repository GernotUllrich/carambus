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
  belongs_to :party, optional: true
  belongs_to :player_a, class_name: "Player", optional: true
  belongs_to :player_b, class_name: "Player", optional: true
  belongs_to :tournament, optional: true

  serialize :data, Hash

  #data 14.1 endlos
  #   data:
  #    {:result=>{"Bälle:"=>"100 : 41", "Aufn.:"=>"25 : 24", "HS:"=>"22 : 7"}},

  #data 10-Ball
  #   data:
  #    {:result=>{"Ergebnis"=>"7 : 0"}},
  #
  def name
    "#{party.league_team_a.shortname.presence||party.league_team_a.name}-#{seqno} - #{party.league_team_b.shortname.presence||party.league_team_b.name}-#{seqno}"
  end
end
