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
  include Searchable

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
    # IDs (versteckt, nur für Backend-Filterung)
    "id" => "party_games.id",
    "region_id" => "regions.id",
    "season_id" => "seasons.id",
    "league_id" => "leagues.id",
    "party_id" => "parties.id",
    "discipline_id" => "disciplines.id",
    
    # Referenzen (Dropdown/Select)
    "Region" => "regions.shortname",
    "Season" => "seasons.name",
    "League" => "leagues.shortname",
    "Party" => "parties.id",
    "Discipline" => "disciplines.name",
    
    # Eigene Felder
    "Name" => "party_games.name",
    "Seqno" => "party_games.seqno",
    "Player A" => "player_a.fl_name",
    "Player B" => "player_b.fl_name",
  }.freeze

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

  # Searchable concern provides search_hash
  def self.text_search_sql
    "(leagues.shortname ilike :search)
     or (leagues.name ilike :search)
     or (parties.id = :isearch)
     or (party_games.name ilike :search)
     or (disciplines.name ilike :search)
     or (regions.shortname ilike :search)
     or (seasons.name ilike :search)
     or (player_a.fl_name ilike :search)
     or (player_b.fl_name ilike :search)"
  end
  
  def self.search_joins
    "INNER JOIN parties ON parties.id = party_games.party_id 
     INNER JOIN leagues ON leagues.id = parties.league_id 
     INNER JOIN seasons ON seasons.id = leagues.season_id 
     INNER JOIN regions ON regions.id = leagues.organizer_id AND leagues.organizer_type = 'Region'
     LEFT JOIN disciplines ON disciplines.id = party_games.discipline_id
     LEFT JOIN players AS player_a ON player_a.id = party_games.player_a_id
     LEFT JOIN players AS player_b ON player_b.id = party_games.player_b_id"
  end
  
  def self.search_distinct?
    true
  end
  
  def self.cascading_filters
    {
      'region_id' => ['season_id'],
      'season_id' => ['league_id'],
      'league_id' => ['party_id']
    }
  end
  
  def self.field_examples(field_name)
    case field_name
    when 'Region'
      { description: "Region auswählen (filtert Seasons)", examples: [] }
    when 'Season'
      { description: "Saison auswählen (filtert Ligen)", examples: [] }
    when 'League'
      { description: "Liga auswählen (filtert Spieltage)", examples: [] }
    when 'Party'
      { description: "Spieltag-ID", examples: ["123", "456"] }
    when 'Discipline'
      { description: "Disziplin", examples: [] }
    when 'Name'
      { description: "Partie-Name", examples: ["Team A - Team B"] }
    when 'Seqno'
      { description: "Sequenz-Nummer", examples: ["1", "2", "> 5"] }
    when 'Player A', 'Player B'
      { description: "Spieler-Name", examples: ["Meyer, Hans"] }
    else
      super
    end
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
