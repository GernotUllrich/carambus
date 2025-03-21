# frozen_string_literal: true

# == Schema Information
#
# Table name: disciplines
#
#  id                  :bigint           not null, primary key
#  data                :text
#  name                :string
#  synonyms            :text
#  team_size           :integer
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
  include LocalProtector
  has_many :discipline_tournament_plans
  belongs_to :table_kind, optional: true
  belongs_to :super_discipline, foreign_key: :super_discipline_id, class_name: "Discipline", optional: true
  has_many :sub_disciplines, foreign_key: :super_discipline_id, class_name: "Discipline"
  has_many :tournaments
  has_many :player_classes
  has_many :player_rankings
  has_one :discipline_cc, foreign_key: :discipline_id
  has_many :leagues
  has_many :game_plan_ccs
  has_many :game_plan_row_ccs
  has_many :seeding_plays, class_name: "Seeding", foreign_key: :playing_discipline_id
  has_one :competition_cc, foreign_key: :discipline_id
  has_one :branch_cc, foreign_key: :discipline_id

  before_save :update_synonyms

  validates :name, presence: true

  def update_synonyms
    self.synonyms = (synonyms.to_s.split("\n") + [name]).uniq.join("\n")
  end

  DE_DISCIPLINE_NAMES = ["Pool", "Snooker", "Kegel", "5 Kegel", "Karambol großes Billard",
                         "Karambol kleines Billard", "Biathlon"].freeze
  DISCIPLINE_NAMES = ["Pool", "Snooker", "Pin Billards", "5-Pin Billards",
                      "Carambol Match Billard", "Carambol Small Billard", "Biathlon"].freeze

  MAJOR_DISCIPLINES = {
    "Pool" => { "table_kind" => ["Pool"] },
    "Snooker" => { "table_kind" => ["Snooker"] },
    "Pin Billards" => { "table_kind" => ["Small Table", "Match Table", "Large Table"] },
    "5-Pin Billards" => { "table_kind" => ["Small Table", "Match Table", "Large Table"] },
    "Carambol Large Table" => { "table_kind" => ["Large Table"] },
    "Carambol Small Table" => { "table_kind" => ["Small Table"] },
    "Carambol Match Table" => { "table_kind" => ["Match Table"] },
    "Biathlon" => { "table_kind" => ["Small Table"] }
  }.freeze

  POOL_DISCIPLINE_MAP = ["8-Ball", "9-Ball", "10-Ball", "14.1 endlos"].freeze
  KARAMBOL_INNINGS_MAP = [0, 20, 25, 30].freeze
  KARAMBOL_POINTS_MAP = %w[10 20 40 80 100 200 400].freeze
  KARAMBOL_DISCIPLINE_MAP = [
    "Dreiband klein",
    "Freie Partie klein",
    "Einband klein",
    "Cadre 52/2",
    "Cadre 35/2",
    "Eurokegel",
    "Dreiband groß",
    "Freie Partie groß",
    "Einband groß",
    "Cadre 71/2",
    "Cadre 47/2",
    "Cadre 47/1",
    "5-Pin Billards",
    "Biathlon"
  ].freeze

  DISCIPLINE_CLASS_LIMITS =
    { # GD-Min oder [GD-Min, Bälle-Min]
      "Freie Partie groß" => {
        "1" => 25.0,
        "2" => 16.0,
        "3" => 10.0,
        "4" => 7.0,
        "5" => 4.0,
        "6" => 2.0,
        "7" => 0.0
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
        "7" => 0.0
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
        "2" => 0.0
      }
    }.freeze

  BA_MAJOR_DISCIPLINES = MAJOR_DISCIPLINES.keys - ["Carambol Match Table"]
  COLUMN_NAMES = {
    "Name" => "disciplines.name",
    "Table Kind" => "table_kinds.name"
  }.freeze
  def self.search_hash(params)
    {
      model: Discipline,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: "#{[params[:sSearch], params[:search]].compact.join("&")}",
      column_names: Discipline::COLUMN_NAMES,
      raw_sql: "(disciplines.name ilike :search)
 or (table_kinds.name ilike :search)",
      joins: :table_kind
    }
  end
  KEY_MAPPINGS = {
    "Pool" => {
      g: "G",
      v: "V",
      quote: "Quote",
      sp_g: "Sp.G",
      sp_v: "Sp.V",
      sp_quote: "Sp.Quote",
      t_ids: "t_ids"
    },
    "14.1 endlos" => {
      innings: "Aufn",
      balls: "Bälle",
      g: "G",
      v: "V",
      btg: "GD",
      bed: "HGD",
      hs: "HS",
      quote: "Quote",
      t_ids: "t_ids"
    },
    "Carambol" => {

      innings: "Aufn",
      balls: "Bälle",
      btg: "GD",
      bed: "BED",
      hs: "HS",
      t_ids: "t_ids",
      ranking: {
        column_header: "GD",
        formula: :carambol_str
      }
    },
    "Snooker" => {
      sets: "Frames",
      hs: "HB",
      g: "G",
      v: "V",
      t_ids: "t_ids"
    },
    "5-Pin Billards" => {
      points: "Partiepunkte",
      sets: "Satzpunkte",
      balls: "Kegel",
      btg: "GD",
      t_ids: "t_ids"
    }
  }.freeze

  GAME_PARAMETERS = {
    "14/1e" => {
      "Punkteziel" => ["score", [30, 40, 50, 65, 75, 100, 125, 150, 200], 125, "score"],
      "Aufnahmelimit" => ["innings", [0, 20, 25, 30], 0],
      "Erster Anstoß" => ["first_break", %w[Ausstoßen Heimspieler Gastspieler], "Ausstoßen"]
    },
    "8-Ball" => {
      "Anstoß" => ["next_break", %w[Wechsel Winner], "Wechsel"],
      "Gewinnspiele" => ["sets", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 8, "sets"],
      "Erster Anstoß" => ["first_break", %w[Ausstoßen Heimspieler Gastspieler], "Ausstoßen"]
    },
    "9-Ball" => {
      "Anstoß" => ["next_break", %w[Wechsel Winner], "Wechsel"],
      "Gewinnspiele" => ["sets", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 8, "sets"],
      "Erster Anstoß" => ["first_break", %w[Ausstoßen Heimspieler Gastspieler], "Ausstoßen"]
    },
    "9-Ball Doppel" => {
      "Anstoß" => ["next_break", %w[Wechsel Winner], "Wechsel"],
      "Gewinnspiele" => ["sets", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 8, "sets"],
      "Erster Anstoß" => ["first_break", %w[Ausstoßen Heimspieler Gastspieler], "Ausstoßen"]
    },
    "10-Ball" => {
      "Anstoß" => ["next_break", %w[Wechsel Winner], "Wechsel"],
      "Gewinnspiele" => ["sets", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 8, "sets"],
      "Erster Anstoß" => ["first_break", %w[Ausstoßen Heimspieler Gastspieler], "Ausstoßen"]
    },
    "10-Ball Doppel" => {
      "Anstoß" => ["next_break", %w[Wechsel Winner], "Wechsel"],
      "Gewinnspiele" => ["sets", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 8, "sets"],
      "Erster Anstoß" => ["first_break", %w[Ausstoßen Heimspieler Gastspieler], "Ausstoßen"]
    },
    "Shootout (4er Team)" => {}
  }.freeze

  def carambol_str(_player_ranking, opts = {})
    if opts[:v1].present? && opts[:v2].present? && opts[:v2].to_i.positive?
      format("%.2f", (opts[:v1].to_f / opts[:v2]))
    else
      ""
    end
  end

  def class_from_accumulated_result(player_ranking)
    case root.name
    when "Carambol"
      class_from_val(player_ranking.btg.to_f)
    else
      ""
    end
  end

  def class_from_val(val)
    DISCIPLINE_CLASS_LIMITS[name].to_a.each do |k, v|
      return k if val > Array(v)[0]
    end
    ""
  end

  def merge_disciplines(with_discipline_ids = [], opts = {})
    Discipline.transaction do
      if opts[:force_merge] ||
         (Discipline.where(id: with_discipline_ids).map(&:name)
                    .sort + synonyms.split("\n"))
         .uniq.compact.sort == synonyms.split("\n").uniq.compact.sort
        Rails.logger.info("REPORT merging disciplines (#{name}[#{id}] with #{
          Array(with_discipline_ids).map do |idx|
            "#{Discipline[idx].name} [#{idx}]"
          end
        })")
        update(synonyms:
                 (Discipline.where(id: with_discipline_ids).map(&:name) +
                   Array(synonyms.andand.split("\n")))
                   .uniq.join("\n"))
        DisciplineTournamentPlan.where(discipline_id: with_discipline_ids).all.each do |dtb|
          dtb.update(discipline_id: id)
        end
        Tournament.where(discipline_id: with_discipline_ids).all.each do |l|
          l.update(discipline_id: id)
        end
        PlayerClass.where(discipline_id: with_discipline_ids).all.each do |l|
          l.update(discipline_id: id)
        end
        PlayerRanking.where(discipline_id: with_discipline_ids).all.each { |l| l.update(discipline_id: id) }
        League.where(discipline_id: with_discipline_ids).all.each { |l| l.update(discipline_id: id) }
        GamePlanCc.where(discipline_id: with_discipline_ids).all.each { |l| l.update(discipline_id: id) }
        GamePlanRowCc.where(discipline_id: with_discipline_ids).all.each { |l| l.update(discipline_id: id) }
        Seeding.where(playing_discipline_id: with_discipline_ids).all.each { |l| l.update(playing_discipline_id: id) }
        Discipline.where(super_discipline_id: with_discipline_ids).all.each { |l| l.update(super_discipline_id: id) }
        Discipline.where(id: with_discipline_ids).destroy_all

      else
        arr = Array(with_discipline_ids).map do |idx|
          "#{Discipline[idx].name} [#{idx}]"
        end
        Rails.logger.info "===== scrape ===== ERROR cannot merge automatically " \
                            "- too different - check manually merge disciplines #{name}[#{id}] with #{arr}"
      end
    end
    reload
  end

  def root
    @root ||= super_discipline.blank? ? self : super_discipline.root
  end
end
