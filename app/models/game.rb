# frozen_string_literal: true

# == Schema Information
#
# Table name: games
#
#  id              :bigint           not null, primary key
#  data            :text
#  ended_at        :datetime
#  gname           :string
#  group_no        :integer
#  roles           :text
#  round_no        :integer
#  seqno           :integer
#  started_at      :datetime
#  table_no        :integer
#  tournament_type :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  tournament_id   :integer
#
class Game < ApplicationRecord
  include LocalProtector

  belongs_to :tournament, polymorphic: true, optional: true
  has_many :game_participations, dependent: :destroy
  has_one :table_monitor, dependent: :nullify
  has_one :was_table_monitor, foreign_key: :prev_game_id, class_name: "TableMonitor", dependent: :nullify

  before_save :set_paper_trail_whodunnit

  serialize :data, coder: YAML, type: Hash

  #   #"data"=>
  #   { "ba_results" =>
  #       { "Gruppe" => 1,
  #         "Partie" => 5,
  #         "Spieler1" => 352853,
  #         "Spieler2" => 121340,
  #         "Points1" => 3,
  #         "Points2" => 0,
  #         "Sets1" => 2,
  #         "Sets2" => 0,
  #         "Ergebnis1" => 150,
  #         "Ergebnis2" => 64,
  #         "Aufnahmen1" => 22,
  #         "Aufnahmen2" => 22,
  #         "Höchstserie1" => 20,
  #         "Höchstserie2" => 15,
  #         "Tischnummer" => 2
  #       },
  #     {
  #     "sets" =>
  #       [
  #         { "Gruppe" => 1,
  #           "SetNo" => 1,
  #           "Spieler1" => 352853,
  #           "Spieler2" => 121340,
  #           "Ergebnis1" => 75,
  #           "Ergebnis2" => 32,
  #           "Aufnahmen1" => 11,
  #           "Aufnahmen2" => 11,
  #           "Höchstserie1" => 20,
  #           "Höchstserie2" => 15,
  #           "Tischnummer" => 2
  #         },
  #         { "Gruppe" => 1,
  #           "SetNo" => 2,
  #           "Partie" => 5,
  #           "Spieler1" => 352853,
  #           "Spieler2" => 121340,
  #           "Ergebnis1" => 75,
  #           "Ergebnis2" => 32,
  #           "Aufnahmen1" => 11,
  #           "Aufnahmen2" => 11,
  #           "Höchstserie1" => 20,
  #           "Höchstserie2" => 15,
  #           "Tischnummer" => 2
  #         },
  #       ]
  #   }
  #   }

  MIN_ID = 50_000_000

  before_create :log

  def log
    Tournament.logger.info "NEW Game attributes = #{attributes.inspect}"
  end

  before_save do
    Tournament.logger.info "Game[#{id}] - #{gname} ##{seqno}" if seqno_changed?
  end

  COLUMN_NAMES = {
    "Date" => "tournaments.date",
    "Tournament" => "tournaments.title",
    "Remarks" => "games.data"
  }.freeze

  def log_state_change
    if DEBUG
      Rails.logger.info "-------------m6[#{id}]-------->>> log_state_change <<<------------------------------------------"
    end
    if state_changed?
      # Tournament.logger.info "[PartyMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]} #{caller.select{|s| s.include?("/app/")}.join("\n")}"
      Tournament.logger.info "[PartyMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}"
      Rails.logger.info "[PartyMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}" if DEBUG
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    data_will_change!
    self.data = JSON.parse(h.to_json)
    # save!
  end

  def deep_delete!(key)
    h = data.dup
    res = nil
    if h[key].present?
      res = h.delete(key)
      data_will_change!
      self.data = JSON.parse(h.to_json)
      save!
    end
    res
  end

  def self.display_ranking_key(ranking_key)
    return unless ranking_key.present?

    if m = ranking_key.match(%r{group(\d+):(\d+)-(\d+)(?:/(\d+))})
      "#{I18n.t("game.display_group_game_name_rp", group_no: m[1], playera: m[2], playerb: m[3], rp: m[4])}".html_safe
    elsif m = ranking_key.match(/group(\d+):(\d+)-(\d+)/)
      "#{I18n.t("game.display_group_game_name", group_no: m[1], playera: m[2], playerb: m[3])}".html_safe
    elsif m = ranking_key.match(/group(\d+)/i)
      "#{I18n.t("game.display_group_game_name_short", group_no: m[1].to_str.gsub("/", ""))}".html_safe
    elsif m = ranking_key.match(%r{hf(/?\d+)})
      "#{I18n.t("game.display_hf_game_name", game_no: m[1].to_str.gsub("/", ""))}"
    elsif m = ranking_key.match(/hf/)
      "#{I18n.t("game.display_hf_game_group")}"
    elsif m = ranking_key.match(%r{vf(/?\d+)})
      "#{I18n.t("game.display_qf_game_name", game_no: m[1])}"
    elsif m = ranking_key.match(%r{qf(/?\d+)})
      "#{I18n.t("game.display_qf_game_name", game_no: m[1])}"
    elsif m = ranking_key.match(/qf/)
      "#{I18n.t("game.display_qf_game_group")}"
    elsif m = ranking_key.match(%r{af(/?\d+)})
      "#{I18n.t("game.display_af_game_name", game_no: m[1].to_str.gsub("/", ""))}"
    elsif m = ranking_key.match(/af/)
      "#{I18n.t("game.display_af_game_group")}"
    elsif m = ranking_key.match(/fin/)
      "#{I18n.t("game.display_fin_game_name")}"
    elsif m = ranking_key.match(/p<(\d+)(?:\.\.|-)(\d+)>(\d+)?/)
      "#{I18n.t("game.display_place_game_name", n1: m[1].to_s.gsub("/", ""), n2: m[2].to_s.gsub("/", ""),
                n3: m[3].to_s.gsub("/", ""))}"
    end
  end

  def display_gname
    Game.display_ranking_key(gname)
  end

  def self.fix_participation(game, opts = {})
    mapping = { "Gr." => :gname, "Ergebnis" => :result, "Aufnahme" => :innings, "HS" => :hs, "GD" => :gd,
                "Punkte" => :points }
    tournament = game.tournament
    begin
      if tournament.present?
        game_participation_ids = game.game_participation_ids
        game.game_participations.delete_all if opts[:touch_games]
        player_a = Player.joins(seedings: :tournament).where(tournaments: { id: tournament.id })
                         .where("players.lastname||', '||players.firstname = :name", name: game.data["Heim"]).first
        if player_a.present?
          gp_a = GameParticipation.where(game_id: game.id, player_id: player_a.id).first
          gp_a.updated_at = Time.now if gp_a.present? && opts(:touch_games)
          gp_a ||= GameParticipation.create(game_id: game.id, player_id: player_a.id)
          gp_a.assign_attributes(role: "Heim")
          gp_a.save
          game_participation_ids.delete(gp_a.id)
        end
        player_b = Player.joins(seedings: :tournament).where(tournaments: { id: tournament.id })
                         .where("players.lastname||', '||players.firstname = :name", name: game.data["Gast"]).first
        if player_b.present?
          gp_b = GameParticipation.where(game_id: game.id, player_id: player_b.id).first
          gp_b.updated_at = Time.now if gp_b.present? && opts(:touch_games)
          gp_b ||= GameParticipation.create(game_id: game.id, player_id: player_b.id)
          gp_b.assign_attributes(role: "Gast")
          gp_b.save
          game_participation_ids.delete(gp_b.id)
        end
        GameParticipation.where(id: game_participation_ids).destroy_all
        gp_a_results = {}
        gp_b_results = {}
        game.data.each do |k, v|
          if /:/.match?(v)
            heim, gast = v.split(":").map(&:strip).map { |str| str =~ /,/ ? str.tr(",", ".").to_f : str.to_i }
            gp_a_results[k] = heim
            gp_b_results[k] = gast
          elsif k == "Gr."
            gp_a_results[k] = v
            gp_b_results[k] = v
          end
        end
        if gp_a.present?
          remarks_a = gp_a.data || {}
          remarks_a["results"] = gp_a_results
          attrs = {}
          if gp_a.data["results"].present?
            attrs = attrs.merge(Array(gp_a.data["results"]).transform_keys { |k| mapping[k] }.symbolize_keys)
          end
          attrs = attrs.merge(data: remarks_a)
          gp_a.assign_attributes(attrs)
          gp_a.save
        end
        if gp_b.present?
          remarks_b = gp_b.data || {}
          remarks_b["results"] = gp_b_results
          attrs = {}
          if gp_b.data["results"].present?
            attrs = attrs.merge(Array(gp_b.data["results"]).transform_keys { |k| mapping[k] }.symbolize_keys)
          end
          attrs = attrs.merge(data: remarks_b)
          gp_b.assign_attributes(attrs)
          gp_b.save
        end
      else
        game.destroy
      end
    rescue StandardError
      game.destroy
    end
  end
end
