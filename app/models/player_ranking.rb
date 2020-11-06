class PlayerRanking < ActiveRecord::Base
  belongs_to :discipline
  belongs_to :player
  belongs_to :region
  belongs_to :season
  belongs_to :player_class
  belongs_to :p_player_class, foreign_key: :p_player_class_id, class_name: "PlayerClass"
  belongs_to :pp_player_class, foreign_key: :pp_player_class_id, class_name: "PlayerClass"
  belongs_to :tournament_player_class, foreign_key: :tournament_player_class_id, class_name: "PlayerClass"

  serialize :data, Hash
  serialize :t_ids, Array

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
      "Kegel" => :balls,
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
      "Turniere" => "player_rankings.t_ids",
  }
end
