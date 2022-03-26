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

  TABLE_KINDS = ["Pool", "Snooker", "Small Billard", "Half Match Billard", "Match Billard"]

  TABLE_KIND_DISCIPLINE_NAMES = {
    "Pin Billards" => [],
    "Biathlon" => [],
    "5-Pin Billards" => [],
    "Pool" => ["9-Ball", "8-Ball", "14.1 endlos", "Blackball"],
    "Small Billard" => ["Dreiband klein", "Freie Partie klein", "Einband klein", "Cadre 52/2", "Cadre 35/2", "Biathlon", "Nordcup", "Petit/Grand Prix"],
    "Match Billard" => ["Dreiband groß", "Einband groß", "Freie Partie groß", "Cadre 71/2", "Cadre 47/2", "Cadre 47/1"],
    "Half Match Billard" => ["Cadre 38/2", "Cadre 57/2"] }

  COLUMN_NAMES = {
      "Name" => "table_kinds.name",
      "Short" => "table_kinds.shortname",
      "Measures" => "table_kinds.measures",
  }

  def display_name
    I18n.t("table_kind.display_name_#{name.downcase.gsub(" ", "_")}")
  end
end
