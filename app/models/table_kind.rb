# == Schema Information
#
# Table name: table_kinds
#
#  id         :bigint           not null, primary key
#  measures   :text
#  name       :string
#  short      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class TableKind < ApplicationRecord
  has_many :disciplines
  has_many :tables

  COLUMN_NAMES = {
      "Name" => "table_kinds.name",
      "Short" => "table_kinds.shortname",
      "Measures" => "table_kinds.measures",
  }
end
