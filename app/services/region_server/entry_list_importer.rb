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
    Result = Struct.new(:tournaments_created, :tournaments_matched, :seedings_created,
      :players_unresolved, :skipped_no_source_id, keyword_init: true)

    def initialize(region:, season:, base_url: nil, armed: false, document: nil)
      @region = region
      @season = season
      @base_url = (base_url.presence || default_base_url).to_s.chomp("/")
      @armed = armed
      @document = document
    end

    def call
      doc = @document || fetch_document
      raise ArgumentError, "Antwort enthält keine tournaments-Liste" unless doc.is_a?(Hash) && doc["tournaments"].is_a?(Array)

      result = Result.new(tournaments_created: 0, tournaments_matched: 0, seedings_created: 0,
        players_unresolved: [], skipped_no_source_id: 0)

      doc["tournaments"].each { |payload| import_tournament(payload, result) }
      result
    end

    private

    # Konvention statt Datenhaltung: Region hat KEINE Spalte fuer ihre Server-URL
    # (vgl. service_accounts.rake:77). Per base_url/ENV ueberschreibbar.
    def default_base_url
      "https://#{@region.shortname.to_s.downcase}.carambus.de"
    end

    def fetch_document
      uri = URI("#{@base_url}/api/entry_lists?region=#{CGI.escape(@region.shortname.to_s)}" \
                "&season=#{CGI.escape(@season.name.to_s)}")
      response = Net::HTTP.get_response(uri)
      raise "Quelle nicht erreichbar (HTTP #{response.code}): #{uri}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def import_tournament(payload, result)
      source_id = payload["source_tournament_id"]
      if source_id.blank?
        result.skipped_no_source_id += 1
        return
      end

      source_url = "#{@base_url}/tournaments/#{source_id}"
      existing = ::Tournament.find_by(source_url: source_url)

      tournament = existing || build_tournament(payload, source_url, result)
      result.tournaments_matched += 1 if existing

      # Auch im dry-run (tournament == nil) die Meldungen durchgehen: die Zahl der entstehenden
      # Seedings und vor allem die UNAUFLOESBAREN Spieler sind die eigentliche Information eines
      # Probelaufs.
      import_entries(tournament, payload["entries"], result)
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

    def import_entries(tournament, entries, result)
      Array(entries).each do |entry|
        player = resolve_player(entry)
        if player.nil?
          result.players_unresolved << entry_label(entry)
          next
        end

        # tournament ist im dry-run nil (noch nicht angelegt) — dann existiert zwangslaeufig noch
        # keine Meldung, alle zaehlen als neu.
        next if tournament&.seedings&.exists?(player_id: player.id)

        result.seedings_created += 1
        next unless @armed && tournament

        ::Seeding.skip_cable_ready_updates do
          tournament.seedings.create!(
            player_id: player.id,
            position: entry["position"],
            balls_goal: entry["balls_goal"]
          )
        end
      end
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
