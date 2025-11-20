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
  include LocalProtector
  has_many :disciplines
  has_many :tables

  TABLE_KINDS = ["Pool", "Snooker", "Small Billard", "Half Match Billard", "Match Billard"]
  TABLE_KIND_BACKGROUND = {
    "Pool" => "/bg_pool2.jpg",
    "Snooker" => "/snooker.jpg",
    "Small Billard" => "/Karambol.jpg",
    "Half Match Billard" => "/Karambol.jpg",
    "Match Billard" => "/Karambol.jpg",
    "Pin Billards" => "/Karambol.jpg",
    "Biathlon" => "/Karambol.jpg",
    "5-Pin Billards" => "/Karambol.jpg"
  }

  TABLE_KIND_FREE_GAME_SETUP = {
    "Pool" => "pool",
    "Snooker" => "snooker",
    "Small Billard" => "karambol_new",
    "Half Match Billard" => "karambol_new",
    "Match Billard" => "karambol_new",
    "Pin Billards" => "karambol_new",
    "Biathlon" => "karambol_new",
    "5-Pin Billards" => "karambol_new"
  }

  TABLE_KIND_DISCIPLINE_NAMES = {
    "Pin Billards" => [],
    "Biathlon" => [],
    "5-Pin Billards" => [],
    "Pool" => ["9-Ball", "8-Ball", "14.1 endlos", "Blackball"],
    "Small Billard" => ["Dreiband klein", "Freie Partie klein", "Einband klein", "Cadre 52/2", "Cadre 35/2",
                        "Biathlon", "Nordcup", "Petit/Grand Prix"],
    "Match Billard" => ["Dreiband groß", "Einband groß", "Freie Partie groß", "Cadre 71/2", "Cadre 47/2", "Cadre 47/1"],
    "Half Match Billard" => ["Cadre 38/2", "Cadre 57/2"]
  }

  COLUMN_NAMES = {
    "Name" => "table_kinds.name",
    "Short" => "table_kinds.shortname",
    "Measures" => "table_kinds.measures"
  }

  TABLE_KIND_ALL = TableKind.all.order(:name).to_a

  def display_name
    I18n.t("table_kind.display_name_#{name.downcase.tr(" ", "_")}")
  end
end
