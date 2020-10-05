class Discipline < ActiveRecord::Base
  has_many :tournament_templates
  belongs_to :table_kind
  belongs_to :super_discipline, foreign_key: :super_discipline_id, :class_name => "Discipline"
  has_many :sub_disciplines, foreign_key: :super_discipline_id, :class_name => "Discipline"
  has_many :tournaments

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

  BA_MAJOR_DISCIPLINES = MAJOR_DISCIPLINES.keys - ["Carambol Match Table"]
  COLUMN_NAMES = {
      "Name" => "disciplines.name",
      "Table size" => "disciplines.table_size",
      "is a" => "sup.name",
      "Table Kind" => "table_kinds.name",
  }
end
