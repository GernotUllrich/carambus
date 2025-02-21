# frozen_string_literal: true

# == Schema Information
#
# Table name: league_teams
#
#  id         :bigint           not null, primary key
#  name       :string
#  shortname  :string
#  source_url :string
#  sync_date  :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ba_id      :integer
#  cc_id      :integer
#  club_id    :integer
#  league_id  :integer
#
class LeagueTeam < ApplicationRecord
  include LocalProtector
  include SourceHandler
  belongs_to :league, optional: true
  belongs_to :club, optional: true
  has_many :parties_a, class_name: "Party", foreign_key: :league_team_a_id
  has_many :parties_b, class_name: "Party", foreign_key: :league_team_b_id
  has_many :parties_as_host, class_name: "Party", foreign_key: :host_league_team_id
  has_many :no_show_parties, class_name: "Party", foreign_key: :no_show_team_id
  has_one :league_team_cc
  has_many :seedings, dependent: :destroy

  serialize :data, coder: JSON, type: Hash

  COLUMN_NAMES = {
    "BA_ID" => "league_team_ccs.ba_id",
    "CC_ID" => "league_team_ccs.cc_id",
    "Name" => "league_team_ccs.name",
    "Sparte" => "league_team_ccs.branch_cc.name",
    "league_id" => "league_teams.league_id"
  }.freeze

  def self.search_hash(params)
    {
      model: LeagueTeam,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: [params[:sSearch], params[:search]].compact.join("&").to_s,
      column_names: LeagueTeam::COLUMN_NAMES,
      raw_sql: "(league_teams.name ilike :search)
or (league_teams.shortname ilike :search)
or (leagues.name ilike :search)",
      joins: :league
    }
  end

  def cc_id_link
    "#{league.organizer.public_cc_url_base}sb_spielplan.php?p=#{league.organizer.cc_id}--#{league.season.name}-#{league.cc_id}-#{league.cc_id2.presence || "0"}-#{cc_id}"
  end

  def scrape_players_from_ba_league_team; end
end
