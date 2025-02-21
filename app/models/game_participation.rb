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
  belongs_to :player, optional: true
  belongs_to :game

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
    "#" => "games.seqno",
    "Game" => "games.gname",
    "Tournament" => "tournaments.title",
    "Discipline" => "disciplines.name",
    "Date" => "tournaments.date",
    "Player" => "players.lastname||', '||players.firstname",
    "Club" => "clubs.shortname",
    "Role" => "game_participations.role",
    "Points" => "game_participations.points",
    "Result" => "game_participations.result",
    "Innings" => "game_participations.innings",
    "GD" => "game_participations.gd",
    "HS" => "game_participations.hs"
  }

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    data_will_change!
    self.data = JSON.parse(h.to_json)
    # save!
  end
end
