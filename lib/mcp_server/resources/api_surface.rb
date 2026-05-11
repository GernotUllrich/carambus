# frozen_string_literal: true
# ApiSurface — Exponiert den kuratierten PATH_MAP-Subset (D-04 Allowlist) als MCP-Resources
# unter cc://api/{action}. NICHT alle ~100 PATH_MAP-Entries (D-04 verbietet Auto-Mapping).
#
# Locked count: genau 25 Entries (12 Read-Lookups + 12 Write/Admin-Actions + 1 Dashboard-Root `home`).
# 25 curated entries — D-04-Boundary von Plan 07-01 explizit auf 25 angehoben (war 20 in Plan 06-03).
# Aufstockung 15→18 in Plan 04-04 (cc_register_for_tournament 2-Step-Workflow):
# +addPlayerToMeldeliste (write), +saveMeldeliste (write), +showCommittedMeldeliste (read).
# Aufstockung 18→20 in Plan 06-03 (cc_update_tournament_deadline 2-Step-Workflow):
# +editMeldelisteCheck (write), +editMeldelisteSave (write). showMeldeliste-Pre-Read
# nutzt existierenden read-only-Key (kein 3. Eintrag — siehe PATH_MAP-Reuse-Decision).
# Aufstockung 20→25 in Plan 07-03 (cc_assign_player_to_teilnehmerliste Multi-Step-Workflow):
# +assignPlayer (write), +removePlayer (write, für Plan 07-04 Inline-Patch / Phase 8),
# +editTeilnehmerlisteCheck (write), +editTeilnehmerlisteSave (write), +showTeilnehmerliste (read).
# D-04-BOUNDARY 25 ERREICHT — weitere Erweiterungen brauchen Re-Discuss (Phase 9 Cleanup vorgemerkt).
#
# WICHTIG (Revision 2026-05-07, Blockers 2+3): Plan 01's `Server.install_central_read_handler`
# besitzt den zentralen Dispatcher. Diese Klasse exponiert nur `.all` (Resource-Liste) +
# `.read(action:)` (Content-Lookup). KEIN eigener Handler-Aufruf hier — das würde mit
# Plan 02 in Wave 2 kollidieren.
#
# Sicherheit (T-40-03-02): ALLOWLIST-Whitelist verhindert, dass beliebige PATH_MAP-Keys
# exponiert werden. Plan 01's Dispatcher-Regex [\w-]+ blockt '/' und '..' auf Dispatch-Ebene.
# T-40-03-03: Manuelle ALLOWLIST mit exakt 25 Entries verhindert D-04-Verletzung (Auto-Mapping).
# D-04-Boundary auf 25 angehoben in Plan 07-01 (Decisions); Konsolidierung deferred Phase 9.

module McpServer
  module Resources
    class ApiSurface
      # 25 kuratierte Entries — gesperrt per RESEARCH §"Curated PATH_MAP Allowlist (D-04 Empfehlung)"
      # plus Aufstockung in Plan 04-04 + Plan 06-03 + Plan 07-03.
      # Aufschlüsselung:
      #   12 Read-Lookups: showLeagueList, showLeague, showMeisterschaftenList, showMeisterschaft,
      #     showMeldelistenList, showMeldeliste, showTeam, showClubList, spielbericht, suche,
      #     showCommittedMeldeliste (Plan 04-04 — Verifikations-Call nach Save),
      #     showTeilnehmerliste (Plan 07-03 — Read-only View Teilnehmerliste)
      #   12 Write/Admin: showAnnounceList, showCategory, showSerie, releaseMeldeliste,
      #     addPlayerToMeldeliste (Plan 04-04), saveMeldeliste (Plan 04-04),
      #     editMeldelisteCheck (Plan 06-03), editMeldelisteSave (Plan 06-03),
      #     assignPlayer (Plan 07-03), removePlayer (Plan 07-03 — for Plan 07-04 / Phase 8),
      #     editTeilnehmerlisteCheck (Plan 07-03), editTeilnehmerlisteSave (Plan 07-03)
      #   1 Dashboard-Root: home
      # Gesamt: 25 (D-04-Boundary aus Plan 07-01 ERREICHT — weitere Erweiterungen brauchen Re-Discuss).
      ALLOWLIST = %w[
        home
        showLeagueList
        showLeague
        showMeisterschaftenList
        showMeisterschaft
        showMeldelistenList
        showMeldeliste
        showTeam
        showClubList
        showAnnounceList
        spielbericht
        showCategory
        showSerie
        suche
        releaseMeldeliste
        addPlayerToMeldeliste
        saveMeldeliste
        showCommittedMeldeliste
        editMeldelisteCheck
        editMeldelisteSave
        assignPlayer
        removePlayer
        editTeilnehmerlisteCheck
        editTeilnehmerlisteSave
        showTeilnehmerliste
      ].freeze

      # Mapping Action → Syncer-Referenz (aus RESEARCH §"Curated PATH_MAP Allowlist" extrahiert).
      USED_BY_SYNCER = {
        "showLeagueList" => "league_syncer.rb",
        "showLeague" => "league_syncer.rb",
        "showMeisterschaftenList" => "tournament_syncer.rb",
        "showMeisterschaft" => "tournament_syncer.rb",
        "showMeldelistenList" => "registration_syncer.rb",
        "showMeldeliste" => "registration_syncer.rb",
        "showTeam" => "league_syncer.rb",
        "showClubList" => "club_syncer.rb",
        "showAnnounceList" => "club_syncer.rb",
        "spielbericht" => "party_syncer.rb",
        "showCategory" => "tournament_syncer.rb",
        "showSerie" => "tournament_syncer.rb",
        "suche" => "(cross-syncer)",
        "releaseMeldeliste" => "(none — Plan 05 Write-Tool)",
        "addPlayerToMeldeliste" => "(none — Plan 04-04 Write-Tool)",
        "saveMeldeliste" => "(none — Plan 04-04 Write-Tool)",
        "showCommittedMeldeliste" => "(none — Plan 04-04 Verifikations-Call)",
        "editMeldelisteCheck" => "(none — Plan 06-03 Write-Tool Step 1)",
        "editMeldelisteSave" => "(none — Plan 06-03 Write-Tool Step 2)",
        "assignPlayer" => "(none — Plan 07-03 Write-Tool Multi-Add)",
        "removePlayer" => "(none — Plan 07-04 Inline-Patch erfüllt D-7-8)",
        "editTeilnehmerlisteCheck" => "(none — Plan 07-03 Pre-Read + Read-Back)",
        "editTeilnehmerlisteSave" => "(none — Plan 07-03 Commit)",
        "showTeilnehmerliste" => "(none — Plan 07-03 Read-only View)"
      }.freeze

      # Mapping Action → MCP-Tool-Name (Plans 04/05, EN-benannt per D-20).
      WRAPPED_BY_TOOL = {
        "showLeagueList" => "cc_lookup_league",
        "showLeague" => "cc_lookup_league",
        "showMeisterschaftenList" => "cc_lookup_tournament",
        "showMeisterschaft" => "cc_lookup_tournament",
        "showMeldelistenList" => "cc_lookup_teilnehmerliste",
        "showMeldeliste" => "cc_lookup_teilnehmerliste",
        "showTeam" => "cc_lookup_team",
        "showClubList" => "cc_lookup_club",
        "showAnnounceList" => "cc_lookup_club",
        "spielbericht" => "cc_lookup_spielbericht",
        "showCategory" => "cc_lookup_category",
        "showSerie" => "cc_lookup_serie",
        "suche" => "cc_search_player",
        "releaseMeldeliste" => "cc_finalize_teilnehmerliste",
        "addPlayerToMeldeliste" => "cc_register_for_tournament",
        "saveMeldeliste" => "cc_register_for_tournament",
        "showCommittedMeldeliste" => "cc_register_for_tournament",
        "editMeldelisteCheck" => "cc_update_tournament_deadline",
        "editMeldelisteSave" => "cc_update_tournament_deadline",
        "assignPlayer" => "cc_assign_player_to_teilnehmerliste",
        "removePlayer" => "cc_remove_from_teilnehmerliste",  # Plan 07-04 Inline-Patch erfüllt D-7-8
        "editTeilnehmerlisteCheck" => "cc_assign_player_to_teilnehmerliste",
        "editTeilnehmerlisteSave" => "cc_assign_player_to_teilnehmerliste",
        "showTeilnehmerliste" => "cc_assign_player_to_teilnehmerliste"
      }.freeze

      # Gibt Array<MCP::Resource> mit genau 20 Entries zurück (D-04 Allowlist, gesperrt).
      # Defensiv: nil-Entries werden via .compact entfernt (sollte nie auftreten, da ALLOWLIST
      # gegen PATH_MAP verifiziert wird — aber verhindert Laufzeitfehler bei Sync-Gap).
      def self.all
        ALLOWLIST.map do |action|
          entry = RegionCc::ClubCloudClient::PATH_MAP[action]
          next nil unless entry  # Defensiv — ALLOWLIST sollte PATH_MAP exakt matchen

          MCP::Resource.new(
            uri: "cc://api/#{action}",
            name: "api-#{action}",
            title: "CC Action: #{action}",
            description: "Kuratierte CC-API-Action (D-04 Allowlist) — Pfad: #{entry[0]}, read_only: #{entry[1]}",
            mime_type: "text/markdown"
          )
        end.compact
      end

      # Wird vom zentralen Read-Handler-Dispatcher in Plan 01 aufgerufen.
      # Gibt String (Markdown-Content) zurück — wirft keine Exception.
      # MCP-Client bekommt immer einen lesbaren String zurück.
      def self.read(action:)
        return not_in_allowlist(action) unless ALLOWLIST.include?(action)

        entry = RegionCc::ClubCloudClient::PATH_MAP[action]
        return missing(action) unless entry

        path, read_only = entry
        syncer = USED_BY_SYNCER[action] || "—"
        tool_name = WRAPPED_BY_TOOL[action] || "(nur als Resource exponiert)"
        http_method = read_only ? "GET" : "POST"

        <<~MARKDOWN
          # CC Action: #{action}

          **Pfad:** `#{path}`
          **HTTP-Methode:** #{http_method}
          **Read-Only:** #{read_only}
          **Genutzt von Syncer:** #{syncer}
          **Verpackt als MCP-Tool:** `#{tool_name}`

          ## Verwendung im MCP-Server

          Diese CC-Action gehört zur **D-04 kuratierten Allowlist** (Phase 40, 15 Entries gesamt).
          Sie wird vom MCP-Server entweder als Read-Lookup-Tool (Plan 04) oder als Write-Tool
          (Plan 05, nur `releaseMeldeliste` als Proof shipped) exponiert — oder ist eine reine
          Resource ohne Tool-Wrapper.

          ## Quellen

          - PATH_MAP-Eintrag: `app/services/region_cc/club_cloud_client.rb`
          - Allowlist-Begründung: `.planning/phases/40-mcp-server-clubcloud/40-RESEARCH.md`
            (Sektion "Curated PATH_MAP Allowlist")
        MARKDOWN
      end

      # Privates Hilfsmethode: Action nicht in Allowlist (T-40-03-02 Mitigierung).
      def self.not_in_allowlist(action)
        "# CC-Action `#{action}` nicht in Allowlist\n\n" \
          "Per D-04 sind nur 15 kuratierte Actions als MCP-Resources exponiert. " \
          "Andere PATH_MAP-Einträge sind absichtlich nicht erreichbar."
      end

      # Privates Hilfsmethode: Action in Allowlist aber nicht in PATH_MAP (Konfigurationsfehler).
      def self.missing(action)
        "# CC-Action `#{action}` nicht in PATH_MAP\n\n" \
          "Allowlist-Konfigurationsfehler — Action fehlt in PATH_MAP."
      end
    end
  end
end
