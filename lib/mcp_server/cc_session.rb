# frozen_string_literal: true

# CcSession — Wraps RegionCc::ClubCloudClient mit in-memory PHPSESSID-Cache (D-10) +
# Lazy-Login + 30-min TTL + Mock-Mode-Failsafe (D-08) + transparentem Reauth bei Session-Ablauf.
#
# Real CC login wird an den existierenden kanonischen Flow in `Setting.login_to_cc`
# delegiert (extend-before-build per CLAUDE.md skill). Phase 40 rollt KEIN eigenes
# Net::HTTP::Post gegen /login.php — siehe revision 2026-05-07 Blocker 4.
#
# Single-threaded by design (MCP stdio ist one-request-at-a-time per SDK README;
# siehe RESEARCH Open Questions §2 RESOLVED — kein Mutex nötig im stdio mode).

module McpServer
  class CcSession
    TTL_SECONDS = 30 * 60
    MOCK_FLAG = "CARAMBUS_MCP_MOCK"

    # Plan 24-01 T2 (Phase-23-Nachzieher): Auto-Logout-Stub-Detection für expired
    # PHPSESSID. CC liefert in diesem Fall HTTP 200 mit `<body onLoad='goOut()'>` +
    # Auto-Submit-Form nach `phpUtilities/sessionLogout/index2.php` — bisher als
    # Empty-Response interpretiert (stillschweigend 0 Treffer). Regex deckt beide
    # Marker ab; Live-Capture als Fixture in test/fixtures/cc/auto_logout_stub.html.
    AUTO_LOGOUT_REGEX = %r{<body[^>]*onLoad=['"]?goOut\(\)|sessionLogout/index2\.php}i

    # Plan 24-01 T2: strukturierter Fehler, wenn das with_session_recovery-Single-Retry
    # nicht greift (Login-Trigger fail ODER zweite Response erneut Auto-Logout-Stub).
    # Tools fangen das und liefern eine klare Error-Message statt „0 Treffer".
    class SessionRecoveryFailed < StandardError; end

    class << self
      attr_accessor :session_id, :session_started_at, :_client_override

      # Returns either a real RegionCc::ClubCloudClient or a McpServer::Tools::MockClient.
      # Failsafe: gibt niemals Mock in Production zurück (D-08).
      #
      # v0.3 Plan 13-04.1 (D-13-04-A teilweise): server_context-aware region_cc.base_url-Routing.
      # server_context[:cc_region] (HTTP-Pfad) → region.region_cc.base_url; Stdio-Pfad bleibt ENV/Setting-basiert.
      #
      # v0.3-Pilot-Boundary: Login-Flow (Setting.login_to_cc, private #login!) ist NICHT refactored —
      # single Carambus-Admin-Account global; HTTP-User mit Cross-Region cc_region nutzen ihre
      # region.region_cc.base_url ABER mit dem global-admin session_id. Per-Region-Login +
      # Per-User-CC-Credentials sind Plan 13-04.2 (D-13-04-A vollständig).
      def client_for(server_context = nil)
        if mock_mode?
          raise "Mock mode not allowed in production" if Rails.env.production?
          return McpServer::Tools::MockClient.new
        end

        return _client_override if _client_override

        # Prio: region_cc.base_url (admin-Subdomain pro Region) > Carambus.config.cc_base_url > Fallback.
        # Plan-04-04 Live-Bugfix: ohne region_cc.base_url wurden Tool-POSTs gegen
        # www.club-cloud.de geroutet → 404, obwohl Login gegen die richtige Admin-Subdomain
        # ging (Setting.login_to_cc nutzt region_cc.base_url + "/index.php").
        base_url = region_cc_base_url(server_context) || Carambus.config.cc_base_url || "https://www.club-cloud.de"
        # ENV-Vars sind optional — der echte Login läuft über Setting.login_to_cc
        # (Rails Credentials), das ENV CC_USERNAME/CC_PASSWORD ohnehin ignoriert.
        # Konstruktor akzeptiert nil; Live-Login wird in #login! über Setting.login_to_cc geholt.
        username = ENV["CC_USERNAME"].presence
        password = ENV["CC_PASSWORD"].presence
        RegionCc::ClubCloudClient.new(base_url: base_url, username: username, userpw: password)
      end

      # Liest die admin-Subdomain für die aktuelle Region (analog Setting.login_to_cc).
      # v0.3 Plan 13-04.1 (D-13-04-A teilweise): server_context-aware via BaseTool.effective_cc_region.
      # Fallback-Chain: server_context[:cc_region] → ENV["CC_REGION"] → Setting.context → "NBV"-Default.
      # Liefert nil bei jedem Lookup-Fehler — Caller fällt dann auf Carambus.config zurück.
      def region_cc_base_url(server_context = nil)
        shortname = McpServer::Tools::BaseTool.effective_cc_region(server_context)
        region = Region.find_by(shortname: shortname)
        region&.region_cc&.base_url.presence
      rescue
        nil
      end

      # Lazy-Login: gibt eine aktive PHPSESSID zurück, loggt ein wenn Cache leer/abgelaufen.
      def cookie
        if session_id.nil? || cookie_expired?(session_started_at)
          login!
        end
        session_id
      end

      def cookie_expired?(started_at)
        return true if started_at.nil?
        Time.now - started_at > TTL_SECONDS
      end

      def reset!
        self.session_id = nil
        self.session_started_at = nil
      end

      def mock_mode?
        ENV[MOCK_FLAG] == "1"
      end

      # PUBLIC — Tools rufen dies nach jeder CC-Response auf, um Login-Redirect zu erkennen (Pitfall 4 — D-10).
      # Gibt true zurück wenn Reauth stattgefunden hat; Tool soll seinen Call dann wiederholen.
      def reauth_if_needed!(doc)
        return false unless login_redirect?(doc)
        reset!
        cookie  # erzwingt login!
        true
      end

      # Plan 24-01 T2 (Phase-23-Nachzieher): erkennt das CC-Auto-Logout-Stub-HTML,
      # das bei expired PHPSESSID statt der erwarteten Response geliefert wird.
      # Akzeptiert String (raw body), Net::HTTPResponse-like Object (.body), oder
      # Nokogiri-Doc (.to_html). Defensiv: false bei nil/blank/non-matching.
      def session_expired?(response_or_body_or_doc)
        body = case response_or_body_or_doc
        when nil then return false
        when String then response_or_body_or_doc
        else
          if response_or_body_or_doc.respond_to?(:body)
            response_or_body_or_doc.body.to_s
          elsif response_or_body_or_doc.respond_to?(:to_html)
            response_or_body_or_doc.to_html.to_s
          else
            response_or_body_or_doc.to_s
          end
        end
        return false if body.empty?
        body.match?(AUTO_LOGOUT_REGEX)
      end

      # Plan 24-01 T2: Block-Helper für CC-Calls mit lazy Auto-Logout-Recovery.
      # Caller-Block bekommt (client, session_id) und liefert [res, doc] zurück
      # (analog client.get / client.post Return-Konvention).
      #
      # Verhalten:
      #   - 1. Aufruf: Block ausführen → wenn Response NICHT Auto-Logout → return [res, doc].
      #   - Sonst: Setting.login_to_cc + reset! → Block GENAU EINMAL wiederholen.
      #   - 2. Aufruf liefert noch immer Auto-Logout → raise SessionRecoveryFailed.
      #   - Login-Trigger raised → raise SessionRecoveryFailed.
      #
      # Symmetrisch zur existierenden Setting.login_to_cc-Architektur (Decision Q1 in
      # Phase-24-CONTEXT: lazy statt eager). Heute live als manueller Recovery-Pfad
      # via curl + frische SID verifiziert.
      def with_session_recovery(server_context: nil)
        client = client_for(server_context)
        res, doc = yield(client, cookie)
        return [res, doc] unless session_expired?(res)

        Rails.logger.warn "[CcSession.with_session_recovery] expired session detected, triggering re-login"
        begin
          reset!
          cookie  # erzwingt login! — raises bei Login-Fail
        rescue => e
          raise SessionRecoveryFailed, "re-login failed after Auto-Logout-Stub: #{e.class}: #{e.message}"
        end

        client = client_for(server_context)  # neuer Client mit fresh SID
        res2, doc2 = yield(client, cookie)
        if session_expired?(res2)
          raise SessionRecoveryFailed, "second response still Auto-Logout-Stub after re-login (PHPSESSID #{cookie[0, 8]}…)"
        end
        [res2, doc2]
      end

      # Plan 14-02.3 / F-5 + D-14-02-A Helper A: Live-CC-Meldeliste-Overview via
      # editMeldelisteCheck.php. Liefert die meldeliste_cc_id + Clubs-Liste aus
      # der CC-Übersicht. Source-of-truth-Pfad (DB-Mirror veraltet/inkomplett).
      #
      # Plan 24-01 T2: nutzt with_session_recovery für Auto-Logout-Recovery.
      # SessionRecoveryFailed propagiert nach oben — Caller (Resolver) liefert
      # strukturierten error statt stillschweigend „0 Treffer".
      #
      # Returnt Hash {meldeliste_cc_id: Integer, clubs: Hash[club_cc_id => name], source: "live-cc-overview"}
      # oder nil bei:
      #   - Network-Error
      #   - HTTP-Status != 200
      #   - Parse-Failure (kein meldeliste_cc_id extrahierbar)
      # Defensive: alle nicht-Auth-Fehler → nil + Rails.logger.warn (KEIN Exception-Raise).
      def fetch_meldeliste_overview(tournament_cc_id, server_context: nil)
        return nil if tournament_cc_id.blank?
        res, doc = with_session_recovery(server_context: server_context) do |client, sid|
          client.get(
            "editMeldelisteCheck",
            {meisterschaftsId: tournament_cc_id},
            {session_id: sid}
          )
        end
        return nil if res.nil? || res.code != "200" || doc.nil?

        meldeliste_cc_id = parse_meldeliste_cc_id(doc)
        return nil if meldeliste_cc_id.nil?

        {
          meldeliste_cc_id: meldeliste_cc_id,
          clubs: parse_clubs_overview(doc),
          source: "live-cc-overview"
        }
      rescue SessionRecoveryFailed
        raise  # propagiert nach oben — Resolver liefert structured error
      rescue => e
        Rails.logger.warn "[CcSession.fetch_meldeliste_overview] #{e.class}: #{e.message}"
        nil
      end

      # Extrahiert meldelisteId aus editMeldelisteCheck.php Response.
      # Robuste Multi-Pattern-Heuristik (CC liefert HTML-Form mit hidden input
      # ODER value-Attribut auf einem Select-Element ODER Link-Param).
      def parse_meldeliste_cc_id(doc)
        # Pattern A: <input name="meldelisteId" value="X">
        input = doc.css('input[name="meldelisteId"], input[name="meldelisteCcId"]').first
        if input && input["value"].to_s.match?(/\A\d+\z/)
          return input["value"].to_i
        end
        # Pattern B: <select name="meldelisteId"><option value="X" selected>
        sel = doc.css('select[name="meldelisteId"] option[selected]').first
        if sel && sel["value"].to_s.match?(/\A\d+\z/)
          return sel["value"].to_i
        end
        # Pattern C: meldelisteId=X im Query-Param eines Anchors
        anchor = doc.css("a[href*='meldelisteId=']").first
        if anchor && (m = anchor["href"].to_s.match(/meldelisteId=(\d+)/))
          return m[1].to_i
        end
        # Pattern D: data-meldeliste-cc-id="X"
        node = doc.css("[data-meldeliste-cc-id]").first
        if node
          return node["data-meldeliste-cc-id"].to_i
        end
        nil
      end

      # Extrahiert Clubs-Liste aus der editMeldelisteCheck.php Übersicht.
      # Returnt Hash[club_cc_id => club_name]. Robust gegen verschiedene
      # CC-HTML-Varianten; leer wenn nichts gefunden (Plan 14-02.4 nutzt das
      # für per-Club-Detail-Calls; in 14-02.3 nur Strukturierungs-Substrate).
      def parse_clubs_overview(doc)
        result = {}
        # Pattern: <option value="club_cc_id">Club Name</option> in einem clubId-Select
        doc.css('select[name="clubId"] option, select[name="clubCcId"] option').each do |opt|
          next if opt["value"].to_s == "*" || opt["value"].to_s.empty?
          next unless opt["value"].to_s.match?(/\A\d+\z/)
          result[opt["value"].to_i] = opt.text.strip
        end
        result
      rescue => e
        Rails.logger.warn "[CcSession.parse_clubs_overview] #{e.class}: #{e.message}"
        {}
      end

      private

      # Real CC-Login: delegiert an existierenden kanonischen Setting.login_to_cc Flow (Blocker 4 Fix).
      # Mock-Mode schaltет auf festes Token kurz.
      def login!
        if mock_mode?
          self.session_id = "MOCK_SESSION_ID"
          self.session_started_at = Time.now
          return session_id
        end

        # Reuse des existierenden kanonischen CC-Login-Flows (Setting.login_to_cc).
        # Diese Methode:
        #   - Liest Region-Kontext via RegionCcAction.get_base_opts_from_environment
        #   - Holt Credentials aus Rails Credentials (per-environment verschlüsselt) oder RegionCc-Fallback
        #   - POSTet an /login/checkUser.php mit MD5-Passwort + call_police hidden field
        #   - Folgt Redirect, extrahiert PHPSESSID aus Set-Cookie
        #   - Persistiert session_id via Setting.key_set_value("session_id", ...)
        #   - Gibt die session_id-String zurück
        #
        # NOTE: ENV vars CC_USERNAME / CC_PASSWORD / CC_FED_ID werden indirekt gelesen — der kanonische
        # Flow nutzt Rails Credentials + Region-Kontext. Für ENV-only-Credentials:
        # In `RAILS_MASTER_KEY`-verschlüsselte credentials.yml.enc eintragen statt Bypass.
        self.session_id = Setting.login_to_cc
        self.session_started_at = Time.now
        session_id
      end

      def login_redirect?(doc)
        return false if doc.nil?
        return false unless doc.respond_to?(:css)
        doc.css("form[action*='login']").any?
      end
    end
  end
end
