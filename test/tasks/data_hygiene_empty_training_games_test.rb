# frozen_string_literal: true

require "test_helper"
require "rake"

# Tests fuer `data_hygiene:empty_training_games` (Milestone v0.3, Plan 02-01).
#
# Der Task entfernt substanzlose Trainingsspiele — Zeilen aus Game.training, die weder
# Teilnehmer mit Spieler noch Ergebnis, ended_at, Turnierbindung oder external_id tragen.
# Erzeuger war die Spielerauswahl am Scoreboard: jeder Aufruf von `sb_state=free_game`
# legt ein Game an (locations_controller.rb:170), ohne Spielerparameter eines ohne jeden
# Teilnehmer. Gemessen 2026-08-29 in der Dev-DB: 20 von 28.
#
# ⚠️ Der Schwerpunkt dieser Tests liegt NICHT auf dem Loeschen, sondern auf dem
# Nicht-Loeschen. Im UAT zu Plan 01-02 hat ein zu weit greifender Loeschzweig real
# Spiel 50000503 gekostet; jede Substanz-Form bekommt hier ihren eigenen Test.
#
# ⚠️ IDs: in der Test-DB startet die games-Sequence bei 1, in Dev/Produktion oberhalb
# von MIN_ID. Trainings-Games werden hier daher mit EXPLIZITER id >= Game::MIN_ID
# angelegt — sonst greift der Game.training-Scope nicht.
class DataHygieneEmptyTrainingGamesTest < ActiveSupport::TestCase
  fixtures :players, :tournaments

  BASE_ID = Game::MIN_ID + 20_100

  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    ENV.delete("ARMED")
    @next_id = BASE_ID
    @player = Player.create!(id: BASE_ID + 900, lastname: "Hygiene", firstname: "Test")
  end

  teardown do
    ENV.delete("ARMED")
    Rake::Task.clear
  end

  # ---------------------------------------------------------------------------
  # Hilfsmethoden
  # ---------------------------------------------------------------------------

  def next_id
    @next_id += 1
  end

  def create_game(id: next_id, **attrs)
    Game.create!({id: id, data: {}, gname: "hyg_#{SecureRandom.hex(4)}"}.merge(attrs))
  end

  def run_task
    Rake::Task["data_hygiene:empty_training_games"].reenable
    Rake::Task["data_hygiene:empty_training_games"].invoke
  end

  # ---------------------------------------------------------------------------
  # A. DRY-RUN als Default
  # ---------------------------------------------------------------------------

  test "A1: DRY-RUN meldet die Kandidaten und aendert nichts" do
    empty = create_game
    before = Game.count

    out = capture_io { run_task }.first

    assert_equal before, Game.count, "DRY-RUN darf nichts loeschen"
    assert Game.exists?(empty.id)
    assert_match(/DRY-RUN/, out)
    assert_match(/id=#{empty.id}/, out)
  end

  test "A2: ohne Kandidaten meldet der Task Idempotenz" do
    # Nur ein Spiel mit Substanz im Bestand.
    create_game(ended_at: Time.current)
    Game.training.reject(&:substanceless?) # Absicherung der Vorbedingung
    substanzlos = Game.training.select(&:substanceless?)
    substanzlos.each(&:destroy)

    out = capture_io { run_task }.first
    assert_match(/Nichts zu tun \(idempotent\)/, out)
  end

  # ---------------------------------------------------------------------------
  # B. ARMED loescht genau die substanzlosen
  # ---------------------------------------------------------------------------

  test "B1: ARMED entfernt das substanzlose Spiel" do
    empty = create_game
    ENV["ARMED"] = "1"

    capture_io { run_task }

    assert_not Game.exists?(empty.id), "substanzloses Trainingsspiel muss weg sein"
  end

  test "B2: zweiter Lauf ist folgenlos (idempotent)" do
    create_game
    ENV["ARMED"] = "1"
    capture_io { run_task }
    after_first = Game.count

    out = capture_io { run_task }.first

    assert_equal after_first, Game.count
    assert_match(/Nichts zu tun \(idempotent\)/, out)
  end

  # ---------------------------------------------------------------------------
  # C. Was ueberleben MUSS (AC-6, zweite Haelfte)
  # ---------------------------------------------------------------------------

  test "C1: Spiel mit zugeordnetem Spieler ueberlebt" do
    game = create_game
    GameParticipation.create!(game_id: game.id, player_id: @player.id, role: "playera")
    ENV["ARMED"] = "1"

    capture_io { run_task }

    assert Game.exists?(game.id)
  end

  test "C2: Spiel mit Ergebnis ueberlebt, auch ohne Spielerbezug" do
    # Genau der Fall aus dem Deferred Issue "Trainingsstatistik von Gastspielern ist
    # fluechtig": remove_inactive_guests nullifiziert player_id, das Ergebnis bleibt.
    game = create_game
    GameParticipation.create!(game_id: game.id, player_id: nil, role: "playera", result: 40)
    ENV["ARMED"] = "1"

    capture_io { run_task }

    assert Game.exists?(game.id), "ein verbuchtes Ergebnis ist Substanz, auch ohne Spieler"
  end

  test "C3: beendetes Spiel ueberlebt" do
    game = create_game(ended_at: Time.current)
    ENV["ARMED"] = "1"

    capture_io { run_task }

    assert Game.exists?(game.id)
  end

  test "C4: Turnierspiel ueberlebt — es faellt schon aus Game.training heraus" do
    game = create_game(tournament_id: tournaments(:local).id)
    ENV["ARMED"] = "1"

    capture_io { run_task }

    assert Game.exists?(game.id)
  end

  test "C5: App-gesteuertes Turnierspiel (external_id) ueberlebt" do
    game = create_game(data: {"external_id" => "abc-123"})
    ENV["ARMED"] = "1"

    capture_io { run_task }

    assert Game.exists?(game.id)
  end

  test "C6: globales Spiel unterhalb MIN_ID wird nie angefasst" do
    game = create_game(id: 4712)
    ENV["ARMED"] = "1"

    capture_io { run_task }

    assert Game.exists?(game.id), "Game.training grenzt auf lokale Spiele ein"
  end

  # ---------------------------------------------------------------------------
  # D. Der Scope bleibt der Task-Grenzstein
  # ---------------------------------------------------------------------------

  test "D1: die Auswahl deckt sich mit Game#substanceless? auf Game.training" do
    leer = create_game
    voll = create_game(ended_at: Time.current)
    ENV["ARMED"] = "1"

    capture_io { run_task }

    assert_not Game.exists?(leer.id)
    assert Game.exists?(voll.id)
  end
end
