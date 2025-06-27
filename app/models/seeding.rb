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
  include AASM
  aasm column: "state", skip_validation_on_save: true do
    state :registered, initial: true
    state :seeded
    state :participated
    state :no_show
  end
  belongs_to :player, optional: true
  belongs_to :tournament, polymorphic: true, optional: true
  belongs_to :playing_discipline, class_name: "Discipline", foreign_key: :playing_discipline_id, optional: true
  belongs_to :league_team, optional: true

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
    "Player" => "players.lastname||', '||players.firstname",
    "Tournament" => "tournaments.title",
    "league_team_id" => "seedings.league_team_id",
    "LeagueTeam" => "league_teams.name",
    "Discipline" => "disciplines.name",
    "Date" => "tournaments.date::date",
    "Season" => "tournament_seasons.name||league_seasons.name",
    "Region" => "tournament_regions.shortname||league_regions.shortname",
    "Status" => "seeding.state",
    "Position" => "seeding.position",
    "Remarks" => "seeding.data"
  }.freeze

  self.ignored_columns = ["region_ids"]

  def self.search_hash(params)
    {
      model: Seeding,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: [params[:sSearch], params[:search]].compact.join("&").to_s,
      column_names: Seeding::COLUMN_NAMES,
      raw_sql: "(players.fl_name ilike :search)
or (players.nickname ilike :search)
or (seedings.state ilike :search)
or (tournament_seasons.name ilike :search)
or (league_seasons.name ilike :search)
",
      joins: [
        "LEFT JOIN tournaments ON (seedings.tournament_id = tournaments.id)",
        "LEFT JOIN leagues ON (seedings.tournament_type = 'League' AND seedings.tournament_id = leagues.id)",
        "LEFT JOIN seasons AS tournament_seasons ON tournaments.season_id = tournament_seasons.id",
        "LEFT JOIN seasons AS league_seasons ON leagues.season_id = league_seasons.id",
        'LEFT JOIN "regions" AS tournament_regions ON ("tournament_regions"."id" = "tournaments"."organizer_id" AND "tournaments"."organizer_type" = \'Region\')',
        'LEFT JOIN "regions" AS league_regions ON ("league_regions"."id" = "leagues"."organizer_id" AND "leagues"."organizer_type" = \'Region\')',
        :player
      ]
    }
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
end
