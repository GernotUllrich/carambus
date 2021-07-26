# == Schema Information
#
# Table name: games
#
#  id            :bigint           not null, primary key
#  data          :text
#  ended_at      :datetime
#  gname         :string
#  group_no      :integer
#  roles         :text
#  round_no      :integer
#  seqno         :integer
#  started_at    :datetime
#  table_no      :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  tournament_id :integer
#
class Game < ApplicationRecord

  belongs_to :tournament, optional: true
  has_many :game_participations, :dependent => :destroy
  has_one :table_monitor, :dependent => :nullify

  MIN_ID = 50000000
  has_paper_trail
  serialize :data, Hash

  attr_accessor :new_game_data
  serialize :new_game_data, Hash

  before_create :log

  def log
    Tournament.logger.info "NEW Game attributes = #{attributes.inspect}"
  end

  before_save do
    if seqno_changed?
      Tournament.logger.info "Game[#{id}] - #{gname} ##{seqno}"
    end
  end

  COLUMN_NAMES = {
    "Date" => "tournaments.date",
    "Tournament" => "tournaments.title",
    "Remarks" => "games.data",
  }

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    self.data_will_change!
    self.data = JSON.parse(h.to_json)
    save!
  end

  def deep_delete!(key)
    h = data.dup
    res = nil
    if h[key].present?
      res = h.delete(key)
      self.data_will_change!
      self.data = JSON.parse(h.to_json)
      save!
    end
    res
  end

  def self.display_ranking_key(ranking_key)
    if ranking_key.present?
      if m = ranking_key.match(/group(\d+):(\d+)-(\d+)(?:\/(\d+))/)
        "#{I18n.t("game.display_group_game_name_rp", group_no: m[1], playera: m[2], playerb: m[3], rp: m[4])}".html_safe
      elsif m = ranking_key.match(/group(\d+):(\d+)-(\d+)/)
        "#{I18n.t("game.display_group_game_name", group_no: m[1], playera: m[2], playerb: m[3])}".html_safe
      elsif m = ranking_key.match(/group(\d+)/i)
        "#{I18n.t("game.display_group_game_name_short", group_no: m[1].to_str.gsub("/", ""))}".html_safe
      elsif m = ranking_key.match(/hf(\/?\d+)/)
        "#{I18n.t("game.display_hf_game_name", game_no: m[1].to_str.gsub("/", ""))}"
      elsif m = ranking_key.match(/hf/)
        "#{I18n.t("game.display_hf_game_group")}"
      elsif m = ranking_key.match(/qf(\/?\d+)/)
        "#{I18n.t("game.display_qf_game_name", { game_no: m[1] })}"
      elsif m = ranking_key.match(/qf/)
        "#{I18n.t("game.display_qf_game_group")}"
      elsif m = ranking_key.match(/af(\/?\d+)/)
        "#{I18n.t("game.display_af_game_name", { game_no: m[1].to_str.gsub("/", "") })}"
      elsif m = ranking_key.match(/af/)
        "#{I18n.t("game.display_af_game_group")}"
      elsif m = ranking_key.match(/fin/)
        "#{I18n.t("game.display_fin_game_name")}"
      elsif m = ranking_key.match(/p<(\d+)(?:\.\.|-)(\d+)>(\d+)?/)
        "#{I18n.t("game.display_place_game_name", n1: m[1].to_s.gsub("/", ""), n2: m[2].to_s.gsub("/", ""), n3: m[3].to_s.gsub("/", ""))}"
      end
    end
  end

  def display_gname
    Game.display_ranking_key(gname)
  end

  def self.fix_participation(game)
    mapping = { "Gr." => :gname, "Ergebnis" => :result, "Aufnahme" => :innings, "HS" => :hs, "GD" => :gd, "Punkte" => :points }
    tournament = game.tournament
    if tournament.present?
      game.game_participations.delete_all
      player_a = Player.joins(:seedings => :tournament).where(tournaments: { id: tournament.id }).
        where("players.lastname||', '||players.firstname = :name", name: game.data["Heim"]).first
      gp_a = GameParticipation.create(game_id: game.id, player_id: player_a.id, role: "Heim") if player_a.present?
      player_b = Player.joins(:seedings => :tournament).where(tournaments: { id: tournament.id }).
        where("players.lastname||', '||players.firstname = :name", name: game.data["Gast"]).first
      gp_b = GameParticipation.create(game_id: game.id, player_id: player_b.id, role: "Gast") if player_b.present?
      gp_a_results = {}
      gp_b_results = {}
      game.data.each do |k, v|
        if v =~ /:/
          heim, gast = v.split(":").map(&:strip).map { |str| (str =~ /,/) ? str.gsub(",", ".").to_f : str.to_i }
          gp_a_results[k] = heim
          gp_b_results[k] = gast
        elsif k == "Gr."
          gp_a_results[k] = v
          gp_b_results[k] = v
        end
      end
      if gp_a.present?
        remarks_a = gp_a.andand.data || {}
        remarks_a["results"] = gp_a_results
        attrs = {}
        attrs = attrs.merge(Hash[gp_a.data["results"].map { |k, v| [mapping[k], v] }].symbolize_keys) if gp_a.data["results"].present?
        attrs = attrs.merge(data: remarks_a)
        gp_a.update(attrs)
      end
      if gp_b.present?
        remarks_b = gp_b.andand.data || {}
        remarks_b["results"] = gp_b_results
        attrs = {}
        attrs = attrs.merge(Hash[gp_b.data["results"].map { |k, v| [mapping[k], v] }].symbolize_keys) if gp_b.data["results"].present?
        attrs = attrs.merge(data: remarks_b)
        gp_b.update(attrs)
      end
    else
      game.destroy
    end
  end
end
