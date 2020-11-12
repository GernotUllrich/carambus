class TableKind < ActiveRecord::Base
  has_many :disciplines
  has_many :tables

  COLUMN_NAMES = {
      "Name" => "table_kinds.name",
      "Short" => "table_kinds.shortname",
      "Measures" => "table_kinds.measures",
  }
end
