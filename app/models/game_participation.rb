# == Schema Information
#
# Table name: game_participations
#
#  id         :bigint           not null, primary key
#  data       :text
#  gd         :float
#  gname      :string
#  hs         :integer
#  innings    :integer
#  points     :integer
#  result     :integer
#  role       :string
#  sets       :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  game_id    :integer
#  player_id  :integer
#
# Indexes
#
#  index_game_participations_on_foreign_keys  (game_id,player_id,role) UNIQUE
#
class GameParticipation < ApplicationRecord
  include LocalProtector
  include CableReady::Broadcaster
  include RegionTaggable
  include Searchable

  belongs_to :player, optional: true
  belongs_to :game

  def display_gname
    game&.display_gname || Game.display_ranking_key(gname) || gname
  end

  before_save :set_paper_trail_whodunnit

  after_update do
    # table_monitor = game.andand.table_monitor
    # if table_monitor.present?
    #   table_monitor.get_options!(I18n.locale)
    #   if role == "playera"
    #     Rails.logger.info "game_participation.table_monitor[#{table_monitor.andand.id}] #{previous_changes.inspect}"
    #     html = ApplicationController.render(
    #       partial: "table_monitors/show",
    #       locals: { table_monitor: table_monitor, full_screen: false }
    #     )
    #     full_screen_html = ApplicationController.render(
    #       partial: "table_monitors/show",
    #       locals: { table_monitor: table_monitor, full_screen: true }
    #     )
    #     cable_ready["table-monitor-stream"].inner_html(
    #       selector: "#full_screen_table_monitor_#{table_monitor.id}",
    #       html: full_screen_html
    #     )
    #     cable_ready["table-monitor-stream"].inner_html(
    #       selector: "#table_monitor_#{table_monitor.id}",
    #       html: html
    #     )
    #     cable_ready.broadcast
    #   end
    # end
  end

  serialize :data, coder: JSON, type: Hash

  COLUMN_NAMES = {
    # IDs (versteckt, nur für Backend-Filterung)
    "id" => "game_participations.id",
    "game_id" => "games.id",
    "tournament_id" => "tournaments.id",
    "discipline_id" => "disciplines.id",
    "player_id" => "players.id",
    "club_id" => "clubs.id",

    # Referenzen (Dropdown/Select)
    "Tournament" => "tournaments.title",
    "Discipline" => "disciplines.name",
    "Club" => "clubs.shortname",

    # Eigene Felder
    "Game" => "games.gname",
    "Date" => "tournaments.date::date",
    "Player" => "players.lastname||', '||players.firstname",
    "Role" => "game_participations.role",
    "Points" => "game_participations.points",
    "Result" => "game_participations.result",
    "Innings" => "game_participations.innings",
    "GD" => "game_participations.gd",
    "HS" => "game_participations.hs"
  }.freeze

  self.ignored_columns = ["region_ids"]

  # Searchable concern provides search_hash
  def self.text_search_sql
    "(tournaments.title ilike :search)
     or (games.gname ilike :search)
     or (disciplines.name ilike :search)
     or (players.fl_name ilike :search)
     or (players.lastname ilike :search)
     or (players.firstname ilike :search)
     or (clubs.shortname ilike :search)"
  end

  def self.search_joins
    [
      "LEFT JOIN games on (game_participations.game_id = games.id)",
      "LEFT JOIN tournaments ON (games.tournament_id = tournaments.id)",
      "LEFT JOIN disciplines ON (disciplines.id = tournaments.discipline_id)",
      "LEFT JOIN players ON players.id = game_participations.player_id",
      "LEFT JOIN season_participations ON season_participations.player_id = players.id",
      "LEFT JOIN clubs ON clubs.id = season_participations.club_id"
    ]
  end

  def self.search_distinct?
    true # wegen season_participations können Duplikate entstehen
  end

  def self.cascading_filters
    {
      "tournament_id" => [],
      "discipline_id" => []
    }
  end

  def self.field_examples(field_name)
    case field_name
    when "Game"
      { description: "Partie-Name/Nummer", examples: ["Partie 1", "Finale"] }
    when "Tournament"
      { description: "Turnier auswählen", examples: [] }
    when "Discipline"
      { description: "Disziplin auswählen", examples: [] }
    when "Player"
      { description: "Spieler-Name", examples: ["Meyer, Hans"] }
    when "Club"
      { description: "Verein", examples: [] }
    when "Date"
      { description: "Spiel-Datum", examples: ["2024-01-15", "> 2024-01-01"] }
    when "Role"
      { description: "Spieler-Rolle", examples: %w[home guest playera playerb] }
    when "Points", "Result", "Innings", "GD", "HS"
      { description: "Numerischer Wert", examples: ["> 100", "= 50", "<= 200"] }
    else
      super
    end
  end

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    data_will_change!
    self.data = JSON.parse(h.to_json)
    # save!
  end
end
