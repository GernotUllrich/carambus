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
