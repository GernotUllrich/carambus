# frozen_string_literal: true

# == Schema Information
#
# Table name: seedings
#
#  id                    :bigint           not null, primary key
#  ba_state              :string
#  balls_goal            :integer
#  data                  :text
#  position              :integer
#  rank                  :integer
#  role                  :string
#  state                 :string
#  tournament_type       :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  league_team_id        :integer
#  player_id             :integer
#  playing_discipline_id :integer
#  tournament_id         :integer
#
class Seeding < ApplicationRecord
  include LocalProtector
  include RegionTaggable
  include Searchable
  include AASM
  aasm column: "state", skip_validation_on_save: true do
    state :registered, initial: true
    state :seeded
    state :participated
    state :no_show
  end
  belongs_to :player
  belongs_to :tournament, polymorphic: true, optional: true
  belongs_to :playing_discipline, class_name: "Discipline", foreign_key: :playing_discipline_id, optional: true
  belongs_to :league_team, optional: true

  # Existing validations (from previous response)
  validates :tournament_type, inclusion: {
    in: %w[Tournament Party],
    message: "%{value} is not a valid type (must be 'Tournament' or 'Party')"
  }, if: -> { tournament_type.present? }

  validate :exactly_one_association

  after_create :loggit

  acts_as_list scope: :tournament

  serialize :data, coder: JSON, type: Hash

  # data Snooker
  #   data:
  #    {"result"=>
  #      {"Gesamtrangliste"=>
  #        {"#"=>"2",
  #         "Name"=>"Kondziella, Steffen",
  #         "Verein"=>"BC Break Lübeck",
  #         "G"=>"0",
  #         "V"=>"1",
  #         "Quote"=>"0,00 %",
  #         "Punkte"=>"0",
  #         "Frames"=>"2 : 5",
  #         "HB"=>"0",
  #         "Rank"=>2}}}

  # data 8-Ball
  #   data:
  #    {"result"=>
  #      {"Gesamtrangliste"=>
  #        {"#"=>"19",
  #         "Name"=>"Albrecht, Steffen",
  #         "Verein"=>"BV Q-Pub HH",
  #         "G"=>"2",
  #         "V"=>"2",
  #         "Quote"=>"50,00 %",
  #         "Sp.G"=>"12",
  #         "Sp.V"=>"9",
  #         "Sp.Quote"=>"57,14 %",
  #         "Rank"=>19}}},

  # data Dreiband groß
  #   data:
  #    {"result"=>
  #      {"Gesamtrangliste"=>
  #        {"#"=>"2",
  #         "Name"=>"Weiß, Ferdinand",
  #         "Verein"=>"BC Wedel",
  #         "Punkte"=>"4",
  #         "Bälle"=>"44",
  #         "Aufn"=>"105",
  #         "GD"=>"0,419",
  #         "BED"=>"0,750",
  #         "HS"=>"3",
  #         "Rank"=>2}}},
  #
  MIN_ID = 50_000_000

  REFLECTION_KEYS = %w[
    versions
    player
    tournament
    playing_discipline
    league_team
  ].freeze

  COLUMN_NAMES = {
    # IDs (versteckt, nur für Backend-Filterung)
    "id" => "seedings.id",
    "tournament_id" => "tournaments.id",
    "league_team_id" => "seedings.league_team_id",
    "discipline_id" => "disciplines.id",
    "player_id" => "players.id",
    
    # Referenzen (Dropdown/Select)
    "Tournament" => "tournaments.title",
    "LeagueTeam" => "league_teams.name",
    "Discipline" => "disciplines.name",
    "Region" => "tournament_regions.shortname||league_regions.shortname",
    "Season" => "tournament_seasons.name||league_seasons.name",
    
    # Eigene Felder
    "Player" => "players.lastname||', '||players.firstname",
    "Date" => "tournaments.date::date",
    "Status" => "seedings.state",
    "Position" => "seedings.position",
  }.freeze

  self.ignored_columns = ["region_ids"]

  # Searchable concern provides search_hash
  def self.text_search_sql
    "(players.fl_name ilike :search)
     or (players.lastname ilike :search)
     or (players.firstname ilike :search)
     or (players.nickname ilike :search)
     or (tournaments.title ilike :search)
     or (league_teams.name ilike :search)
     or (disciplines.name ilike :search)
     or (seedings.state ilike :search)
     or (tournament_seasons.name ilike :search)
     or (league_seasons.name ilike :search)"
  end
  
  def self.search_joins
    [
      "LEFT JOIN tournaments ON (seedings.tournament_id = tournaments.id AND seedings.tournament_type = 'Tournament')",
      "LEFT JOIN leagues ON (seedings.tournament_id = leagues.id AND seedings.tournament_type = 'League')",
      "LEFT JOIN league_teams ON league_teams.id = seedings.league_team_id",
      "LEFT JOIN disciplines ON disciplines.id = seedings.playing_discipline_id",
      "LEFT JOIN seasons AS tournament_seasons ON tournaments.season_id = tournament_seasons.id",
      "LEFT JOIN seasons AS league_seasons ON leagues.season_id = league_seasons.id",
      'LEFT JOIN "regions" AS tournament_regions ON ("tournament_regions"."id" = "tournaments"."organizer_id" AND "tournaments"."organizer_type" = \'Region\')',
      'LEFT JOIN "regions" AS league_regions ON ("league_regions"."id" = "leagues"."organizer_id" AND "leagues"."organizer_type" = \'Region\')',
      :player
    ]
  end
  
  def self.search_distinct?
    false
  end
  
  def self.cascading_filters
    {
      'tournament_id' => [],
      'discipline_id' => []
    }
  end
  
  def self.field_examples(field_name)
    case field_name
    when 'Player'
      { description: "Spieler-Name", examples: ["Meyer, Hans"] }
    when 'Tournament'
      { description: "Turnier/Liga", examples: [] }
    when 'LeagueTeam'
      { description: "Mannschaft", examples: [] }
    when 'Discipline'
      { description: "Disziplin", examples: [] }
    when 'Date'
      { description: "Turnier-Datum", examples: ["2024-01-15", "> 2024-01-01"] }
    when 'Season'
      { description: "Saison", examples: [] }
    when 'Region'
      { description: "Region", examples: [] }
    when 'Status'
      { description: "Teilnahme-Status", examples: ["registered", "confirmed", "cancelled"] }
    when 'Position'
      { description: "Setzposition", examples: ["1", "2", "> 5"] }
    else
      super
    end
  end

  def loggit
    Rails.logger.info "Seeding[#{id}] created."
  end

  def self.result_display(seeding)
    ret = []
    result = seeding.data.andand["result"]
    if result.present?
      ret << "<table>"
      lists = result.keys
      if result.keys.present?
        cols = result[lists[0]].andand.keys
        if cols.present?
          i_name = cols.index("Name")
          i_verein = cols.index("Verein")
          cols -= %w[Name Verein]
          ret << "<tr><th></th>#{cols.map { |c| "<th>#{c}</th>" }.join("")}</tr>"
          lists.each do |list|
            values = result[list].values
            values = values.reject.with_index { |_e, i| [i_name, i_verein].include? i }
            ret << "<tr><td>#{list}</td>#{values.map { |c| "<td>#{c}</td>" }.join("")}</tr>"
          end
        end
      end
      ret << "</table>"
    end
    ret.join("\n").html_safe
  end

  private

  def exactly_one_association
    has_league_team = league_team_id.present?
    has_tournament = tournament_id.present? && tournament_type.present?

    if has_league_team && has_tournament
      errors.add(:base, "Seeding cannot belong to both a league_team and a tournament")
      return # Early return to avoid further checks if already invalid
    elsif !has_league_team && !has_tournament
      errors.add(:base, "Seeding must belong to either a league_team or a tournament")
      return
    elsif has_tournament && tournament_id.blank?
      errors.add(:tournament_id, "must be present if tournament_type is set")
      return
    elsif has_tournament && tournament_type.blank?
      errors.add(:tournament_type, "must be present if tournament_id is set")
      return
    end

    # New: Check existence of the referenced record
    if has_league_team
      unless LeagueTeam.exists?(id: league_team_id)
        errors.add(:league_team_id, "references a non-existent LeagueTeam (ID: #{league_team_id})")
      end
    elsif has_tournament
      # Dynamically get the class from tournament_type and check existence
      klass = tournament_type.safe_constantize
      if klass.nil? || !klass.ancestors.include?(ApplicationRecord)
        errors.add(:tournament_type, "references an invalid or non-model class (#{tournament_type})")
      elsif !klass.exists?(id: tournament_id)
        errors.add(:tournament_id, "references a non-existent #{tournament_type} (ID: #{tournament_id})")
      end
    end
  end
end
