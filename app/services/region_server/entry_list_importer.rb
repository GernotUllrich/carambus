# frozen_string_literal: true

module RegionServer
  # Plan 28-01: Holt die MELDELISTE eines Region Servers auf die AUTHORITY.
  #
  # Pull, analog CC-Scrape (Betreiber-Vorgabe): die Authority fetcht das JSON-Dokument von
  # `Api::EntryListsController` und legt daraus GLOBALE Records an. Danach verteilt der regulaere
  # Versions-Sync sie an alle Instanzen — auch an den Location Server, wo gespielt wird.
  #
  # ID-UEBERSETZUNG (der Kern): Die Quelle liefert LOKALE IDs (>= MIN_ID, dort die normale Sequenz).
  # Auf der Authority entstehen GLOBALE IDs (< MIN_ID). Die Verknuepfung laeuft NICHT ueber die ID,
  # sondern ueber `source_url` — dieselbe Provenienz-Konvention wie bei CC/LigaManager/NuLiga:
  #   source_url = "<region-server-base>/tournaments/<lokale-id>"
  #
  # Guard wie die uebrigen Importer: dry-run per Default, Schreiben nur mit armed:, broadcast-frei.
  #
  # ⚠️ Spieler werden AUFGELOEST, nie neu angelegt — Stammdaten bleiben DBU-CC-gepflegt
  # ("CC-less" != "CC-frei"). Unaufloesbare Meldungen werden berichtet.
  class EntryListImporter
    Result = Struct.new(:tournaments_created, :tournaments_matched, :tournaments_updated,
      :seedings_created, :seedings_removed,
      :players_unresolved, :skipped_no_source_id,
      :rankings_imported, :rankings_skipped_foreign, keyword_init: true)

    def initialize(region:, season:, base_url: nil, armed: false, document: nil, token: nil)
      @region = region
      @season = season
      @base_url = (base_url.presence || default_base_url).to_s.chomp("/")
      @armed = armed
      @document = document
      @token = token
    end

    def call
      doc = @document || fetch_document
      raise ArgumentError, "Antwort enthält keine tournaments-Liste" unless doc.is_a?(Hash) && doc["tournaments"].is_a?(Array)

      result = Result.new(tournaments_created: 0, tournaments_matched: 0, tournaments_updated: 0,
        seedings_created: 0, seedings_removed: 0,
        players_unresolved: [], skipped_no_source_id: 0,
        rankings_imported: 0, rankings_skipped_foreign: 0)

      doc["tournaments"].each { |payload| import_tournament(payload, result) }
      result
    end

    # Fuer die Kopfzeile des Rake-Tasks: woraus bedient sich der Lauf? Beantwortet im Probelauf die
    # Frage, ob der Credential-Weg schon traegt oder noch der carambus.yml-Fallback greift.
    def self.credential_source(region_shortname)
      group = Rails.application.credentials.region_server
      return "credentials" if group.present? && group[region_shortname.to_s.downcase.to_sym].present?
      return "carambus.yml" if Carambus.config.region_server_user.present?

      "—"
    end

    private

    # Konvention statt Datenhaltung: Region hat KEINE Spalte fuer ihre Server-URL
    # (vgl. service_accounts.rake:77). Per base_url/ENV ueberschreibbar.
    def default_base_url
      "https://#{@region.shortname.to_s.downcase}.carambus.de"
    end

    # Plan 29-05: Der Endpunkt steht hinter `authenticate_user!` — ein unauthentifizierter Fetch
    # bekommt einen Login-Redirect und meldete frueher "Quelle nicht erreichbar (HTTP 302)", was die
    # Ursache verschwieg.
    def fetch_document
      uri = URI("#{@base_url}/api/entry_lists?region=#{CGI.escape(@region.shortname.to_s)}" \
                "&season=#{CGI.escape(@season.name.to_s)}")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{token}"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
      raise "Quelle nicht erreichbar (HTTP #{response.code}): #{uri}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    # Zugang zum Region Server: ein Service-Account je Region (Betreiber-Entscheidung 2026-07-21),
    # aufgeloest ueber `Carambus.region_server_credentials`. Fehlt er, bricht der Lauf mit einer
    # Meldung ab, die die drei noetigen Handgriffe benennt — statt am 401 zu scheitern.
    def token
      return @token if @token.present?

      credentials = Carambus.region_server_credentials(@region.shortname)
      if credentials.nil?
        raise "Kein Zugang zum Region Server #{@base_url} konfiguriert. Noetig sind: " \
              "(1) `rake service_accounts:create_carambus_app[#{@region.shortname}]` AUF DEM REGION SERVER, " \
              "(2) die Zugangsdaten unter `shared.region_server.#{@region.shortname.to_s.downcase}` " \
              "in carambus_data/secrets.yml und `region_server_contexts: [#{@region.shortname}]` " \
              "in der config.yml des Szenarios, " \
              "(3) `rake scenario:generate_credentials[<szenario>,production]` + " \
              "`rake scenario:push_credentials[<szenario>]`."
      end

      @token = ServiceAccountToken.fetch(base_url: @base_url, **credentials)
    end

    def import_tournament(payload, result)
      source_id = payload["source_tournament_id"]
      if source_id.blank?
        result.skipped_no_source_id += 1
        return
      end

      source_url = "#{@base_url}/tournaments/#{source_id}"
      existing = ::Tournament.find_by(source_url: source_url)

      if existing
        result.tournaments_matched += 1
        tournament = update_tournament(existing, payload, result)
      else
        tournament = build_tournament(payload, source_url, result)
      end

      # Auch im dry-run (tournament == nil bei Neuanlage) die Meldungen durchgehen: die Zahl der
      # entstehenden Seedings und vor allem die UNAUFLOESBAREN Spieler sind die eigentliche
      # Information eines Probelaufs. `import_entries` liefert die aufgeloesten Spieler-IDs zurueck,
      # damit `prune_removed_entries` weiss, welche Meldungen auf der Quelle geloescht wurden.
      keep_player_ids = import_entries(tournament, payload["entries"], result)
      prune_removed_entries(tournament, keep_player_ids, result)
    end

    # Ein bereits uebernommenes Turnier bekommt Struktur- und Datumsaenderungen der Quelle nach.
    # OHNE dies erreichte eine Datums-/Titelkorrektur des Sportwarts die Authority NIE (Plan 29-05
    # Backlog). Nur die Meldelisten-Phase-Felder werden aktualisiert; ein bereits GESPIELTES Turnier
    # (state != Meldephase) bleibt unangetastet, damit der Ingest keine Ergebnisstruktur ueberschreibt.
    def update_tournament(tournament, payload, result)
      return tournament if tournament_in_play?(tournament)

      attrs = payload.slice(*::Tournament::SeasonCopier::STRUCTURE_ATTRIBUTES)
      attrs["date"] = payload["date"] if payload.key?("date")
      attrs["end_date"] = payload["end_date"] if payload.key?("end_date")

      changed = attrs.any? { |k, v| tournament.public_send(k).to_s != v.to_s }
      return tournament unless changed

      result.tournaments_updated += 1
      return tournament unless @armed

      ::Tournament.skip_cable_ready_updates do
        tournament.update!(attrs)
      end
      tournament
    end

    # Turnier ist ueber die reine Meldelisten-Phase hinaus (gestartet/gespielt): dann NICHT mehr aus
    # der Quelle strukturell ueberschreiben. `new_tournament` ist der Default frisch angelegter
    # (auch kopierter) Turniere; alles andere ist Bearbeitung/Spielbetrieb.
    def tournament_in_play?(tournament)
      tournament.tournament_started == true ||
        (tournament.respond_to?(:state) && tournament.state.present? && tournament.state != "new_tournament")
    end

    def build_tournament(payload, source_url, result)
      attrs = payload.slice(*::Tournament::SeasonCopier::STRUCTURE_ATTRIBUTES)
      attrs["season_id"] = @season.id
      attrs["region_id"] = @region.id
      attrs["organizer_type"] = "Region"
      attrs["organizer_id"] = @region.id
      attrs["date"] = payload["date"]
      attrs["end_date"] = payload["end_date"]
      attrs["source_url"] = source_url
      # CC-los entstanden — kein automatischer Upload (konsistent zu Plan 25-01).
      attrs["auto_upload_to_cc"] = false

      result.tournaments_created += 1
      return nil unless @armed

      ::Tournament.skip_cable_ready_updates do
        ::Tournament.create!(attrs)
      end
    end

    # Gibt die aufgeloesten Spieler-IDs der eingehenden Meldeliste zurueck (fuer prune_removed_entries).
    def import_entries(tournament, entries, result)
      keep_player_ids = []
      Array(entries).each do |entry|
        player = resolve_player(entry)
        if player.nil?
          result.players_unresolved << entry_label(entry)
          next
        end
        keep_player_ids << player.id

        # tournament ist im dry-run nil (noch nicht angelegt) — dann existiert zwangslaeufig noch
        # keine Meldung, alle zaehlen als neu.
        seeding = tournament&.seedings&.find_by(player_id: player.id)

        if seeding.nil?
          result.seedings_created += 1
          seeding = create_seeding(tournament, player, entry) if @armed && tournament
        elsif @armed
          update_seeding(seeding, entry)
        end

        import_ranking(seeding, entry, result)
      end
      keep_player_ids
    end

    # Meldungen, die auf der Quelle GELOESCHT wurden, auch auf der Authority entfernen — sonst bliebe
    # ein zurueckgezogener Spieler fuer immer gemeldet (Plan 29-05 Backlog: "eintragen/loeschen").
    # Schutz: nur Meldungen OHNE Ergebnis werden entfernt, damit ein bereits gespieltes Seeding
    # niemals verloren geht. Im dry-run (tournament nil bei Neuanlage) gibt es nichts zu pruefen.
    def prune_removed_entries(tournament, keep_player_ids, result)
      return if tournament.nil?

      orphans = tournament.seedings.where.not(player_id: keep_player_ids)
        .reject { |s| seeding_has_result?(s) }
      return if orphans.empty?

      result.seedings_removed += orphans.size
      return unless @armed

      ::Seeding.skip_cable_ready_updates do
        orphans.each(&:destroy!)
      end
    end

    def seeding_has_result?(seeding)
      seeding.data.is_a?(Hash) && seeding.data["result"].present?
    end

    def create_seeding(tournament, player, entry)
      ::Seeding.skip_cable_ready_updates do
        tournament.seedings.create!(
          player_id: player.id,
          position: entry["position"],
          balls_goal: entry["balls_goal"]
        )
      end
    end

    # Position/Ball-Vorgabe einer bestehenden Meldung nachziehen (der Sportwart kann die Setzliste
    # auf der Quelle aendern). Das Ergebnis bleibt import_ranking vorbehalten.
    def update_seeding(seeding, entry)
      attrs = {position: entry["position"], balls_goal: entry["balls_goal"]}
      return if attrs.all? { |k, v| seeding.public_send(k).to_s == v.to_s }

      ::Seeding.skip_cable_ready_updates do
        seeding.update!(attrs)
      end
    end

    # Plan 29-03: Traegt das Ergebnis mit hoch, wenn eines mitgereist ist. Damit erreicht der
    # Turnier-Abschluss die Authority ueber denselben Pull, der die Meldung holt — die Authority bleibt
    # fuer Schreibzugriffe von aussen geschlossen.
    def import_ranking(seeding, entry, result)
      ranking = entry["Gesamtrangliste"]
      return if ranking.blank?

      # Dieselbe Schutzregel wie entlang der ganzen Kette: gescrapte Ranglisten gehoeren der ClubCloud.
      # Im dry-run ist `seeding` noch nil — dann gibt es zwangslaeufig nichts zu ueberschreiben.
      if seeding.present? && !::Tournament::FinalRankingWriter.writable?(seeding)
        result.rankings_skipped_foreign += 1
        return
      end

      result.rankings_imported += 1
      return unless @armed && seeding

      ::Tournament::FinalRankingWriter.write_gesamtrangliste(seeding, ranking)
    end

    # dbu_nr ist global eindeutig (Memory carambus-club-player-identity-numbers). Kein Fallback auf
    # Namensmatch: ein falsch zugeordneter Spieler waere schlimmer als eine gemeldete Luecke.
    def resolve_player(entry)
      dbu_nr = entry["dbu_nr"]
      return nil if dbu_nr.blank?

      ::Player.find_by(dbu_nr: dbu_nr)
    end

    def entry_label(entry)
      name = [entry["lastname"], entry["firstname"]].compact.join(", ")
      club = entry["club"].presence
      dbu = entry["dbu_nr"].presence || "ohne dbu_nr"
      [name.presence || "(ohne Namen)", club, "DBU #{dbu}"].compact.join(" · ")
    end
  end
end
