# frozen_string_literal: true

module McpServer
  # TEMPORARY STUB (Plan 14-G.1 / D-14-G6):
  # User#mcp_role-Enum wurde entfernt; Authority-Layer-Refactor (Sportwart-Wirkbereich + TL-FK +
  # Carambus.config.region_id) folgt in Plan 14-G.2.
  #
  # Aktuelles Verhalten: jeder authentifizierte User bekommt das volle Tool-Subset
  # ("all-authenticated-tools"). Der eigentliche Authority-Check wandert in 14-G.2
  # in den McpController bzw. in BaseTool#authorize!.
  #
  # Frozen-Array-Pattern aus Phase-13 bleibt erhalten — nur das Mapping ist degeneriert
  # auf eine einzige „all"-Liste.
  module RoleToolMap
    # Read-only Tools
    BASE_READ_TOOLS = %i[
      LookupRegion
      LookupClub
      LookupLeague
      LookupCategory
      LookupSerie
      LookupTeam
      LookupTournament
      LookupSpielbericht
      LookupMeldelisteForTournament
      LookupTeilnehmerliste
      ListClubsByDiscipline
      ListPlayersByClubAndDiscipline
      ListPlayersByName
      ListOpenTournaments
      SearchPlayer
      CheckPlayerDisciplineExperience
    ].freeze

    # Write-Tools (Sportwart + Turnierleiter zusammen — 14-G.2 trennt das wieder authority-basiert)
    WRITE_TOOLS = %i[
      RegisterForTournament
      UpdateTournamentDeadline
      UnregisterForTournament
      AssignPlayerToTeilnehmerliste
      RemoveFromTeilnehmerliste
      FinalizeTeilnehmerliste
    ].freeze

    # All-Tools (Stub-Inhalt für jeden authentifizierten User)
    ALL_TOOLS = (BASE_READ_TOOLS + WRITE_TOOLS).uniq.freeze
  end
end
