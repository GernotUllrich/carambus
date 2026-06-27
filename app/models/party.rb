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
  include Searchable

  self.ignored_columns = ["region_ids"]

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
    # IDs (versteckt, nur für Backend-Filterung)
    "id" => "parties.id",
    "league_id" => "parties.league_id",
    "season_id" => "seasons.id",
    "region_id" => "regions.id",

    # Referenzen (Dropdown/Select)
    "League" => "leagues.name",
    "Season" => "seasons.name",
    "Region" => "regions.shortname",

    # Eigene Felder
    "Date" => "parties.date::date",
  }.freeze

  # Searchable concern provides search_hash
  def self.text_search_sql
    "(leagues.name ilike :search)
     or (leagues.shortname ilike :search)
     or (regions.shortname ilike :search)
     or (seasons.name ilike :search)"
  end

  def self.search_joins
    [
      :league,
      'LEFT OUTER JOIN "regions" ON ("regions"."id" = "leagues"."organizer_id" AND "leagues"."organizer_type" = \'Region\')',
      'LEFT OUTER JOIN "seasons" ON "seasons"."id" = "leagues"."season_id"'
    ]
  end

  def self.search_distinct?
    false
  end

  def self.cascading_filters
    {
      'season_id' => ['league_id'],
      'region_id' => []
    }
  end

  def self.field_examples(field_name)
    case field_name
    when 'League'
      { description: "Liga auswählen", examples: [] }
    when 'Season'
      { description: "Saison auswählen", examples: [] }
    when 'Region'
      { description: "Region/Veranstalter auswählen", examples: [] }
    when 'Date'
      { description: "Spieltag-Datum", examples: ["2024-01-15", "> 2024-01-01"] }
    else
      super
    end
  end

  # Plan 46.5-03: Phantom-Duplikat-Cleanup. Entfernt LEERE Dubletten (0 party_games UND kein
  # Ziffern-Ergebnis) je natürlichem Schlüssel (league_id + day_seqno + teams) — bewusst OHNE
  # round_name, denn die Alt-Phantome (alte Scraper-Logik) haben round_name=nil, echte Parties
  # aber gesetzt; mit round_name würden sie nicht als Dubletten desselben Spieltags erkannt.
  # (day_seqno + teams identifiziert den Spieltag eindeutig.) Behält IMMER mindestens eine Party
  # je Termin und NIE eine gespielte (party_games/Ergebnis). Default dry_run (nur Report).
  # Authority-seitig — LocalProtector blockt global-Record-Deletes auf Local-Servern. Idempotent.
  # MEMORY-SAFE: verarbeitet PRO LIGA (nicht alle ~15k Parties + ~100k party_games auf einmal —
  # das OOM't auf der Produktions-Authority). Pro Liga sind es nur hunderte Records.
  def self.cleanup_phantom_duplicates(scope: Party.all, dry_run: true)
    report = {groups_with_dupes: 0, deleted: 0, deleted_ids: [], kept: 0, dry_run: dry_run}
    # WICHTIG: data wird teils mit Symbol-Key {result: …} gespeichert (Ergebnis-Nachtrag/Create),
    # teils mit String-Key. p.data["result"] allein verfehlt Symbol-Einträge → eine Party MIT echtem
    # Ergebnis (Symbol-Key) aber ohne party_games würde sonst als Phantom gelöscht (DATENVERLUST).
    # Daher BEIDE Keys prüfen (wie League::StandingsCalculator).
    phantom = ->(p) { p.party_games.empty? && (p.data["result"] || p.data[:result]).to_s !~ /\d/ }
    scope.distinct.pluck(:league_id).compact.each do |lid|
      # Nur diese Liga laden (Schlüssel innerhalb der Liga = day_seqno + teams).
      scope.where(league_id: lid).includes(:party_games)
        .group_by { |p| [p.day_seqno, p.league_team_a_id, p.league_team_b_id] }
        .each do |_key, parties|
        next if parties.size <= 1
        reals = parties.reject { |p| phantom.call(p) }
        to_delete = if reals.any?
          parties.select { |p| phantom.call(p) } # echte/gespielte bleiben ALLE
        else
          parties - [parties.min_by(&:id)] # nur Phantome: genau eine (niedrigste id) behalten
        end
        next if to_delete.empty?
        report[:groups_with_dupes] += 1
        report[:kept] += parties.size - to_delete.size
        report[:deleted] += to_delete.size
        to_delete.each do |p|
          report[:deleted_ids] << p.id
          p.destroy unless dry_run
        end
      end
    end
    report
  end

  def kickoff_switches_with
    read_attribute(:kickoff_switches_with).presence || "set"
  end

  def intermediate_result
    # TODO GameParticipation is only for tournament games and PartyGame is not a Game!!
    return [0, 0]
    raise "GameParticipation is only for tournament games and PartyGame is not a Game!!"
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
  rescue StandardError => e
    Rails.logger.info "OOPS- #{e}"
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
