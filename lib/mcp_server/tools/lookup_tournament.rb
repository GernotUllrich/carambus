# frozen_string_literal: true

# cc_lookup_tournament — DB-first Tournament lookup via TournamentCc mirror (D-02); live showMeisterschaft fallback.

module McpServer
  module Tools
    class LookupTournament < BaseTool
      tool_name "cc_lookup_tournament"
      description "Wann nutzen? Sportwart/Turnierleiter fragt nach Details zu einem Turnier — Status, Meldeschluss, bereits angemeldete Spieler — ODER ein anderes Tool braucht eine meldeliste_cc_id, die nur über den Turniernamen bekannt ist. " \
                  "Was tippt der User typisch? 'Status Eurokegel?', 'Wann ist Meldeschluss NDM Endrunde?', 'Wie viele Spieler sind angemeldet?', 'Details zur DM Cadre'. " \
                  "Look up a ClubCloud tournament by CC meisterschaft ID or Carambus tournament ID. " \
                  "Queries the local Carambus DB (TournamentCc mirror) by default; pass force_refresh=true for live CC. " \
                  "Output enthält Detail-Felder (location_text, tournament_start, tournament_end, accredation_end). " \
                  "Mit `with_committed_list:true` wird zusätzlich showCommittedMeldeliste live abgefragt und " \
                  "die bereits angemeldeten Player-cc_ids aus dem HTML extrahiert (read-only). " \
                  "Konversations-UX: Vor JEDER Neuanmeldung die Liste der bereits angemeldeten Spieler kurz " \
                  "aufzählen — der TM erkennt so Doppelanmeldungen vor dem register-Tool. Tool ist DB-first; " \
                  "bei Detail-Lücken (fehlende location_text, fehlender tournament_start) `force_refresh:true` " \
                  "empfehlen — der CC-Sync ist max ~2h alt, aber Detail-Felder sind nicht immer komplett " \
                  "in den TournamentCc-Mirror gespiegelt. " \
                  "Region-Filter (Plan 10-05 Befund #3): meisterschaft_id (cc_id) ist nur regions-eindeutig; " \
                  "Tool filtert per default nach Region (CC_REGION/Setting 'context'). Optional `shortname` " \
                  "überschreibt die Default-Region (z.B. 'BVBW' für Multi-Region-Lookups). Bei 0 Treffern " \
                  "in der Region wird ein Fallback-Output mit Cross-Region-Kandidaten geliefert."
      input_schema(
        properties: {
          meisterschaft_id: {type: "integer", description: "CC meisterschaft ID (cc_id on TournamentCc) — nur regions-eindeutig"},
          cc_id: {type: "integer", description: "Plan 14-02.3 / F-4: Alias für meisterschaft_id (User-Vokabular). Wenn beide gesetzt, gewinnt meisterschaft_id."},
          tournament_id: {type: "integer", description: "Carambus-internal Tournament ID (region-eindeutig)"},
          name: {type: "string", description: "Optionaler Name-Search-Filter (Substring auf TournamentCc.name via ILIKE; Plan 10-06 D-10-04-J Vokabular-Schicht). Liefert Disambiguation-Output (0/1/≥2-Treffer) analog cc_lookup_club."},
          fed_id: {type: "integer", description: "Deprecated — Backwards-Compat; wird aus User#cc_region abgeleitet."},
          shortname: {type: "string", description: "Optionaler Region-Filter-Override. Strict-Mode aus 14-02.1-fix: Override ungleich User#cc_region wird mit Warning ignoriert. Removal in 14-02.4."},
          season: {type: "string", description: "Season-Name (z.B. '2025/2026'). Plan 14-02.3 / F-7: Default = aktuelle Saison."},
          force_refresh: {type: "boolean", default: false, description: "Bypass DB cache, query CC live"},
          with_committed_list: {type: "boolean", default: false, description: "Wenn true, ruft showCommittedMeldeliste auf und liefert die bereits angemeldeten Player-cc_ids als 'committed_players' (read-only). meldeliste_cc_id wird aus TournamentCc.registration_list_cc abgeleitet — falls nicht in DB verknüpft, kann optional `meldeliste_cc_id` als Override gesetzt werden."},
          meldeliste_cc_id: {type: "integer", description: "Override für with_committed_list — nur nötig wenn TournamentCc keine registration_list_cc-Beziehung hat. Sonst wird der Wert aus der DB-Beziehung gelesen."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(meisterschaft_id: nil, cc_id: nil, tournament_id: nil, name: nil, fed_id: nil, shortname: nil, season: nil, force_refresh: false, with_committed_list: false, meldeliste_cc_id: nil, server_context: nil)
        # Plan 14-02.3 / F-4: cc_id-Alias-Aufnahme. meisterschaft_id hat Präzedenz wenn beide gesetzt.
        meisterschaft_id ||= cc_id
        fed_id ||= default_fed_id(server_context)
        unless meisterschaft_id.present? || tournament_id.present? || name.present?
          return error("Bitte gib `meisterschaft_id` (oder Alias `cc_id`), `tournament_id` oder `name` an.")
        end

        return live_lookup(meisterschaft_id: meisterschaft_id, fed_id: fed_id, season: season, server_context: server_context) if force_refresh

        # Plan 10-06 Task 1 (D-10-04-J Vokabular-Schicht): Name-Search via TournamentCc.name ILIKE
        # mit Phase-8-Disambiguation-Pattern (5. Anwendung). Vorbild: cc_lookup_club aus Plan 10-05.
        # Plan 14-02.3 / F-7: Season-Filter via effective_season; bei TournamentCc.season=null
        # NULL-tolerant (data-quality-bug — siehe v0.4-Backlog).
        if name.present? && meisterschaft_id.blank? && tournament_id.blank?
          return name_search(name: name, shortname: shortname, season: season, server_context: server_context)
        end

        # Plan 14-02.1-fix / D-14-02-G: strict User-Context. shortname-Override-Logik entfernt
        # (Removal aus Schema folgt in 14-02.4). Direkter effective_cc_region(server_context)-
        # Zugriff; nil → klarer Profile-Edit-Hinweis-Error statt silent-Fallback.
        if meisterschaft_id.present?
          region_shortname = effective_cc_region(server_context)
          if region_shortname.blank?
            return scenario_config_missing_error
          end
          tournament_cc = resolve_tournament_cc(
            cc_id: meisterschaft_id,
            server_context: server_context
          )

          if tournament_cc.nil?
            return error(
              "Turnier-cc_id=#{meisterschaft_id} nicht in deiner Region '#{region_shortname}' gefunden. " \
              "Prüfe: (a) ist die meisterschaft_id korrekt? (b) liegt es in einer anderen Region — Cross-Region-Lookup " \
              "wird in v0.3.1+ nicht unterstützt (Single-Region-User-Profile)."
            )
          end
        else
          tournament_cc = TournamentCc.find_by(tournament_id: tournament_id)
        end

        return error("Tournament not found in Carambus DB. Try force_refresh: true to query CC.") if tournament_cc.nil?

        text(format_tournament_cc(tournament_cc, with_committed_list: with_committed_list, meldeliste_cc_id_override: meldeliste_cc_id, fed_id: fed_id))
      end

      # Plan 14-02.1-fix / D-14-02-G: Name-Search strict auf User-Region; shortname-Override-
      # Logik entfernt (Removal aus Schema folgt in 14-02.4). Pattern aus Plan 10-06 erhalten
      # (Phase-8-Disambiguation, 5. Anwendung).
      # Plan 14-02.3 / F-7: Season-Default-Filter (current_season; NULL-tolerant für
      # TournamentCc.season=null data-quality-bug).
      # Plan 14-02.3 / B-3: shortname-Override-Warning analog 14-02.2 Pattern.
      def self.name_search(name:, shortname:, season: nil, server_context: nil)
        region_shortname = effective_cc_region(server_context)
        if region_shortname.blank?
          return scenario_config_missing_error
        end
        if shortname.present? && shortname.to_s.upcase != region_shortname
          Rails.logger.warn "[cc_lookup_tournament] shortname-Override '#{shortname}' ignoriert; nutze User#cc_region='#{region_shortname}'"
        end

        season_obj = effective_season(server_context, override: season)

        escaped = ActiveRecord::Base.sanitize_sql_like(name.to_s)
        scope = TournamentCc.where("name ILIKE ?", "%#{escaped}%")
          .where(context: region_shortname.to_s.downcase)
        # Plan 14-02.3 / F-7: NULL-tolerant Season-Filter. TournamentCc.season ist String;
        # NULL-Records passieren tolerant durch (data-quality-bug — v0.4-Backlog).
        scope = scope.where("season = ? OR season IS NULL", season_obj.name) if season_obj
        matches = scope.order(:name).limit(20)

        candidates = matches.map { |tc|
          {
            cc_id: tc.cc_id,
            tournament_id: tc.tournament_id,
            name: tc.name,
            context: tc.context,
            season: tc.season
          }
        }

        if candidates.empty?
          return error(
            "Kein Turnier in Region '#{region_shortname}' (Saison '#{season_obj&.name || "—"}') passt zu '#{name}'. " \
            "Versuche: (a) kürzerer Suchbegriff (z.B. 'Eurokegel' statt 'NDM Endrunde Eurokegel'), " \
            "(b) andere Saison via season-Parameter, " \
            "(c) tournament_id falls bekannt (Carambus-Rails-id)."
          )
        end

        body = {
          cc_id: (candidates.length == 1) ? candidates.first[:cc_id] : nil,
          tournament_id: (candidates.length == 1) ? candidates.first[:tournament_id] : nil,
          candidates: candidates,
          meta: {
            count: candidates.length,
            region: region_shortname,
            season: season_obj&.name,
            search: {name: name}
          }
        }
        body[:warning] = "#{candidates.length} Treffer gefunden — bitte Sportwart-Rückfrage: welches Turnier?" if candidates.length > 1
        text(JSON.generate(body))
      end

      def self.live_lookup(meisterschaft_id:, fed_id:, season:, server_context: nil)
        return error("Missing meisterschaft_id for live lookup") if meisterschaft_id.blank?
        return error("Missing fed_id for live lookup") if fed_id.blank?
        client = cc_session.client_for(server_context)
        params = {fedId: fed_id, meisterschaftId: meisterschaft_id}
        params[:season] = season if season.present?
        res, _doc = client.get("showMeisterschaft", params, {session_id: cc_session.cookie})
        return error("CC live-lookup failed: HTTP #{res&.code}") if res&.code != "200"
        text("CC live response for showMeisterschaft (meisterschaft_id=#{meisterschaft_id}, status #{res.code})")
      end

      def self.format_tournament_cc(tournament_cc, with_committed_list: false, meldeliste_cc_id_override: nil, fed_id: nil)
        tournament = tournament_cc.tournament
        meta = {}

        payload = {
          id: tournament_cc.id,
          cc_id: tournament_cc.cc_id,
          name: tournament_cc.name,
          status: tournament_cc.status,
          season: tournament_cc.season,
          tournament_id: tournament_cc.tournament_id,
          context: tournament_cc.context,
          location_text: tournament_cc.location_text,
          tournament_start: tournament_cc.tournament_start&.iso8601,
          tournament_end: tournament_cc.tournament_end&.iso8601,
          accredation_end: tournament&.accredation_end&.iso8601
        }

        if with_committed_list
          committed = read_committed_players(
            tournament_cc: tournament_cc,
            meldeliste_cc_id_override: meldeliste_cc_id_override,
            fed_id: fed_id,
            meta: meta
          )
          payload[:committed_players] = committed
        end

        payload[:meta] = meta unless meta.empty?
        JSON.generate(payload)
      end

      # Liest bereits-angemeldete Player-cc_ids via showCommittedMeldeliste.
      # Defensives Pattern (analog Phase-2 force_refresh): Sync-/Parse-Fehler erzeugen
      # nil + meta-Warnung statt Exception. meldeliste_cc_id-Auflösung primär aus
      # tournament_cc.registration_list_cc; Override-Param erlaubt Fallback.
      def self.read_committed_players(tournament_cc:, meldeliste_cc_id_override:, fed_id:, meta:)
        meldeliste_cc_id = meldeliste_cc_id_override.presence || tournament_cc.registration_list_cc&.cc_id
        if meldeliste_cc_id.blank?
          # Plan 14-02.3 / F-6: Sportwart-Vokabular.
          meta[:committed_list_warning] = "Daten-Lücke: Das Turnier ist in Carambus, aber die Meldeliste-Verknüpfung fehlt. Bitte LSW informieren — oder meldeliste_cc_id direkt setzen (Override-Parameter)."
          return nil
        end

        # 8-Felder-Payload analog Phase-5-D3-Bugfix in cc_register_for_tournament.
        # branchId aus tournament_cc.branch_cc.cc_id; clubId/disciplinId/catId als
        # Wildcards (CC akzeptiert "*" in show-Pfaden — analog register-Tool).
        branch_id = tournament_cc.branch_cc&.cc_id
        payload = {
          clubId: "*",
          fedId: fed_id,
          branchId: branch_id || "*",
          disciplinId: "*",
          catId: "*",
          season: tournament_cc.season,
          meldelisteId: meldeliste_cc_id,
          sortOrder: "player"
        }

        client = cc_session.client_for(server_context)
        res, _doc = client.post("showCommittedMeldeliste", payload, {session_id: cc_session.cookie})

        if res.nil? || res.code != "200"
          meta[:committed_list_warning] = "showCommittedMeldeliste returned HTTP #{res&.code || "nil"} — committed_players unavailable."
          return nil
        end

        # Player-cc_id-Marker analog SNIFF v2 A2: <td align="center">{cc_id}</td>
        cc_ids = res.body.to_s.scan(%r{<td align="center">(\d+)</td>}).flatten.map(&:to_i).uniq
        cc_ids.map { |cc_id| {cc_id: cc_id} }
      rescue => e
        Rails.logger.warn "[cc_lookup_tournament] read_committed_players failed: #{e.class}: #{e.message}"
        meta[:committed_list_warning] = "Exception while reading committed list: #{e.class.name} (defensive — see Rails.logger)."
        nil
      end
    end
  end
end
