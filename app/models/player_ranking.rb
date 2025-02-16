# frozen_string_literal: true

# == Schema Information
#
# Table name: player_rankings
#
#  id                         :bigint           not null, primary key
#  balls                      :integer
#  bed                        :float
#  btg                        :float
#  g                          :integer
#  gd                         :float
#  hs                         :integer
#  innings                    :integer
#  org_level                  :string
#  p_gd                       :float
#  points                     :integer
#  pp_gd                      :float
#  quote                      :float
#  rank                       :integer
#  remarks                    :text
#  sets                       :integer
#  sp_g                       :integer
#  sp_quote                   :float
#  sp_v                       :integer
#  status                     :string
#  t_ids                      :text
#  v                          :integer
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  discipline_id              :integer
#  p_player_class_id          :integer
#  player_class_id            :integer
#  player_id                  :integer
#  pp_player_class_id         :integer
#  region_id                  :integer
#  season_id                  :integer
#  tournament_player_class_id :integer
#
class PlayerRanking < ApplicationRecord
  include LocalProtector
  belongs_to :discipline
  belongs_to :player
  belongs_to :region
  belongs_to :season

  # belongs_to :player_class
  # belongs_to :p_player_class, foreign_key: :p_player_class_id, class_name: "PlayerClass"
  # belongs_to :pp_player_class, foreign_key: :pp_player_class_id, class_name: "PlayerClass"
  # belongs_to :tournament_player_class, foreign_key: :tournament_player_class_id, class_name: "PlayerClass"

  serialize :remarks, coder: YAML, type: Hash
  serialize :t_ids, coder: YAML, type: Array

  KEY_MAPPINGS = {
    "Punkte" => :points,
    "Aufn" => :innings,
    "Bälle" => :balls,
    "t_ids" => :t_ids,
    "G" => :g,
    "V" => :v,
    "GD" => :btg,
    "HGD" => :bed,
    "HS" => :hs,
    "Quote" => :quote,
    "Sp.G" => :sp_g,
    "Sp.Quote" => :sp_quote,
    "Sp.V" => :sp_v,
    "BED" => :bed,
    "Frames" => :sets,
    "HB" => :hs,
    "Partiepunkte" => :points,
    "Satzpunkte" => :sets,
    "Kegel" => :balls
  }

  COLUMN_NAMES = {
    "Rank" => "player_rankings.rank",
    "Player" => "players.lastname||', '||players.lastname",
    "Region" => "regions.shortname",
    "Club" => "clubs.shortname",
    "Season" => "seasons.name",
    "Discipline" => "disciplines.name",
    "Balls" => "player_rankings.balls",
    "Innings" => "player_rankings.innings",
    "Gd" => "cast(player_rankings.balls as float)/NULLIF(player_rankings.innings,0) as ggd",
    "Hs" => "player_rankings.hs",
    "Bed" => "player_rankings.bed",
    "Btg" => "player_rankings.btg",
    "Class" => "",
    "G" => "player_rankings.g",
    "V" => "player_rankings.v",
    "Quote" => "cast(player_rankings.g as float)/NULLIF(player_rankings.g + player_rankings.v, 0) as gv_quote",
    "Sets" => "player_rankings.sets",
    "Sp.G" => "player_rankings.sp_g",
    "Sp.V" => "player_rankings.sp_v",
    "Sp.Quote" => "cast(player_rankings.sp_g as float)/NULLIF(player_rankings.sp_g + player_rankings.sp_v, 0) as sp_quote",
    # "Player class" => "player_rankings.player_class",
    # "P player class" => "player_rankings.p_player_class",
    # "Pp player class" => "player_rankings.pp_player_class",
    # "P gd" => "player_rankings.p_gd",
    # "Pp gd" => "player_rankings.pp_gd",
    # "Org level" => "player_rankings.org_level",
    # "Status" => "player_rankings.status",
    "Turniere" => "player_rankings.t_ids"
  }.freeze

  def self.search_hash(params)
    {
      model: PlayerRanking,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: "#{[params[:sSearch], params[:search]].compact.join("&")}",
      column_names: PlayerRanking::COLUMN_NAMES,
      raw_sql: "(regions.shortname ilike :search)
 or (disciplines.name ilike :search)
 or (players.fl_name ilike :search)
 or (seasons.name ilike :search)",
      joins: [:discipline, :player, :region, :season]
    }
  end

  def self.ranking_csv(season, region)
    lines = []
    lines << "Discipline;Rank;Player;btg24;btg23;btg22"
    PlayerRanking.where(season_id: 15, region_id: 1).joins(:discipline, :player).order(:discipline_id, :rank).map do |r|
      btg_1 = PlayerRanking.where(
        player: r.player,
        discipline: r.discipline,
        season_id: season.id - 1,
        region_id: region.id
      ).first&.btg
      btg_2 = PlayerRanking.where(
        player: r.player,
        discipline: r.discipline,
        season_id: season.id - 1,
        region_id: region.id
      ).first&.btg
      lines << "#{r.discipline.name};#{r.rank};#{r.player.fl_name};#{btg_1};#{r.btg};#{btg_2}"
    end
    f = File.new("#{Rails.root}/tmp/ranking_season_#{region.shortname}-#{season.name.gsub("/", "-")}.csv", "w")
    f.write(lines.join("\n"))
    f.close
  end
end
