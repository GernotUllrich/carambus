# frozen_string_literal: true

module ExternalTournament
  # Die Spiel-Suche fuer App-getriebene Turniere — geteilt von AcknowledgeResultProcessor
  # und CancelGameProcessor.
  #
  # Warum eigens: App-Games sind NUR ueber den gebundenen TableMonitor mit dem Turnier
  # verknuepft (GameSetup#create_new_game setzt KEIN tournament_id/tournament_type, nur
  # tm.game_id). Ein `tournament.games.find_by(...)` findet sie deshalb nicht. Die
  # Zuordnung haengt allein an der external_id, nicht am Tisch — wer das nachbaut statt
  # wiederzuverwenden, bricht diese Invariante beim naechsten Sonderfall.
  #
  # Phase 28-01: aus AcknowledgeResultProcessor herausgezogen, verhaltensgleich.
  module AppGameLookup
    # Sucht ueber die an den TournamentMonitor gebundenen TableMonitors: aktuelles Spiel
    # (tm.game) + ggf. das vorige (tm.prev_game_id, nach Rematch/Swap im PartyMonitor-Pfad).
    def find_game(tournament, external_id)
      owner = tournament.tournament_monitor
      return nil if owner.blank?
      bound = TableMonitor.where(tournament_monitor_id: owner.id, tournament_monitor_type: "TournamentMonitor")
      bound.each do |tm|
        g = tm.game
        return g if g.present? && lookup_safe_data(g)["external_id"].to_s == external_id
        if tm.prev_game_id.present?
          pg = Game.find_by(id: tm.prev_game_id)
          return pg if pg.present? && lookup_safe_data(pg)["external_id"].to_s == external_id
        end
      end
      nil
    end

    # Eigener Name statt `safe_data`: Im Verzeichnis existieren fuenf gleichnamige private
    # Helfer (acknowledge_result, app_tournament_cleaner, round_result_aggregator,
    # start_game, round_start). Haette das Modul `safe_data` definiert, ueberschriebe die
    # einbindende Klasse es still — verhaltensgleich heute, aber eine Falle fuer morgen.
    def lookup_safe_data(record)
      d = record.data
      return d if d.is_a?(Hash)
      return {} if d.blank?
      JSON.parse(d.to_s)
    rescue JSON::ParserError
      {}
    end
  end
end
