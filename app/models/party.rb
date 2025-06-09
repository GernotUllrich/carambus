# == Schema Information
#
# Table name: parties
#
#  id                             :bigint           not null, primary key
#  allow_follow_up                :boolean          default(TRUE), not null
#  color_remains_with_set         :boolean          default(TRUE), not null
#  continuous_placements          :boolean          default(FALSE), not null
#  data                           :text
#  date                           :datetime
#  day_seqno                      :integer
#  fixed_display_left             :string
#  group                          :string
#  kickoff_switches_with          :string
#  manual_assignment              :boolean
#  party_no                       :integer
#  register_at                    :date
#  remarks                        :text
#  reported_at                    :datetime
#  reported_by                    :string
#  round                          :string
#  section                        :string
#  sets_to_play                   :integer          default(1), not null
#  sets_to_win                    :integer          default(1), not null
#  source_url                     :string
#  status                         :integer
#  sync_date                      :datetime
#  team_size                      :integer          default(1), not null
#  time                           :datetime
#  time_out_stoke_preparation_sec :integer          default(45)
#  time_out_warm_up_first_min     :integer          default(5)
#  time_out_warm_up_follow_up_min :integer          default(3)
#  timeout                        :integer          default(0), not null
#  timeouts                       :integer
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  ba_id                          :integer
#  cc_id                          :integer
#  host_league_team_id            :integer
#  league_id                      :integer
#  league_team_a_id               :integer
#  league_team_b_id               :integer
#  location_id                    :integer
#  no_show_team_id                :integer
#  reported_by_player_id          :integer
#
class Party < ApplicationRecord
  include LocalProtector
  include SourceHandler
  include RegionTaggable
  belongs_to :league, class_name: "League", foreign_key: :league_id
  has_many :games, as: :tournament, class_name: "Game", dependent: :destroy
  belongs_to :league_team_a, class_name: "LeagueTeam", foreign_key: :league_team_a_id, optional: true
  belongs_to :league_team_b, class_name: "LeagueTeam", foreign_key: :league_team_b_id, optional: true
  belongs_to :host_league_team, class_name: "LeagueTeam", foreign_key: :host_league_team_id, optional: true
  belongs_to :location, optional: true
  belongs_to :no_show_team, class_name: "LeagueTeam", foreign_key: :no_show_team_id, optional: true

  has_one :party_monitor, dependent: :nullify
  has_one :party_cc, dependent: :destroy
  has_many :party_games, -> { order("seqno") }
  has_many :seedings, -> { order(position: :asc) }, as: :tournament, dependent: :destroy

  serialize :data, coder: JSON, type: Hash
  serialize :remarks, coder: YAML, type: Hash

  REFLECTIONS = %w[versions
                   league
                   games
                   league_team_a
                   league_team_b
                   host_league_team
                   location
                   no_show_team
                   party_cc
                   party_games]

  COLUMN_NAMES = {
    "BA_ID" => "league_team_ccs.ba_id",
    "CC_ID" => "league_team_ccs.cc_id",
    "a_team" => "league_team_a.shortname",
    "b_team" => "league_team_a.shortname",
    "host" => "host_league_team.shortname",
    "league" => "leagues.name",
    "Sparte" => "league_team_ccs.branch_cc.name",
    "league_id" => "parties.league_id",
    "date" => "parties.date::date"
  }

  def self.search_hash(params)
    {
      model: Party,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: params[:sSearch],
      column_names: Party::COLUMN_NAMES,
      raw_sql: "(league.name ilike :search)
 or (league_team_a.name ilike :search)
 or (league_team_b.name ilike :search)
 or (host_league_team.name ilike :search)",
      joins: [
        :league,
        'LEFT OUTER JOIN "league_teams" AS "league_team_a" ON "parties"."league_team_a_id" = "league_teams"."id"',
        'LEFT OUTER JOIN "league_teams" AS "league_team_b" ON "parties"."league_team_b_id" = "league_teams"."id"',
        'LEFT OUTER JOIN "league_teams" AS "host_league_team" ON "parties"."host_league_team_id" = "league_teams"."id"',
      ]
    }
  end

  def kickoff_switches_with
    read_attribute(:kickoff_switches_with).presence || "set"
  end

  def intermediate_result
    points_l = nil
    points_r = nil
    players = GameParticipation.joins(:game).joins("left outer join parties on parties.id = games.tournament_id").where.not(points: nil).where(games: {
                                                                                                                                                 tournament_id: id, tournament_type: "Party"
                                                                                                                                               }).map(&:player).uniq
    players_hash = players.each_with_object({}) do |player, memo|
      memo[player.id] = player
    end
    GameParticipation.joins(:game).joins("left outer join parties on parties.id = games.tournament_id").where.not(points: nil).where(games: {
                                                                                                                                       tournament_id: id, tournament_type: "Party"
                                                                                                                                     }).each do |gp|
      nls = "a"
      nrs = "b"
      # - TODO far to complicated!
      if gp.game.andand.data.andand["ba_results"].present? && (gp.game.data["ba_results"]["Spieler1"] == players_hash[Array(party_monitor.get_attribute_by_gname(
                                                                                                                              gp.game.gname, "player_b"
                                                                                                                            ))[0]].andand.ba_id)
        nls = "b"
        nrs = "a"
      end
      points_l = points_l.to_i + gp.points if gp.role == "player#{nls}"
      points_r = points_r.to_i + gp.points if gp.role == "player#{nrs}"
    end
    [points_l, points_r]
  rescue StandardError
    Rails.logger.info "OOPS"
    raise StandardError unless Rails.env == "production"
  end

  def name
    "#{league_team_a.name} - #{league_team_b.name}"
  end

  def title
    name
  end

  def party_nr
    unless party_no.present?
      first_cc_id = league.parties.order(:cc_id).first.cc_id
      self.unprotected = true
      self.party_no = cc_id - first_cc_id + 1
      save!
      self.unprotected = false
    end
    party_no.to_i
  end

  def player_controlled?
    false
  end

  def handicap_tournier?
    false
  end

  def manual_assignment
    true
  end

  def cc_link
    "#{league.organizer.public_cc_url_base}sb_spielbericht.php?p=#{league.organizer.cc_id}--#{league.season.name}-#{league.cc_id}-#{league.cc_id2.presence || "0"}-#{cc_id}"
  end

  def get_non_show_team
    return league_team_b.id if no_show_team_id == league_team_a.id
    league_team_a.id
  end
end
