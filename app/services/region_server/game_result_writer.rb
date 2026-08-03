# frozen_string_literal: true

module RegionServer
  # Plan 35-03: Die EINE Stelle, an der auf dem Region Server ein Spiel mit Ergebnis entsteht.
  #
  # Zwei Wege muenden hier: der Push vom Location Server (GameResultIngest, 32-08) und die manuelle
  # Erfassung aus Spielberichten (Tournaments::GameResultsController). Beide muessen dieselbe Form
  # erzeugen — sonst haette ein Turnier zwei Sorten Spiele.
  #
  # WARUM DAS NOETIG WAR: Der Ingest schrieb bisher KEIN `game.data` (nur gname/seqno/ended_at/
  # region_id). `tournaments/show.html.erb:146` ueberspringt aber jedes Spiel ohne "Ergebnis" oder
  # "Punkte" und baut die Tabellenkoepfe aus `data.keys`. Die per 32-09 gepushten Ergebnisse lagen
  # damit korrekt in der DB, waren auf der Turnierseite aber UNSICHTBAR — derselbe Fehler, den
  # Plan 32-10 auf der Authority-Seite bereits behoben hatte (GameResultImporter#game_data).
  # Nie aufgefallen, weil die Kette nie live lief.
  #
  # ROLLEN SIND NICHT FREI WAEHLBAR: "playera"/"playerb". Der Authority-Importer mappt sie ueber
  # ROLE_MAP auf "Heim"/"Gast" und verwirft Zeilen mit unbekannter Rolle STILL
  # (game_result_importer.rb:135-152) — ein Spiel mit "Heim"/"Gast" saehe lokal richtig aus und
  # verschwaende beim Authority-Pull spurlos.
  class GameResultWriter
    ROLE_A = "playera"
    ROLE_B = "playerb"

    Result = Struct.new(:game, :created, keyword_init: true)

    # participations: genau zwei Hashes, in Reihenfolge A, B:
    #   {player:, result:, innings:, hs:, gd: (optional — wird sonst berechnet)}
    def initialize(tournament:, gname:, seqno:, participations:, ended_at: nil)
      @tournament = tournament
      @gname = gname.to_s.strip
      @seqno = seqno
      @participations = participations
      @ended_at = ended_at
    end

    def call
      rows = normalized_participations

      # Upsert ueber (gname, seqno) — der Unique-Index auf (tournament_id, gname, seqno) verlangt
      # es, und eine Korrektur soll das Spiel aktualisieren statt ein zweites anzulegen.
      game = @tournament.games.find_by(gname: @gname, seqno: @seqno)
      created = game.nil?
      game ||= @tournament.games.new

      game.assign_attributes(
        gname: @gname,
        seqno: @seqno,
        ended_at: @ended_at,
        tournament_type: "Tournament",
        data: game_data(rows)
      )
      game.region_id = @tournament.region_id
      game.save!

      rows.each_with_index { |row, ix| upsert_participation(game, row, ix.zero? ? ROLE_A : ROLE_B) }

      # Plan 36-03: die Authority anstossen, die Ergebniszeilen einzulesen. Hier und nicht in den
      # beiden Aufrufern, weil BEIDE Wege oben ankommen muessen — der Push vom Location Server
      # (GameResultIngest) genauso wie die manuelle Erfassung. Ohne diesen Anstoss blieben Spiele
      # auf dem Region Server liegen: der Authority-Empfang existiert seit 32-10, aber niemand rief
      # ihn (live aufgefallen 2026-07-29). Dieselbe Luecke wie bei den Meldungen vor Plan 36-02.
      GameResultSyncJob.enqueue_for(tournament: @tournament)

      Result.new(game: game, created: created)
    end

    private

    # Ergaenzt den Generaldurchschnitt, wo er nicht mitgeliefert wurde (manuelle Erfassung liefert
    # nur Baelle und Aufnahmen). Division durch null faengt die Guard ab — `innings` 0 ist bei einem
    # abgebrochenen Spiel real und darf nicht in Infinity/NaN laufen.
    def normalized_participations
      @participations.map do |row|
        row = row.dup
        row[:gd] = computed_gd(row) if row[:gd].blank?
        row
      end
    end

    def computed_gd(row)
      result = row[:result].to_f
      innings = row[:innings].to_i
      return nil if innings.zero?

      (result / innings).round(2)
    end

    # DIE FORM IST NICHT KOSMETIK (siehe Klassenkommentar). Uebernommen aus
    # GameResultImporter#game_data, das seinerseits die Einzel-Frame-Form des CC-Scrapers spiegelt.
    #
    # BEWUSST OHNE `compact` — anders als der Importer: `show.html.erb:136` baut den Tabellenkopf
    # aus dem ERSTEN Spiel, die Zellen aber je Zeile aus `data.each`. Faellt bei einem Spiel ein
    # Schluessel weg (etwa "HS", weil beide Spieler keine Hoechstserie tragen), verschieben sich in
    # dieser Zeile alle folgenden Spalten. Ein konstanter Schluesselsatz ist die Bedingung dafuer,
    # dass die Tabelle ueberhaupt ausgerichtet bleibt.
    def game_data(rows)
      home, guest = rows
      {
        "Gruppe" => @gname,
        "Partie" => @seqno,
        "Heim" => home[:player].fullname,
        "Gast" => guest[:player].fullname,
        "Disziplin" => @tournament.discipline&.name,
        "Punkte" => pair(home, guest, :result, ":"),
        "Aufn." => pair(home, guest, :innings, "/"),
        "HS" => pair(home, guest, :hs, "/"),
        "Durchschnitt" => pair(home, guest, :gd, "/")
      }
    end

    def pair(home, guest, key, separator)
      [home[key], guest[key]].join(separator)
    end

    def upsert_participation(game, row, role)
      gp = game.game_participations.find_by(role: role) || game.game_participations.new(role: role)

      gp.assign_attributes(
        player_id: row[:player].id,
        result: row[:result],
        innings: row[:innings],
        gd: row[:gd],
        hs: row[:hs],
        data: {
          "results" => {
            "Gr." => @gname,
            "Ergebnis" => row[:result],
            "Aufnahme" => row[:innings],
            "GD" => row[:gd],
            "HS" => row[:hs]
          }.compact
        }
      )
      gp.region_id = @tournament.region_id
      gp.save!
    end
  end
end
