# frozen_string_literal: true

require "test_helper"

# Unit-Tests fuer TableMonitor::TrainingResultRecorder (Milestone v0.3, Plan 01-01).
#
# Deckt ab:
#   A. Game.training-Scope (AC-2)
#   B. Wertberechnung inkl. gd-Rundung und innings == 0 (AC-3)
#   C. Gast-Guard: Platzhalter Gast A/B UND Fremdclub-Gast (AC-4)
#   D. Passive/regulaere Mitglieder zaehlen (AC-4b)
#   E. No-op im Turnierpfad (AC-5)
#   F. Idempotenz (AC-6)
#
# ⚠️ IDs: in der Test-DB startet die games-Sequence bei 1, in Dev/Produktion oberhalb
# von MIN_ID. Trainings-Games werden hier daher mit EXPLIZITER id >= Game::MIN_ID
# angelegt — sonst greift der Game.training-Scope nicht.
class TableMonitor::TrainingResultRecorderTest < ActiveSupport::TestCase
  fixtures :players, :seasons, :season_participations, :clubs, :locations,
    :tables, :table_kinds, :table_monitors, :tournaments

  # ⚠️ club_locations.yml wird bewusst NICHT geladen: die Datei verknuepft ueber
  # Label-Verweise (club: bcw), die Rails zu Label-Hash-IDs aufloest — diese treffen
  # die expliziten Club-IDs (50_000_00x) nicht, `Location#clubs` bleibt leer.
  # Dieselbe Falle ist in season_participations.yml dokumentiert ("FKs explizit statt
  # Label-Verweise"). C3 baut die Verknuepfung daher selbst mit korrekten IDs auf.

  PLAYER_A = 50_001_010 # nbv_ullrich, SeasonParticipation ohne status (= zaehlt mit)
  PLAYER_B = 50_001_011 # nbv_andresen, dito

  setup do
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
    TableMonitor.allow_change_tables = nil
    @next_id = Game::MIN_ID + 500
  end

  teardown do
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
    TableMonitor.allow_change_tables = nil
  end

  # ---------------------------------------------------------------------------
  # Hilfsmethoden
  # ---------------------------------------------------------------------------

  def next_id
    @next_id += 1
  end

  def create_game(id: next_id, tournament_id: nil, player_a_id: PLAYER_A, player_b_id: PLAYER_B)
    game = Game.create!(id: id, data: {}, gname: "trr_#{SecureRandom.hex(4)}", tournament_id: tournament_id)
    GameParticipation.create!(game_id: game.id, player_id: player_a_id, role: "playera")
    GameParticipation.create!(game_id: game.id, player_id: player_b_id, role: "playerb")
    game.reload
  end

  # `top:` fuellt die oberste Ebene von tm.data — dort stehen die gemeinsamen
  # Spielparameter (innings_goal, sets_to_play), waehrend discipline/balls_goal
  # pro Rolle liegen. Default leer, damit die Bestandstests unveraendert bleiben.
  def build_tm(game:, a: {}, b: {}, top: {})
    tm = TableMonitor.create!(
      state: "final_set_score",
      data: {
        "playera" => {"result" => 30, "innings" => 20, "hs" => 6, "balls_goal" => 30}.merge(a),
        "playerb" => {"result" => 24, "innings" => 20, "hs" => 4, "balls_goal" => 30}.merge(b)
      }.merge(top)
    )
    tm.update_columns(game_id: game.id)
    tm.reload
  end

  def record(tm)
    TableMonitor::TrainingResultRecorder.call(table_monitor: tm)
  end

  def gp(game, role)
    game.game_participations.find_by(role: role)
  end

  # Macht einen Spieler zum Gast, indem seine SeasonParticipation der laufenden
  # Saison auf status "guest" gesetzt wird (so legt das System Fremdclub-Gaeste an).
  def make_guest!(player_id)
    sp = SeasonParticipation.find_by(player_id: player_id, season_id: Season.current_season.id)
    assert_not_nil sp, "Fixture-Annahme: Spieler #{player_id} hat eine SeasonParticipation der laufenden Saison"
    sp.update!(status: "guest")
    sp
  end

  # ===========================================================================
  # A. Game.training-Scope (AC-2)
  # ===========================================================================

  test "A1: Game.training enthaelt lokale Spiele ohne Turnierbindung" do
    training = create_game
    assert_includes Game.training.pluck(:id), training.id
  end

  test "A2: Game.training schliesst Spiele mit Turnierbindung aus" do
    with_tournament = create_game(tournament_id: tournaments(:local).id)
    assert_not_includes Game.training.pluck(:id), with_tournament.id
  end

  test "A3: Game.training schliesst globale Spiele (id < MIN_ID) aus" do
    global = create_game(id: 4711)
    assert_not_includes Game.training.pluck(:id), global.id
  end

  # ===========================================================================
  # B. Wertberechnung (AC-3)
  # ===========================================================================

  test "B1: schreibt alle Statistikfelder beider Seiten" do
    game = create_game
    tm = build_tm(game: game)

    assert record(tm)

    game.reload
    a = gp(game, "playera")
    b = gp(game, "playerb")

    assert_equal 30, a.result
    assert_equal 20, a.innings
    assert_equal 6, a.hs
    assert_in_delta 1.5, a.gd, 0.001
    assert_equal 1, a.sets

    assert_equal 24, b.result
    assert_equal 20, b.innings
    assert_equal 4, b.hs
    assert_in_delta 1.2, b.gd, 0.001
    assert_equal 1, b.sets
  end

  test "B2: gd wird auf zwei Nachkommastellen gerundet" do
    game = create_game
    # 30 / 7 = 4.2857... -> 4.29
    tm = build_tm(game: game, a: {"result" => 30, "innings" => 7})

    record(tm)

    assert_in_delta 4.29, gp(game.reload, "playera").gd, 0.0001
  end

  test "B3: innings == 0 fuehrt zu gd 0.0 statt Division durch Null" do
    game = create_game
    tm = build_tm(game: game, a: {"result" => 0, "innings" => 0})

    record(tm)

    a = gp(game.reload, "playera")
    assert_equal 0.0, a.gd
    assert_predicate a.gd, :finite?
  end

  test "B4: Sieger erhaelt 2 Punkte, Verlierer 0" do
    game = create_game
    tm = build_tm(game: game)

    record(tm)

    game.reload
    assert_equal 2, gp(game, "playera").points
    assert_equal 0, gp(game, "playerb").points
  end

  test "B5: Gleichstand ergibt je einen Punkt" do
    game = create_game
    tm = build_tm(game: game, a: {"result" => 25}, b: {"result" => 25})

    record(tm)

    game.reload
    assert_equal 1, gp(game, "playera").points
    assert_equal 1, gp(game, "playerb").points
  end

  # ===========================================================================
  # C. Gast-Guard (AC-4)
  # ===========================================================================

  test "C1: Spiel mit einem Gast wird nicht verbucht" do
    make_guest!(PLAYER_B)
    game = create_game
    tm = build_tm(game: game)

    assert_not record(tm)

    game.reload
    assert_nil gp(game, "playera").result
    assert_nil gp(game, "playerb").result
  end

  test "C2: Guard legt keine Player- oder SeasonParticipation-Datensaetze an" do
    game = create_game
    tm = build_tm(game: game)

    assert_no_difference ["Player.count", "SeasonParticipation.count"] do
      record(tm)
    end
  end

  test "C3: Guard greift auch club-scoped ueber die Location des Tisches" do
    make_guest!(PLAYER_A)
    game = create_game
    tm = build_tm(game: game)
    # Tisch/Location anhaengen und Club-Verknuepfung mit KORREKTEN IDs aufbauen
    # (siehe Fixture-Hinweis oben) -> Club-Scope aktiv, Location#club = clubs.first
    table = tables(:one)
    table.update!(table_monitor_id: tm.id)
    ClubLocation.create!(club_id: clubs(:bcw).id, location_id: table.location_id, status: "active")
    tm.reload
    assert_equal clubs(:bcw).id, tm.table.location.club.id, "Club-Scope muss aufloesbar sein"

    assert_not record(tm)
    assert_nil gp(game.reload, "playera").result
  end

  # ===========================================================================
  # D. Passive / regulaere Mitglieder zaehlen (AC-4b)
  # ===========================================================================

  test "D1: SeasonParticipation ohne status (passiv gemeldet) zaehlt mit" do
    sp = SeasonParticipation.find_by(player_id: PLAYER_A, season_id: Season.current_season.id)
    assert_nil sp.status, "Fixture-Annahme: status ist nil"

    game = create_game
    assert record(build_tm(game: game))
    assert_equal 30, gp(game.reload, "playera").result
  end

  test "D2: status active zaehlt mit" do
    SeasonParticipation.find_by(player_id: PLAYER_A, season_id: Season.current_season.id).update!(status: "active")
    SeasonParticipation.find_by(player_id: PLAYER_B, season_id: Season.current_season.id).update!(status: "active")

    game = create_game
    assert record(build_tm(game: game))
    assert_equal 30, gp(game.reload, "playera").result
  end

  test "D3: status temporary zaehlt mit" do
    SeasonParticipation.find_by(player_id: PLAYER_A, season_id: Season.current_season.id).update!(status: "temporary")

    game = create_game
    assert record(build_tm(game: game))
    assert_equal 30, gp(game.reload, "playera").result
  end

  # ===========================================================================
  # E. No-op ausserhalb des Trainings (AC-5)
  # ===========================================================================

  test "E1: kein Schreiben wenn tournament_monitor gesetzt ist" do
    game = create_game
    tm = build_tm(game: game)
    # Stub statt Fixture: der Guard fragt nur `tournament_monitor.present?` ab —
    # ein echter TournamentMonitor braeuchte eine Turnier-Kette, die hier nichts beitraegt.
    tm.define_singleton_method(:tournament_monitor) { TournamentMonitor.new }

    assert_not record(tm)
    assert_nil gp(game.reload, "playera").result
  end

  test "E2: kein Schreiben fuer ein globales Spiel (id < MIN_ID)" do
    game = create_game(id: 4712)
    tm = build_tm(game: game)

    assert_not record(tm)
    assert_nil gp(game.reload, "playera").result
  end

  test "E3: kein Schreiben ohne Game" do
    tm = TableMonitor.create!(state: "final_set_score", data: {})
    assert_not record(tm)
  end

  # ===========================================================================
  # F. Idempotenz (AC-6)
  # ===========================================================================

  test "F1: zweifacher Aufruf liefert identische Werte und keine neuen Datensaetze" do
    game = create_game
    tm = build_tm(game: game)

    record(tm)
    first = gp(game.reload, "playera").attributes.slice("points", "result", "innings", "gd", "hs", "sets")

    assert_no_difference "GameParticipation.count" do
      record(tm)
    end

    second = gp(game.reload, "playera").attributes.slice("points", "result", "innings", "gd", "hs", "sets")
    assert_equal first, second
  end

  # ===========================================================================
  # G. Spielkontext ueberlebt die Finalisierung (Plan 02-01, AC-1/AC-2)
  #
  # Disziplin und Distanz stehen nur in table_monitors.data und werden vom
  # naechsten Spiel ueberschrieben. Ohne die Kopie ans Spiel traegt ein fertiges
  # Trainingsspiel keine Angabe darueber, WAS gespielt wurde.
  # ===========================================================================

  test "G1: Disziplin und balls_goal landen pro Teilnehmer am Spiel" do
    game = create_game
    tm = build_tm(
      game: game,
      a: {"discipline" => "Freie Partie klein", "balls_goal" => 40},
      b: {"discipline" => "Freie Partie klein", "balls_goal" => 30}
    )

    assert record(tm)

    a = gp(game.reload, "playera")
    b = gp(game.reload, "playerb")
    assert_equal "Freie Partie klein", a.data["discipline"]
    assert_equal "Freie Partie klein", b.data["discipline"]
    # Getrennt pro Rolle — bei Handicap sind die Distanzen verschieden.
    assert_equal 40, a.data["balls_goal"]
    assert_equal 30, b.data["balls_goal"]
  end

  test "G2: innings_goal und sets_to_play landen am Game" do
    game = create_game
    tm = build_tm(game: game, top: {"innings_goal" => 20, "sets_to_play" => 1})

    assert record(tm)

    game.reload
    assert_equal 20, game.data["innings_goal"]
    assert_equal 1, game.data["sets_to_play"]
  end

  test "G3: das Spiel bleibt nach dem Schreiben im Game.training-Scope" do
    game = create_game
    tm = build_tm(
      game: game,
      a: {"discipline" => "Cadre 35/2"},
      top: {"innings_goal" => 20, "sets_to_play" => 1}
    )

    assert record(tm)

    game.reload
    assert_includes Game.training.pluck(:id), game.id
    # Der Scope filtert per LIKE auf "external_id" in der serialisierten Textspalte —
    # der Recorder darf diesen Schluessel unter keinen Umstaenden erzeugen.
    assert_not_includes game.data.keys, "external_id"
    assert_not_includes game.read_attribute_before_type_cast(:data).to_s, "external_id"
  end

  test "G4: vorhandene data-Schluessel bleiben erhalten" do
    game = create_game
    gp(game, "playera").update!(data: {"note" => "vorher da"})
    game.update!(data: {"note" => "vorher da"})
    tm = build_tm(game: game, a: {"discipline" => "Einband"}, top: {"innings_goal" => 15})

    assert record(tm)

    assert_equal "vorher da", gp(game.reload, "playera").data["note"]
    assert_equal "Einband", gp(game.reload, "playera").data["discipline"]
    assert_equal "vorher da", game.reload.data["note"]
    assert_equal 15, game.data["innings_goal"]
  end

  test "G5: fehlende Kontextangaben werden weggelassen, nicht als nil geschrieben" do
    game = create_game
    # build_tm setzt balls_goal, aber weder discipline noch die Top-Level-Ziele.
    tm = build_tm(game: game)

    assert record(tm)

    a = gp(game.reload, "playera")
    assert_not_includes a.data.keys, "discipline"
    assert_equal 30, a.data["balls_goal"]
    assert_not_includes game.reload.data.keys, "innings_goal"
    assert_not_includes game.data.keys, "sets_to_play"
  end

  test "G6: Laufzeitzustand des Monitors wandert nicht mit ans Spiel" do
    game = create_game
    tm = build_tm(
      game: game,
      a: {"discipline" => "Dreiband", "innings_list" => [1, 0, 2], "innings_redo_list" => []},
      top: {"innings_goal" => 20, "balls_counter_stack" => [15, -25], "current_left_player" => "playera"}
    )

    assert record(tm)

    a = gp(game.reload, "playera")
    assert_equal "Dreiband", a.data["discipline"]
    assert_not_includes a.data.keys, "innings_list"
    assert_not_includes game.reload.data.keys, "balls_counter_stack"
    assert_not_includes game.data.keys, "current_left_player"
  end

  test "G7: kein Kontext bei Gastbeteiligung — der Guard greift zuerst" do
    game = create_game
    make_guest!(PLAYER_B)
    tm = build_tm(game: game, a: {"discipline" => "Freie Partie klein"}, top: {"innings_goal" => 20})

    assert_not record(tm)

    assert_nil gp(game.reload, "playera").data["discipline"]
    assert_nil game.reload.data["innings_goal"]
  end

  test "G8: zweifacher Aufruf schreibt denselben Kontext" do
    game = create_game
    tm = build_tm(game: game, a: {"discipline" => "Einband"}, top: {"innings_goal" => 20})

    record(tm)
    first = gp(game.reload, "playera").data.dup
    first_game = game.data.dup

    record(tm)

    assert_equal first, gp(game.reload, "playera").data
    assert_equal first_game, game.reload.data
  end
end
