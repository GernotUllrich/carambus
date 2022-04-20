# == Schema Information
#
# Table name: seedings
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
#  league_team_id        :integer
#  player_id             :integer
#  playing_discipline_id :integer
#  tournament_id         :integer
#
class Seeding < ApplicationRecord
  include AASM
  aasm column: "state", skip_validation_on_save: true do
    state :registered, initial: true
    state :seeded
    state :participated
    state :no_show
  end
  belongs_to :player, optional: true
  belongs_to :tournament, optional: true
  belongs_to :playing_discipline, class_name: "Discipline", foreign_key: :playing_discipline_id, optional: true
  belongs_to :league_team, optional:true

  after_create :loggit

  acts_as_list scope: :tournament

  serialize :data, Hash

  # data Snooker
  #   data:
  #    {"result"=>
  #      {"Gesamtrangliste"=>
  #        {"#"=>"2",
  #         "Name"=>"Kondziella, Steffen",
  #         "Verein"=>"BC Break Lübeck",
  #         "G"=>"0",
  #         "V"=>"1",
  #         "Quote"=>"0,00 %",
  #         "Punkte"=>"0",
  #         "Frames"=>"2 : 5",
  #         "HB"=>"0",
  #         "Rank"=>2}}}

  #data 8-Ball
  #   data:
  #    {"result"=>
  #      {"Gesamtrangliste"=>
  #        {"#"=>"19",
  #         "Name"=>"Albrecht, Steffen",
  #         "Verein"=>"BV Q-Pub HH",
  #         "G"=>"2",
  #         "V"=>"2",
  #         "Quote"=>"50,00 %",
  #         "Sp.G"=>"12",
  #         "Sp.V"=>"9",
  #         "Sp.Quote"=>"57,14 %",
  #         "Rank"=>19}}},

  # data Dreiband groß
  #   data:
  #    {"result"=>
  #      {"Gesamtrangliste"=>
  #        {"#"=>"2",
  #         "Name"=>"Weiß, Ferdinand",
  #         "Verein"=>"BC Wedel",
  #         "Punkte"=>"4",
  #         "Bälle"=>"44",
  #         "Aufn"=>"105",
  #         "GD"=>"0,419",
  #         "BED"=>"0,750",
  #         "HS"=>"3",
  #         "Rank"=>2}}},
  #
  MIN_ID=50000000

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

  def loggit
    Rails.logger.info "Seeding[#{id}] created."
  end

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
