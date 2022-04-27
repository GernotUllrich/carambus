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
class PartyGame < ApplicationRecord
  belongs_to :party, optional: true
  belongs_to :player_a, class_name: "Player", optional: true
  belongs_to :player_b, class_name: "Player", optional: true
  belongs_to :tournament, optional: true
  belongs_to :discipline, optional: true
  has_one :party_game_cc

  serialize :data, Hash

  #data 14.1 endlos
  #   data:
  #    {:result=>{"Bälle:"=>"100 : 41", "Aufn.:"=>"25 : 24", "HS:"=>"22 : 7"}},

  #data 10-Ball
  #   data:
  #    {:result=>{"Ergebnis"=>"7 : 0"}},
  #
  # def name
  #   "#{party.league_team_a.shortname.presence||party.league_team_a.name}-#{seqno} - #{party.league_team_b.shortname.presence||party.league_team_b.name}-#{seqno}"
  # end

  def update_discipline_from_name
    name_str = read_attribute(:name)
    m = name_str.match(/([^:]+)::([^:]+)(?:::(.*))?/)
    if m.present?
      discipline_str = m[2].strip
      discipline = Discipline.find_by_name(discipline_str)
      self.discipline_id = discipline.andand.id
    else
      Rails.logger.info "ERROR unknown discipline name: \"#{name_str}\" in PartyGame[#{id}]"
    end
  end

end
