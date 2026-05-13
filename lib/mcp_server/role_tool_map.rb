# frozen_string_literal: true

module McpServer
  # Statisches Mapping MCP-Rolle → Tool-Subset (D-13-01-D Option-B-Override 5-Rollen-Modell).
  # Jede Rolle bekommt ein Array von Tool-Klassen-Symbolen (entsprechen Klassennamen unter McpServer::Tools).
  # NICHT direkt aus Klassen-Constants ableiten — Mapping ist die Single-Source-of-Truth für Permissions.
  #
  # Pattern: Read-Tools in BASE_READ_TOOLS; Write-Tools per Rolle hinzugefügt.
  # Frozen-Hash + frozen-Arrays gegen versehentliche Mutation zur Laufzeit.
  module RoleToolMap
    # Read-only Tools (alle Rollen haben mindestens diese)
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

    # Sportwart-Write-Subset (Vor-Turnier-Persona)
    SPORTWART_WRITE_TOOLS = %i[
      RegisterForTournament
      UpdateTournamentDeadline
      UnregisterForTournament
    ].freeze

    # Turnierleiter-Write-Subset (Am-Turniertag-Persona)
    TURNIERLEITER_WRITE_TOOLS = %i[
      AssignPlayerToTeilnehmerliste
      RemoveFromTeilnehmerliste
      FinalizeTeilnehmerliste
      RegisterForTournament
      UnregisterForTournament
    ].freeze

    # Admin/LSW-Write-Subset (alle Write-Tools)
    ADMIN_WRITE_TOOLS = (SPORTWART_WRITE_TOOLS + TURNIERLEITER_WRITE_TOOLS).uniq.freeze

    # Vollständiges Mapping pro mcp_role-Enum-Wert (User#mcp_role-String → Tool-Subset-Array)
    MAPPING = {
      mcp_public_read: BASE_READ_TOOLS,
      mcp_sportwart: (BASE_READ_TOOLS + SPORTWART_WRITE_TOOLS).uniq.freeze,
      mcp_turnierleiter: (BASE_READ_TOOLS + TURNIERLEITER_WRITE_TOOLS).uniq.freeze,
      mcp_landessportwart: (BASE_READ_TOOLS + ADMIN_WRITE_TOOLS).uniq.freeze,
      mcp_admin: (BASE_READ_TOOLS + ADMIN_WRITE_TOOLS).uniq.freeze
    }.freeze

    # Anzahl der erwarteten Tools pro Rolle (für Test-Drift-Guard)
    EXPECTED_COUNTS = MAPPING.transform_values(&:size).freeze
  end
end
