# == Schema Information
#
# Table name: t_seedings
#
#  id                    :bigint           not null, primary key
#  ba_state              :string
#  balls_goal            :integer
#  data                  :text
#  position              :integer
#  rank                  :integer
#  state                 :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  player_id             :integer
#  playing_discipline_id :integer
#  t_tournament_id       :integer
#
# Indexes
#
#  index_t_seedings_on_foreign_keys  (player_id,t_tournament_id) UNIQUE
#
class TSeeding < ApplicationRecord
  include AASM
  aasm column: "state", skip_validation_on_save: true do
    state :registered, initial: true
    state :seeded
    state :participated
    state :no_show
  end
  belongs_to :player, optional: true
  belongs_to :t_tournament, optional: true
  belongs_to :playing_discipline, class_name: "Discipline", foreign_key: :playing_discipline_id, optional: true

  acts_as_list scope: :t_tournament

  serialize :data, Hash

  COLUMN_NAMES = {
      "Player" => "players.lastname||', '||players.firstname",
      "Tournament" => "tournaments.title",
      "Discipline" => "disciplines.name",
      "Date" => "tournaments.date",
      "Season" => "seasons.name",
      "Status" => "seeding.status",
      "Position" => "seeding.position",
      "Remarks" => "seeding.data",
  }

  def self.result_display(seeding)
    ret = []
    result = seeding.data.andand["result"]
    if result.present?
      ret << "<table>"
      lists = result.keys
      cols = nil
      if result.keys.present?
        cols = result[lists[0]].andand.keys
        if cols.present?
          i_name = cols.index("Name")
          i_verein = cols.index("Verein")
          cols = cols - %w{Name Verein}
          ret << "<tr><th></th>#{cols.map { |c| "<th>#{c}</th>" }.join("")}</tr>"
          lists.each do |list|
            values = result[list].values
            values = values.reject.with_index { |e, i| [i_name, i_verein].include? i }
            ret << "<tr><td>#{list}</td>#{values.map { |c| "<td>#{c}</td>" }.join("")}</tr>"
          end
        end
      end
      ret << "</table>"
    end
    ret.join("\n").html_safe
  end

end
