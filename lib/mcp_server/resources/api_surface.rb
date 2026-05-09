# frozen_string_literal: true
# ApiSurface — Exponiert den kuratierten PATH_MAP-Subset (D-04 Allowlist) als MCP-Resources
# unter cc://api/{action}. NICHT alle ~100 PATH_MAP-Entries (D-04 verbietet Auto-Mapping).
#
# Locked count: genau 18 Entries (11 Read-Lookups + 6 Write/Admin-Actions + 1 Dashboard-Root `home`).
# 18 curated entries innerhalb der D-04-Erlaubnis von 10-20 Actions.
# Aufstockung 15→18 in Plan 04-04 (cc_register_for_tournament 2-Step-Workflow):
# +addPlayerToMeldeliste (write), +saveMeldeliste (write), +showCommittedMeldeliste (read).
#
# WICHTIG (Revision 2026-05-07, Blockers 2+3): Plan 01's `Server.install_central_read_handler`
# besitzt den zentralen Dispatcher. Diese Klasse exponiert nur `.all` (Resource-Liste) +
# `.read(action:)` (Content-Lookup). KEIN eigener Handler-Aufruf hier — das würde mit
# Plan 02 in Wave 2 kollidieren.
#
# Sicherheit (T-40-03-02): ALLOWLIST-Whitelist verhindert, dass beliebige PATH_MAP-Keys
# exponiert werden. Plan 01's Dispatcher-Regex [\w-]+ blockt '/' und '..' auf Dispatch-Ebene.
# T-40-03-03: Manuelle ALLOWLIST mit exakt 18 Entries verhindert D-04-Verletzung (Auto-Mapping).

module McpServer
  module Resources
    class ApiSurface
      # 18 kuratierte Entries — gesperrt per RESEARCH §"Curated PATH_MAP Allowlist (D-04 Empfehlung)"
      # plus Aufstockung in Plan 04-04 (cc_register_for_tournament 2-Step-Workflow).
      # Aufschlüsselung:
      #   11 Read-Lookups: showLeagueList, showLeague, showMeisterschaftenList, showMeisterschaft,
      #     showMeldelistenList, showMeldeliste, showTeam, showClubList, spielbericht, suche,
      #     showCommittedMeldeliste (Plan 04-04 — Verifikations-Call nach Save)
      #   6 Write/Admin: showAnnounceList, showCategory, showSerie, releaseMeldeliste,
      #     addPlayerToMeldeliste (Plan 04-04), saveMeldeliste (Plan 04-04)
      #   1 Dashboard-Root: home
      # Gesamt: 18 (innerhalb D-04 Bereich 10-20).
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
        "showCommittedMeldeliste" => "(none — Plan 04-04 Verifikations-Call)"
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
        "showCommittedMeldeliste" => "cc_register_for_tournament"
      }.freeze

      # Gibt Array<MCP::Resource> mit genau 18 Entries zurück (D-04 Allowlist, gesperrt).
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
