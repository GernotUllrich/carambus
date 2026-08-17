# frozen_string_literal: true

module RegionServer
  # Plan 32-10: Holt die SPIELERGEBNISSE eines Region Servers auf die AUTHORITY.
  #
  # Pull, analog CC-Scrape: die Authority fetcht das JSON von `Api::Public::GameResultsController`
  # und legt daraus GLOBALE Game/GameParticipation an. Der regulaere Versions-Sync verteilt sie
  # anschliessend an alle Instanzen. Das ist der Schlusspunkt des CC-losen Ergebniswegs — erst hier
  # wird ein Ergebnis global und damit fuer das turnieruebergreifende Ranking sichtbar.
  #
  # OHNE TOKEN (Betreiber-Entscheidung D9): die Quelle ist oeffentlich, wie das public CC. Anders
  # als `EntryListImporter` braucht dieser Weg keinen Service-Account — und faellt damit nicht aus,
  # wenn ein DB-Rebuild des Region Servers den Account loescht.
  #
  # UPSERT STATT DELETE-AND-REBUILD: Der CC-Scraper loescht alle Spiele eines Turniers und baut sie
  # neu (public_cc_scraper.rb:325) — er MUSS, weil HTML-Scraping keinen verlaesslichen Schluessel
  # liefert. Hier gibt es (gname, seqno). Bei laufendem Turnier (Betreiber-Entscheidung D4) wuerde
  # Neuaufbau je Pull PaperTrail-Versionen im Verhaeltnis Spiele × Pulls erzeugen und den Sync
  # fluten — gegen die gesamte v0.6-Arbeit an der Scrape-/Sync-Effizienz.
  #
  # ⚠️ Spieler werden AUFGELOEST, nie neu angelegt; Turniere ebenso. Unaufloesbares wird berichtet.
  class GameResultImporter
    Result = Struct.new(:games_created, :games_updated, :games_unchanged, :games_removed,
      :tournaments_matched, :tournaments_unmatched, :tournaments_skipped_cc,
      :players_unresolved, keyword_init: true)

    def initialize(region:, season:, base_url: nil, armed: false, document: nil)
      @region = region
      @season = season
      @base_url = (base_url.presence || default_base_url).to_s.chomp("/")
      @armed = armed
      @document = document
    end

    def call
      doc = @document || fetch_document
      unless doc.is_a?(Hash) && doc["tournaments"].is_a?(Array)
        raise ArgumentError, "Antwort enthält keine tournaments-Liste"
      end

      result = Result.new(games_created: 0, games_updated: 0, games_unchanged: 0, games_removed: 0,
        tournaments_matched: 0, tournaments_unmatched: [], tournaments_skipped_cc: 0,
        players_unresolved: [])

      doc["tournaments"].each { |payload| import_tournament(payload, result) }
      result
    end

    private

    # Konvention statt Datenhaltung: Region hat KEINE Spalte fuer ihre Server-URL
    # (vgl. entry_list_importer.rb:61). Per base_url/ENV ueberschreibbar.
    def default_base_url
      "https://#{@region.shortname.to_s.downcase}.carambus.de"
    end

    def fetch_document
      uri = URI("#{@base_url}/api/public/game_results?region=#{CGI.escape(@region.shortname.to_s)}" \
                "&season=#{CGI.escape(@season.name.to_s)}")

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(Net::HTTP::Get.new(uri))
      end
      raise "Quelle nicht erreichbar (HTTP #{response.code}): #{uri}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    # Verknuepfung ueber `source_url`, nicht ueber die ID — dieselbe Provenienz-Konvention wie im
    # Meldelisten-Ingest (Plan 28-01). Kein Treffer heisst: dieses Turnier ist nie ueber den Ingest
    # gelaufen. Dann wird berichtet, NICHT angelegt: ein hier erzeugtes Turnier waere ein
    # Duplikat-Zwilling ohne Meldeliste.
    def import_tournament(payload, result)
      source_id = payload["source_tournament_id"]
      return if source_id.blank?

      source_url = "#{@base_url}/tournaments/#{source_id}"
      tournament = ::Tournament.find_by(source_url: source_url)
      if tournament.nil?
        result.tournaments_unmatched << source_url
        return
      end

      # Was aus der ClubCloud stammt, gehoert der ClubCloud — der PublicCcScraper bleibt fuer diese
      # Turniere der Weg. Der Region Server filtert bereits, das hier ist die zweite Linie.
      #
      # Seit Plan 34-02 ueber `cc_sourced?` statt ueber den `tournament_cc`-Zwilling. Im Bestand
      # unterscheiden sich beide nur bei 376 BillardArea-Turnieren mit Migrations-Zwilling — und die
      # tragen per Definition keine `source_url`, koennen hier also gar nicht ankommen (der Match
      # oben laeuft ueber `source_url`).
      if tournament.cc_sourced?
        result.tournaments_skipped_cc += 1
        return
      end

      result.tournaments_matched += 1
      keep_keys = Array(payload["games"]).filter_map { |row| import_game(tournament, row, result) }
      prune_removed_games(tournament, keep_keys, result)
    end

    # Ein auf dem Region Server GELOESCHTES Spiel muss auch global verschwinden — sonst bliebe eine
    # zurueckgezogene Ergebniszeile fuer immer stehen und floesse ins Ranking ein.
    #
    # Live aufgefallen 2026-07-29: `import_game` allein macht Upserts; ohne Gegenstueck kannte der
    # Weg keine Loeschung. Das Muster ist von `EntryListImporter#prune_removed_entries` uebernommen,
    # der Schluessel ist derselbe wie beim Upsert: (gname, seqno).
    #
    # ⚠️ DIE QUELLE IST FUEHREND: liefert sie fuer ein Turnier keine Spiele mehr, verschwinden auch
    # global alle. Das ist gewollt (dasselbe gilt fuer Meldungen), macht den Weg aber empfindlich
    # gegen ein fehlerhaft LEERES Dokument — derselbe fail-silent-Fall, den ScrapeListGuard fuer die
    # CC-Listen adressiert. Bewusst nicht zusaetzlich abgesichert: hier ist die Quelle die eigene
    # Instanz, nicht ein fremder Anbieter.
    def prune_removed_games(tournament, keep_keys, result)
      orphans = tournament.games.reject { |g| keep_keys.include?([g.gname.to_s, g.seqno.to_i]) }
      return if orphans.empty?

      result.games_removed += orphans.size
      return unless @armed

      ::Game.skip_cable_ready_updates do
        orphans.each(&:destroy!)
      end
    end

    # Gibt den Schluessel [gname, seqno] zurueck, damit `prune_removed_games` weiss, welche Spiele
    # die Quelle noch fuehrt — oder nil, wenn die Zeile unbrauchbar ist.
    def import_game(tournament, row, result)
      gname = row["group"].to_s.strip
      seqno = row["seqno"]
      return nil if gname.blank? || seqno.blank?

      key = [gname, seqno.to_i]

      participations = resolve_participations(row)
      if participations.nil?
        result.players_unresolved << row_label(row)
        # Der Schluessel zaehlt TROTZDEM als vorhanden: ein Spiel, dessen Spieler (noch) nicht
        # aufloesbar ist, existiert auf der Quelle. Es zu loeschen waere die falsche Schlussfolgerung
        # aus einem Stammdaten-Problem.
        return key
      end

      game = tournament.games.find_by(gname: gname, seqno: seqno)
      existing = game.present?

      unless @armed
        existing ? result.games_updated += 1 : result.games_created += 1
        return key
      end

      ::Game.skip_cable_ready_updates do
        game ||= tournament.games.new
        game.assign_attributes(
          gname: gname, seqno: seqno, ended_at: row["ended_at"],
          data: game_data(tournament, gname, seqno, participations)
        )
        game.region_id = tournament.region_id

        if game.changed?
          game.save!
          existing ? result.games_updated += 1 : result.games_created += 1
        else
          result.games_unchanged += 1
        end

        write_participations(game, gname, participations)
      end

      key
    end

    # Rollen-Abbildung: der Transportweg nutzt die lokale Konvention playera/playerb, die GLOBALEN
    # Records tragen "Heim"/"Gast" — genau wie CC-gescrapte (public_cc_scraper.rb:1080/1097). Das
    # ist der Punkt, an dem der CC-lose Weg auf die kanonische Form einschwenkt.
    ROLE_MAP = {"playera" => "Heim", "playerb" => "Gast"}.freeze

    # Alles-oder-nichts je Spiel: ein halb aufgeloestes Spiel waere im Ranking schaedlicher als
    # keines. Spieler werden NIE angelegt (Grundsatz aus Plan 28-01).
    def resolve_participations(row)
      rows = Array(row["participations"])
      return nil unless rows.size == 2

      resolved = rows.map do |participation|
        player = ::Player.find_by(dbu_nr: participation["dbu_nr"].to_s)
        {row: participation, player: player, role: ROLE_MAP[participation["role"].to_s]}
      end
      return nil if resolved.any? { |r| r[:player].nil? || r[:role].nil? }

      # Heim zuerst — die Reihenfolge bestimmt "100:85" und darf nicht von der Quelle abhaengen.
      resolved.sort_by { |r| (r[:role] == "Heim") ? 0 : 1 }
    end

    def write_participations(game, gname, participations)
      ::GameParticipation.skip_cable_ready_updates do
        participations.each do |entry|
          participation = game.game_participations.find_by(role: entry[:role]) ||
            game.game_participations.new(role: entry[:role])

          participation.assign_attributes(
            player_id: entry[:player].id,
            result: entry[:row]["result"],
            innings: entry[:row]["innings"],
            gd: entry[:row]["gd"],
            hs: entry[:row]["hs"],
            data: {"results" => {
              "Gr." => gname,
              "Ergebnis" => entry[:row]["result"],
              "Aufnahme" => entry[:row]["innings"],
              "GD" => entry[:row]["gd"],
              "HS" => entry[:row]["hs"]
            }.compact}
          )
          participation.region_id = game.region_id
          participation.save! if participation.changed?
        end
      end
    end

    # DIE FORM IST NICHT KOSMETIK: `tournaments/show.html.erb:137` ueberspringt Spiele ohne
    # "Ergebnis" ODER "Punkte" und baut die Tabellenkoepfe aus `data.keys` — ein leeres `data`
    # machte die importierten Spiele auf der Turnierseite UNSICHTBAR.
    #
    # Uebernommen wird die Einzel-Frame-Form des CC-Scrapers (public_cc_scraper.rb:1034-1049),
    # beschraenkt auf die Felder, die aus den Ergebniszeilen wirklich ableitbar sind. `compact`
    # wie dort: was fehlt, faellt raus, statt als leere Spalte zu erscheinen.
    def game_data(tournament, gname, seqno, participations)
      home, guest = participations
      {
        "Gruppe" => gname,
        "Partie" => seqno,
        "Heim" => home[:player].fullname,
        "Gast" => guest[:player].fullname,
        "Disziplin" => tournament.discipline&.name,
        "Punkte" => pair(home, guest, "result", ":"),
        "Aufn." => pair(home, guest, "innings", "/"),
        "HS" => pair(home, guest, "hs", "/"),
        "Durchschnitt" => pair(home, guest, "gd", "/")
      }.compact
    end

    def pair(home, guest, key, separator)
      values = [home[:row][key], guest[:row][key]]
      return nil if values.all?(&:blank?)

      values.join(separator)
    end

    def row_label(row)
      numbers = Array(row["participations"]).map { |p| p["dbu_nr"].presence || "fehlt" }.join(" vs ")
      "#{row["group"].presence || "(ohne Gruppe)"} / Partie #{row["seqno"].presence || "?"} (DBU #{numbers})"
    end
  end
end
