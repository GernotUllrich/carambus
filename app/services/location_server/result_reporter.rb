# frozen_string_literal: true

module LocationServer
  # Plan 29-03: Meldet den ABSCHLUSS eines Turniers vom LOCATION SERVER an den REGION SERVER.
  #
  # Der Weg des Ergebnisses ist dreistufig — und das mit Absicht:
  #   Location Server (hier) → Region Server → Phase-28-Ingest → Authority → Sync → alle Instanzen
  # Ein direkter Push an die Authority waere kuerzer, wuerde sie aber erstmals fuer Schreibzugriffe
  # von aussen oeffnen. Die Betreiber-Entscheidung (2026-07-21) haelt sie geschlossen.
  #
  # ZIELABLEITUNG OHNE NEUE DATENHALTUNG: Das Turnier liegt hier als GLOBALER Record (per Sync
  # eingetroffen) und traegt `source_url = "<region-base>/tournaments/<lokale-id>"` — gesetzt vom
  # Ingest in Plan 28-01. Daraus liest dieser Service beides: wohin gemeldet wird (Region-Basis) und
  # woran es dort haengt (die lokale ID des Region Servers). Dieselbe Provenienz-Konvention,
  # rueckwaerts gelesen. Keine Migration, keine Konfiguration.
  #
  # Gemeldet werden NUR selbst erzeugte Ranglisten (`data["result_source"] == "carambus"`, Plan 29-02).
  # Was aus der ClubCloud stammt, gehoert der ClubCloud — es zurueckzuspielen waere bestenfalls
  # ueberfluessig und schlimmstenfalls eine Ueberschreibung fremder Daten.
  class ResultReporter
    Result = Struct.new(:reported, :skipped_no_source_url, :skipped_no_own_ranking,
      :response, keyword_init: true)

    # ZUGANG: ein Service-Account JE REGION auf dem Region Server (Betreiber-Entscheidung 2026-07-21),
    # angelegt mit `rake service_accounts:create_carambus_app[NBV]`. Alle Location Server einer Region
    # teilen ihn. Die Zugangsdaten stehen in der Instanz-Konfiguration (`config/carambus.yml`), nicht
    # im Code und nicht in der Datenbank — dieselbe Ebene wie `carambus_api_url`.
    #
    # Fehlen sie, meldet der Service das verstaendlich, statt unauthentifiziert loszulaufen und am
    # 401 zu scheitern.
    #
    # Die Spieler-Kennung ist `dbu_nr` — IDs sind je Instanz verschieden und taugen nicht ueber
    # Instanzgrenzen (derselbe Grundsatz wie im Meldelisten-Ingest, Plan 28-01).
    def initialize(tournament:, armed: false, token: nil)
      @tournament = tournament
      @armed = armed
      @token = token
    end

    def call
      result = Result.new(reported: 0, skipped_no_source_url: 0, skipped_no_own_ranking: 0)

      target = target_from_source_url
      if target.nil?
        # Kein source_url: entweder aus der ClubCloud gescrapt oder nie ueber den Ingest gelaufen.
        # Dann gibt es keinen Region Server, der dieses Turnier als Arbeitsexemplar fuehrt.
        result.skipped_no_source_url += 1
        return result
      end

      entries = own_rankings
      if entries.empty?
        result.skipped_no_own_ranking += 1
        return result
      end

      result.reported = entries.size
      return result unless @armed

      result.response = post(target, entries)
      result
    end

    private

    # "<region-base>/tournaments/<lokale-id>" -> {base:, source_tournament_id:}
    def target_from_source_url
      url = @tournament.source_url.to_s
      match = url.match(%r{\A(?<base>https?://[^/]+)/tournaments/(?<id>\d+)\z})
      return nil if match.nil?

      {base: match[:base], source_tournament_id: match[:id].to_i}
    end

    def own_rankings
      @tournament.seedings.includes(:player).filter_map do |seeding|
        next unless seeding.data.is_a?(Hash)
        next unless seeding.data["result_source"] == ::Tournament::FinalRankingWriter::SOURCE_MARKER

        ranking = seeding.data.dig("result", "Gesamtrangliste")
        next if ranking.blank?

        dbu_nr = seeding.player&.dbu_nr
        next if dbu_nr.blank?

        {"dbu_nr" => dbu_nr, "Gesamtrangliste" => ranking}
      end
    end

    # Holt ein JWT beim Region Server (devise-jwt, Muster aus service_accounts.rake:78-81).
    # Ein Token wird pro Aufruf besorgt — die Meldung geschieht einmal je Turnier, ein Cache waere
    # unnoetige Zustandshaltung.
    def token_for(base)
      return @token if @token.present?

      email = Carambus.config.region_server_user
      password = Carambus.config.region_server_password
      if email.blank? || password.blank?
        raise "Kein Zugang zum Region Server konfiguriert — `region_server_user`/`region_server_password` " \
              "in config/carambus.yml setzen (Service-Account je Region, siehe " \
              "`rake service_accounts:create_carambus_app[<REGION>]`)"
      end

      uri = URI("#{base}/login")
      request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
      request.body = {user: {email: email, password: password}}.to_json
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
      raise "Anmeldung am Region Server fehlgeschlagen (HTTP #{response.code}): #{uri}" unless response.is_a?(Net::HTTPSuccess)

      response["Authorization"].to_s.sub(/\ABearer /, "").presence ||
        raise("Region Server lieferte kein Authorization-Header bei der Anmeldung")
    end

    def post(target, entries)
      token = token_for(target[:base])

      uri = URI("#{target[:base]}/api/tournament_results")
      request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
      request["Authorization"] = "Bearer #{token}"
      request.body = {
        "schema" => "carambus.tournament_result/v1",
        "source_tournament_id" => target[:source_tournament_id],
        "entries" => entries
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
      raise "Region Server antwortet HTTP #{response.code}: #{uri}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
