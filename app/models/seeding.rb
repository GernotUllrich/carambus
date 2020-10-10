class Seeding < ActiveRecord::Base
  belongs_to :player
  belongs_to :tournament
  ["player", "tournament"]

  serialize :remarks, Hash

  COLUMN_NAMES = {
      "Player" => "players.lastname||', '||players.firstname",
      "Tournament" => "tournaments.title",
      "Discipline" => "disciplines.name",
      "Date" => "tournaments.date",
      "Season" => "seasons.name",
      "Status" => "seeding.status",
      "Position" => "seeding.position",
      "Remarks" => "seeding.remarks",
  }

  def self.result_display(seeding)
    ret = []
    result = seeding.remarks.andand["result"]
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
