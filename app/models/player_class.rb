# == Schema Information
#
# Table name: player_classes
#
#  id            :bigint           not null, primary key
#  shortname     :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  discipline_id :integer
#
class PlayerClass < ApplicationRecord
  include LocalProtector
  belongs_to :discipline

  # has_many :player_rankings
  # has_many :p_player_rankings, foreign_key: :p_player_class_id, class_name: "PlayerRanking"
  # has_many :pp_player_rankings, foreign_key: :pp_player_class_id, class_name: "PlayerRanking"
  # has_many :tournament_player_rankings, foreign_key: :tournament_player_class_id, class_name: "PlayerRanking"

  # Override-Slots fuer shared/_scaffold_index: eine PlayerClass ist "Klasse N innerhalb einer Disziplin".
  # Die blosse shortname-Nummer als Titel wirkt duplikat-artig -> Disziplin als Titel, Klasse als Subzeile.
  def scaffold_row_label
    discipline&.name.presence || "Klasse #{shortname}"
  end

  def scaffold_row_subtitle
    "Klasse #{shortname}" if shortname.present?
  end
end
