# frozen_string_literal: true

# == Schema Information
#
# Table name: season_participations
#
#  id         :bigint           not null, primary key
#  data       :text
#  source_url :string
#  status     :string
#  sync_date  :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ba_id      :integer
#  club_id    :integer
#  player_id  :integer
#  season_id  :integer
#
# Indexes
#
#  index_season_participations_on_foreign_keys  (player_id,club_id,season_id) UNIQUE
#
class SeasonParticipation < ApplicationRecord
  include LocalProtector
  include RegionTaggable
  include Searchable

  self.ignored_columns = ["region_ids"]

  belongs_to :season
  belongs_to :player
  belongs_to :club

  REFLECTION_KEYS = %w[season player club].freeze
  COLUMN_NAMES = {
    # IDs (versteckt, nur für Backend-Filterung)
    "id" => "season_participations.id",
    "season_id" => "seasons.id",
    "player_id" => "players.id",
    "club_id" => "clubs.id",
    "region_id" => "regions.id",
    
    # Referenzen (Dropdown/Select)
    "Season" => "seasons.name",
    "Region" => "regions.shortname",
    "Club" => "clubs.shortname",
    
    # Eigene Felder (mit concat für Player-Name)
    "Player" => "players.lastname||', '||players.firstname",
    "Status" => "season_participations.status",
  }.freeze
  
  # Searchable concern provides search_hash
  def self.text_search_sql
    "(players.lastname ilike :search)
     or (players.firstname ilike :search)
     or (players.fl_name ilike :search)
     or (players.nickname ilike :search)
     or (clubs.name ilike :search)
     or (clubs.shortname ilike :search)
     or (seasons.name ilike :search)"
  end
  
  def self.search_joins
    [:season, :player, { club: :region }]
  end
  
  def self.search_distinct?
    false
  end
  
  def self.cascading_filters
    {
      'season_id' => [],
      'region_id' => ['club_id']
    }
  end
  
  def self.field_examples(field_name)
    case field_name
    when 'Season'
      { description: "Saison auswählen", examples: [] }
    when 'Region'
      { description: "Region auswählen", examples: [] }
    when 'Club'
      { description: "Verein auswählen", examples: [] }
    when 'Player'
      { description: "Spieler-Name", examples: ["Meyer, Hans", "Schmidt, Peter"] }
    when 'Status'
      { description: "Mitgliedsstatus", examples: ["active", "passive", "guest"] }
    else
      super
    end
  end
  # status:
  # "active" member
  # "passive" Membership
  # "guest" Player
end
