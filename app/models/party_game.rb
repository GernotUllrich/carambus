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
#
class PartyGame < ApplicationRecord
  include LocalProtector
  include RegionTaggable

  self.ignored_columns = ["region_ids"]

  belongs_to :party, optional: true
  belongs_to :player_a, class_name: "Player", optional: true
  belongs_to :player_b, class_name: "Player", optional: true
  belongs_to :discipline, optional: true

  serialize :data, coder: JSON, type: Hash

  REFLECTIONS = %w[versions
                   party
                   player_a
                   player_b
                   tournament
                   discipline
                   party_game_cc]

  COLUMN_NAMES = {
    # Cascading references
    "Region" => "regions.shortname",
    "Season" => "seasons.name",
    "League" => "leagues.shortname",
    #  party_id      :integer
    "Party" => "parties.id",
    #  name          :string
    "Name" => "party_games.name",
    #  seqno         :integer
    "Seqno" => "party_games.seqno",
    #  created_at    :datetime         not null
    #  updated_at    :datetime         not null
    #  discipline_id :integer
    "Discipline" => "disciplines.name",
    #  player_a_id   :integer
    "Player A" => "player_a.name",
    #  player_b_id   :integer
    "Player B" => "player_b.name",
    #  tournament_id :integer
    "Tournament" => "tournaments.name",
  }

  # data 14.1 endlos
  #   data:
  #    {:result=>{"Bälle:"=>"100 : 41", "Aufn.:"=>"25 : 24", "HS:"=>"22 : 7"}},

  # data 10-Ball
  #   data:
  #    {:result=>{"Ergebnis"=>"7 : 0"}},
  #
  # def name
  #   "#{party.league_team_a.shortname.presence||party.league_team_a.name}-#{seqno} - #{party.league_team_b.shortname.presence||party.league_team_b.name}-#{seqno}"
  # end

  def self.search_hash(params)
    {
      model: PartyGame,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: "#{[params[:sSearch], params[:search]].compact.join("&")}",
      column_names: PartyGame::COLUMN_NAMES.merge({
        "region_id" => "regions.id",
        "season_id" => "seasons.id",
        "league_id" => "leagues.id",
        "party_id" => "parties.id"
      }),
      raw_sql: "(leagues.shortname ilike :search) or (parties.id = :isearch) or (party_games.name ilike :search) or (disciplines.name ilike :search) or (regions.shortname ilike :search) or (seasons.name ilike :search)",
      joins: "INNER JOIN parties ON parties.id = party_games.party_id INNER JOIN leagues ON leagues.id = parties.league_id INNER JOIN seasons ON seasons.id = leagues.season_id INNER JOIN regions ON regions.id = leagues.organizer_id AND leagues.organizer_type = 'Region'",
      distinct: true
    }
  end

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
