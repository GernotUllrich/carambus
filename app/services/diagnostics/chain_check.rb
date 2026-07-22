# frozen_string_literal: true

module Diagnostics
  # Prueft auf der LAUFENDEN Instanz, ob sie ihren Platz in der CC-losen Turnier-Kette einnehmen kann.
  #
  #   Authority  ──holt Meldelisten──▶  Region Server  ◀──meldet Ergebnisse──  Location Server
  #
  # Warum instanz-lokal und nicht zentral: die Zugangsdaten liegen in den verschluesselten Credentials
  # JEDER Instanz. Keine Instanz kann die Konfiguration einer anderen lesen — ein zentraler Check
  # koennte nur raten. Den statischen Abgleich ueber alle Szenarien macht `Diagnostics::ScenarioCheck`
  # aus dem Entwickler-Checkout.
  #
  # STRIKT READ-ONLY. Der einzige Seiteneffekt ist ein Login am Region Server (erzeugt ein JWT) —
  # abschaltbar ueber `probe_network: false`.
  #
  # ⚠️ Gibt NIEMALS Passwoerter aus, auch nicht gekuerzt: die Ausgabe landet erfahrungsgemaess in
  # Support-Mails und Chat-Verlaeufen.
  class ChainCheck
    # Konvention aus RegionServer::EntryListImporter: "https://<shortname>.carambus.de".
    # Der ResultReporter nutzt sie NICHT — er liest sein Ziel aus `tournament.source_url`. Fuer eine
    # Vorab-Diagnose (es gibt noch kein Turnier) ist die Konvention die einzige Quelle, deshalb wird
    # sie in der Ausgabe als Annahme kenntlich gemacht.
    def self.region_server_base(shortname) = "https://#{shortname.to_s.downcase}.carambus.de"

    HTTP_TIMEOUT = 8

    def initialize(probe_network: true)
      @probe_network = probe_network
      @checks = []
    end

    def call
      @checks = []
      check_role
      check_context_region
      check_season

      case role
      when :authority then check_authority
      when :region_server then check_region_server
      when :location_server then check_location_server
      end

      @checks
    end

    # :authority | :region_server | :location_server
    #
    # `local_server?` (== carambus_api_url gesetzt) ist die im Code etablierte Unterscheidung
    # (application_record.rb:75). location_id trennt darunter Location- von Region Server.
    def role
      return :authority unless ApplicationRecord.local_server?

      (location_id.to_i > 0) ? :location_server : :region_server
    end

    private

    def add(name, status, detail, hint = nil)
      @checks << Check.new(name: name, status: status, detail: detail, hint: hint)
    end

    def config = Carambus.config

    def location_id = config.respond_to?(:location_id) ? config.location_id : nil

    def context = config.respond_to?(:context) ? config.context.to_s.strip : ""

    # ---------------------------------------------------------------- gemeinsame Checks

    def check_role
      label = {authority: "Authority", region_server: "Region Server", location_server: "Location Server"}[role]
      add("Rolle", :info, "#{label} (carambus_api_url=#{ApplicationRecord.local_server? ? "gesetzt" : "leer"}, location_id=#{location_id.presence || "-"})")
    end

    # Der Fehler, der auf nbv unsichtbar war und erst auf tbv auffiel: `context` ist in den
    # Szenario-Configs uneinheitlich geschrieben. Wird er nicht aufgeloest, faellt das Scope-Band
    # still auf NBV zurueck — die Instanz zeigt dann die Daten einer FREMDEN Region.
    def check_context_region
      if context.blank?
        status = (role == :authority) ? :ok : :fail
        detail = "kein context gesetzt"
        hint = (role == :authority) ? nil : "scenario.context in der config.yml auf den Region-Shortname setzen"
        return add("Server-Kontext", status, detail, hint)
      end

      region = Region.find_by("UPPER(shortname) = ?", context.upcase)
      if region
        add("Server-Kontext", :ok, "#{context} → Region #{region.shortname} (id=#{region.id})")
      else
        add("Server-Kontext", :fail, "context=#{context.inspect} passt zu keiner Region",
          "Scope-Band und Formular-Vorbelegungen fallen still auf den Default zurueck. Shortname pruefen.")
      end
    end

    def check_season
      season = Season.current_season
      if season
        add("Aktuelle Saison", :info, "#{season.name} (id=#{season.id})")
      else
        add("Aktuelle Saison", :fail, "Season.current_season liefert nichts",
          "Ingest und Ranglisten brauchen eine aufloesbare Saison.")
      end
    end

    # ---------------------------------------------------------------- Authority

    def check_authority
      contexts = declared_region_server_contexts

      if contexts.empty?
        return add("Region-Server-Zugaenge", :fail, "keine deklariert",
          "scenario.credentials.region_server_contexts in carambus_api/config.yml setzen, " \
          "danach scenario:generate_credentials + push_credentials. Ohne sie holt die Authority " \
          "von NIEMANDEM eine Meldeliste — ohne Fehlermeldung.")
      end

      add("Region-Server-Zugaenge", :ok, "deklariert: #{contexts.join(", ").upcase}")
      contexts.each { |ctx| check_region_server_reachable(ctx) }
    end

    # Kontexte aus den ausgerollten Credentials, nicht aus der Szenario-Config: die Instanz sieht
    # nur, was TATSAECHLICH bei ihr angekommen ist. Genau diese Differenz ist der Fehlerfall
    # (deklariert, aber Generator/Push hat die Gruppe still weggelassen).
    def declared_region_server_contexts
      creds = Rails.application.credentials.config[:region_server]
      return [] unless creds.is_a?(Hash)

      creds.keys.map(&:to_s).reject { |k| k == "private_key" }.sort
    end

    def check_region_server_reachable(shortname)
      region = Region.find_by("UPPER(shortname) = ?", shortname.upcase)
      unless region
        return add("Zugang #{shortname.upcase}", :warn, "keine Region mit diesem Shortname",
          "Zugangsdaten sind da, aber der Ingest (REGION=#{shortname.upcase}) findet die Region nicht.")
      end

      credentials = Carambus.region_server_credentials(shortname)
      if credentials.nil?
        return add("Zugang #{shortname.upcase}", :fail, "keine Zugangsdaten aufloesbar",
          "Weder credentials (region_server.#{shortname.downcase}) noch der carambus.yml-Fallback greifen.")
      end

      base = self.class.region_server_base(shortname)
      unless @probe_network
        return add("Zugang #{shortname.upcase}", :skip, "Zugangsdaten vorhanden; Login nicht geprueft (Netzwerk aus)")
      end

      probe_login(label: "Zugang #{shortname.upcase}", base: base, credentials: credentials)
    end

    # ---------------------------------------------------------------- Region Server

    def check_region_server
      check_api_endpoints
      check_service_account
      check_local_tournaments
      check_authority_reachable
    end

    # Der Region Server ist ZIEL, nicht Aufrufer: hier zaehlt, dass die beiden Endpunkte existieren.
    def check_api_endpoints
      %w[/api/entry_lists /api/tournament_results].each do |path|
        exists = Rails.application.routes.routes.any? { |r| r.path.spec.to_s.start_with?(path) }
        if exists
          add("Endpunkt #{path}", :ok, "vorhanden")
        else
          add("Endpunkt #{path}", :fail, "nicht in den Routen",
            "Instanz laeuft auf einem Stand vor v0.7 — Deploy noetig.")
        end
      end
    end

    # Ohne bestaetigten Account antwortet der Login mit 401. Genau daran hing v0.7 zwei Anlaeufe lang:
    # `User` ist :confirmable, die Anlage setzte `confirmed_at` nicht.
    def check_service_account
      return add("Service-Account", :skip, "kein context gesetzt") if context.blank?

      email = "carambus-app-#{context.downcase}-bridge@carambus.de"
      user = User.find_by(email: email)

      if user.nil?
        add("Service-Account", :fail, "#{email} existiert nicht",
          "rake \"service_accounts:create_carambus_app[#{context.upcase}]\" AUF DIESER INSTANZ")
      elsif user.respond_to?(:confirmed_at) && user.confirmed_at.blank?
        add("Service-Account", :fail, "#{email} ist NICHT bestaetigt",
          "Login antwortet mit 401. confirmed_at setzen oder Account neu anlegen.")
      else
        add("Service-Account", :ok, email)
      end
    end

    def check_local_tournaments
      season = Season.current_season
      return add("Lokale Turniere", :skip, "keine aufloesbare Saison") if season.nil?

      region = Region.find_by("UPPER(shortname) = ?", context.upcase)
      return add("Lokale Turniere", :skip, "keine Region aufloesbar") if region.nil?

      scope = Tournament.where(region_id: region.id, season_id: season.id)
        .where(Tournament.arel_table[:id].gteq(ApplicationRecord::MIN_ID))
      add("Lokale Turniere", :info,
        "#{scope.count} in #{season.name} (nur diese liefert /api/entry_lists aus)")
    end

    # ---------------------------------------------------------------- Location Server

    def check_location_server
      check_location
      check_own_region_server
      check_authority_reachable
    end

    def check_location
      location = Location.find_by(id: location_id)
      if location.nil?
        return add("Spielort", :fail, "location_id=#{location_id.inspect} existiert nicht",
          "Ohne gueltigen Spielort kann hier kein Turnier durchgefuehrt werden.")
      end

      tables = location.tables.count
      status = tables.zero? ? :warn : :ok
      hint = tables.zero? ? "Tische sind lokale Records und werden hier angelegt — ohne Tisch kein TableMonitor." : nil
      add("Spielort", status, "#{location.name} (id=#{location.id}, #{tables} Tische)", hint)
    end

    # Der ResultReporter liest sein Ziel aus `tournament.source_url`, nicht aus der Config. Vor dem
    # ersten Turnier gibt es das nicht — deshalb hier die Namenskonvention, klar als Annahme benannt.
    def check_own_region_server
      if context.blank?
        return add("Rueckweg zum Region Server", :fail, "kein context gesetzt",
          "Ohne Region-Kontext sind keine Zugangsdaten aufloesbar.")
      end

      credentials = Carambus.region_server_credentials(context)
      if credentials.nil?
        return add("Rueckweg zum Region Server", :fail, "keine Zugangsdaten fuer #{context.upcase}",
          "region_server_contexts: [#{context.upcase}] in der config.yml + shared.region_server." \
          "#{context.downcase} in secrets.yml, dann generate/push_credentials. " \
          "Betrifft nur CC-lose Regionen — wo die ClubCloud fuehrt, laeuft der Rueckweg ueber sie.")
      end

      base = self.class.region_server_base(context)
      unless @probe_network
        return add("Rueckweg zum Region Server", :skip, "Zugangsdaten vorhanden; Login nicht geprueft (Netzwerk aus)")
      end

      probe_login(label: "Rueckweg zum Region Server", base: base, credentials: credentials,
        suffix: " (angenommene Adresse; im Betrieb kommt sie aus tournament.source_url)")
    end

    # ---------------------------------------------------------------- geteilt

    def check_authority_reachable
      url = config.carambus_api_url.to_s
      return add("Authority erreichbar", :skip, "carambus_api_url leer") if url.blank?
      return add("Authority erreichbar", :skip, "#{url} (Netzwerk aus)") unless @probe_network

      code = http_status(URI.join(url, "/"))
      if code&.between?(200, 399)
        add("Authority erreichbar", :ok, "#{url} → HTTP #{code}")
      else
        add("Authority erreichbar", :fail, "#{url} → #{code || "keine Antwort"}",
          "Ohne die Authority kommen keine globalen Records per Sync an.")
      end
    end

    def probe_login(label:, base:, credentials:, suffix: "")
      ServiceAccountToken.fetch(base_url: base, **credentials)
      add(label, :ok, "Login an #{base} erfolgreich#{suffix}")
    rescue => e
      add(label, :fail, "#{base}: #{e.message.lines.first.to_s.strip}",
        "Ein 401 heisst falsches/rotiertes Passwort oder unbestaetigter Account; " \
        "ein 302/422 heisst, die Gegenstelle laeuft auf einem Stand vor v0.7.")
    end

    def http_status(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
        open_timeout: HTTP_TIMEOUT, read_timeout: HTTP_TIMEOUT) do |http|
        http.request(Net::HTTP::Head.new(uri)).code.to_i
      end
    rescue
      nil
    end
  end
end
