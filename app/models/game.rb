class Game < ActiveRecord::Base
  belongs_to :tournament
  has_many :game_participations
  has_one :table_monitor

  serialize :remarks, Hash

  COLUMN_NAMES = {
      "Date" => "tournaments.date",
      "Tournament" => "tournaments.title",
      "Remarks" => "games.remarks",
  }

  def self.fix_participation(game)
    mapping = {"Gr." => :gname, "Ergebnis" => :result, "Aufnahme" => :innings, "HS" => :hs, "GD" => :gd, "Punkte" => :points}
    tournament = game.tournament
    if tournament.present?
      game.game_participations.delete_all
      player_a = Player.joins(:seedings => :tournament).where(tournaments: {id: tournament.id}).
          where("players.lastname||', '||players.firstname = :name", name: game.remarks["Heim"]).first
      gp_a = GameParticipation.create(game_id: game.id, player_id: player_a.id, role: "Heim") if player_a.present?
      player_b = Player.joins(:seedings => :tournament).where(tournaments: {id: tournament.id}).
          where("players.lastname||', '||players.firstname = :name", name: game.remarks["Gast"]).first
      gp_b = GameParticipation.create(game_id: game.id, player_id: player_b.id, role: "Gast") if player_b.present?
      gp_a_results = {}
      gp_b_results = {}
      game.remarks.each do |k, v|
        if v =~ /:/
          heim, gast = v.split(":").map(&:strip).map { |str| (str =~ /,/) ? str.gsub(",", ".").to_f : str.to_i }
          gp_a_results[k] = heim
          gp_b_results[k] = gast
        elsif k == "Gr."
          gp_a_results[k] = v
          gp_b_results[k] = v
        end
      end
      if gp_a.present?
        remarks_a = gp_a.andand.remarks || {}
        remarks_a["results"] = gp_a_results
        attrs = {}
        attrs = attrs.merge(Hash[gp_a.remarks["results"].map { |k, v| [mapping[k], v] }].symbolize_keys) if gp_a.remarks["results"].present?
        attrs = attrs.merge(remarks: remarks_a)
        gp_a.update_attributes(attrs)
      end
      if gp_b.present?
        remarks_b = gp_b.andand.remarks || {}
        remarks_b["results"] = gp_b_results
        attrs = {}
        attrs = attrs.merge(Hash[gp_b.remarks["results"].map { |k, v| [mapping[k], v] }].symbolize_keys) if gp_b.remarks["results"].present?
        attrs = attrs.merge(remarks: remarks_b)
        gp_b.update_attributes(attrs)
      end
    else
      game.destroy
    end
  end
end
