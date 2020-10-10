class TableKind < ActiveRecord::Base
  has_many :disciplines

  COLUMN_NAMES = {
      "Name" => "table_kinds.name",
      "Short" => "table_kinds.shortname",
      "Measures" => "table_kinds.measures",
  }
end
