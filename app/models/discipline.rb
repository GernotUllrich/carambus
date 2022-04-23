# == Schema Information
#
# Table name: disciplines
#
#  id                  :bigint           not null, primary key
#  data                :text
#  name                :string
#  type                :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  super_discipline_id :integer
#  table_kind_id       :integer
#
# Indexes
#
#  index_disciplines_on_foreign_keys            (name,table_kind_id) UNIQUE
#  index_disciplines_on_name_and_table_kind_id  (name,table_kind_id) UNIQUE
#
class Discipline < ApplicationRecord
  has_many :discipline_tournament_plans
  belongs_to :table_kind
  belongs_to :super_discipline, foreign_key: :super_discipline_id, :class_name => "Discipline"
  has_many :sub_disciplines, foreign_key: :super_discipline_id, :class_name => "Discipline"
  has_many :tournaments
  has_many :player_classes
  has_many :player_rankings
  has_many :leagues
  has_many :seeding_plays, class_name: "Seeding", :foreign_key => :playing_discipline_id

  DE_DISCIPLINE_NAMES = ["Pool", "Snooker", "Kegel", "5 Kegel", "Karambol großes Billard", "Karambol kleines Billard", "Biathlon"]
  DISCIPLINE_NAMES = ["Pool", "Snooker", "Pin Billards", "5-Pin Billards", "Carambol Match Billard", "Carambol Small Billard", "Biathlon"]

  MAJOR_DISCIPLINES = {
      "Pool" => {"table_kind" => ["Pool"]},
      "Snooker" => {"table_kind" => ["Snooker"]},
      "Pin Billards" => {"table_kind" => ["Small Table", "Match Table", "Large Table"]},
      "5-Pin Billards" => {"table_kind" => ["Small Table", "Match Table", "Large Table"]},
      "Carambol Large Table" => {"table_kind" => ["Large Table"]},
      "Carambol Small Table" => {"table_kind" => ["Small Table"]},
      "Carambol Match Table" => {"table_kind" => ["Match Table"]},
      "Biathlon" => {"table_kind" => ["Small Table"]}
  }

  DISCIPLINE_CLASS_LIMITS =
      {# GD-Min oder [GD-Min, Bälle-Min]
       "Freie Partie groß" => {
           "1" => 25.0,
           "2" => 16.0,
           "3" => 10.0,
           "4" => 7.0,
           "5" => 4.0,
           "6" => 2.0,
           "7" => 0.0,
       },
       "Cadre 47/2" => {
           "1" => 7.0,
           "2" => 0.0
       },
       "Cadre 71/2" => {
           "1" => 5.0,
           "2" => 0.0
       },
       "Einband groß" => {
           "1" => 3.0,
           "2" => 0.0
       },
       "Dreiband groß" => {
           "1" => [0.7, 66],
           "2" => [0.5, 45],
           "3" => 0.0
       },
       "Freie Partie klein" => {
           "1" => 25.0,
           "2" => 16.0,
           "3" => 10.0,
           "4" => 7.0,
           "5" => 4.0,
           "6" => 2.0,
           "7" => 0.0,
       },
       "Cadre 35/2" => {
           "1" => 7.0,
           "2" => 0.0
       },
       "Cadre 52/2" => {
           "1" => 5.0,
           "2" => 0.0
       },
       "Einband klein" => {
           "1" => 2.5,
           "2" => 0.0
       },
       "Dreiband klein" => {
           "1" => 0.8,
           "2" => 0.0,
       },
      }

  BA_MAJOR_DISCIPLINES = MAJOR_DISCIPLINES.keys - ["Carambol Match Table"]
  COLUMN_NAMES = {
      "Name" => "disciplines.name",
      "is a" => "sup.name",
      "Table Kind" => "table_kinds.name",
  }
  KEY_MAPPINGS = {
      "Pool" => {
          :g => "G",
          :v => "V",
          :quote => "Quote",
          :sp_g => "Sp.G",
          :sp_v => "Sp.V",
          :sp_quote => "Sp.Quote",
          :t_ids => "t_ids"
      },
      "14.1 endlos" => {
          :innings => "Aufn",
          :balls => "Bälle",
          :g => "G",
          :v => "V",
          :btg => "GD",
          :bed => "HGD",
          :hs => "HS",
          :quote => "Quote",
          :t_ids => "t_ids"
      },
      "Carambol" => {

          :innings => "Aufn",
          :balls => "Bälle",
          :btg => "GD",
          :bed => "BED",
          :hs => "HS",
          :t_ids => "t_ids",
          :ranking => {
              :column_header => "GD",
              :formula => :carambol_str,
          }
      },
      "Snooker" => {
          :sets => "Frames",
          :hs => "HB",
          :g => "G",
          :v => "V",
          :t_ids => "t_ids"
      },
      "5-Pin Billards" => {
          :points => "Partiepunkte",
          :sets => "Satzpunkte",
          :balls => "Kegel",
          :btg => "GD",
          :t_ids => "t_ids"
      }
  }

  def carambol_str(player_ranking, opts = {})
    if opts[:v1].present? && opts[:v2].present? && opts[:v2].to_i > 0
      sprintf("%.2f", (opts[:v1].to_f / opts[:v2].to_f))
    else
      ""
    end
  end

  def class_from_accumulated_result(player_ranking)
    case root.name
    when "Carambol"
      return class_from_val(player_ranking.btg.to_f)
    else
      ""
    end
  end

  def class_from_val(val)
    DISCIPLINE_CLASS_LIMITS[name].to_a.each do |k,v|
      if val > Array(v)[0]
        return k
      end
    end
    return ""
  end

  def root
    @root ||= super_discipline.blank? ? self : super_discipline.root
  end
end
