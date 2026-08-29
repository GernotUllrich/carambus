# frozen_string_literal: true

require "test_helper"

# Milestone v0.3 Plan 02-03 — Spielerauswahl auf der DETAILSEITE
# (LocationsController#show, sb_state=free_game_detail).
#
# Unterschied zum Schnellstart (Plan 02-02): Hier bleibt der Ablauf "erst Spieler, dann
# Parameter" — auf der Detailseite werden Disziplin und Punktziel JE SPIELER gesetzt,
# und das ist eindeutig, sobald die Namen feststehen. Der Link "Spieler-Auswahl" bleibt,
# das Bestaetigen im Modal startet KEIN Spiel.
#
# ⚠️ Carambus.config: der gesamte Scoreboard-Zweig haengt an `local_server?`
# (locations_controller.rb:116), dessen else-Zweig ein stiller redirect_back ist.
# `local_server?` liest Carambus.config — globalen Zustand, den andere Tests umschreiben.
# Ohne das Setzen unten haengt das Ergebnis davon ab, welcher Test vorher lief
# (Befund und Diagnose in Plan 02-02).
class LocationsFreeGameDetailTest < ActionDispatch::IntegrationTest
  Rails.application.eager_load!

  setup do
    @original_config = Carambus.config
    Carambus.config = OpenStruct.new(@original_config.to_h.merge(carambus_api_url: "http://localhost:3131"))

    sign_in users(:admin)
    @location = locations(:one)
    @table = @location.tables.first
    # ⚠️ Der Fixture-Tisch traegt die Tischart "Karambol", die in
    # TableKind::TABLE_KIND_FREE_GAME_SETUP (table_kind.rb:29) NICHT vorkommt — der
    # Detail-Zweig baut den Templatenamen daraus zusammen und rendert sonst
    # "scoreboard_free_game_" (leerer Suffix) => MissingTemplate => 500.
    # Hier auf eine unterstuetzte Art setzen; der zugrundeliegende Defekt (unbekannte
    # Tischart ergibt 500 statt Fehlermeldung) ist als Deferred Issue notiert.
    @table.table_kind.update!(name: "Small Billard")
    @table.reload
    @club = clubs(:bcw)
    ClubLocation.find_or_create_by!(club_id: @club.id, location_id: @location.id) do |cl|
      cl.status = "active"
    end
    @location.reload

    @player_a = create_member(50_100_811, "DetailA")
    @player_b = create_member(50_100_812, "DetailB")
    @next_id = Game::MIN_ID + 50_000
  end

  teardown do
    Carambus.config = @original_config if @original_config
    GameParticipation.where(player: [@player_a, @player_b].compact).destroy_all
    Game.where("created_at > ?", 1.minute.ago).destroy_all
    SeasonParticipation.where(player_id: [@player_a&.id, @player_b&.id].compact).destroy_all
    Player.where(id: [@player_a&.id, @player_b&.id].compact).destroy_all
    # Der free_game-Zweig ruft Player.default_guest, das Records ANLEGT und in einer
    # Klassen-Instanzvariablen behaelt — die ueberlebt den Transaktions-Rollback.
    Player.instance_variable_set(:@default_guest, {a: {}, b: {}})
    ClubLocation.where(club_id: @club&.id, location_id: @location&.id).destroy_all
  end

  def create_member(id, lastname)
    player = Player.create!(id: id, firstname: "Test", lastname: lastname)
    SeasonParticipation.create!(player_id: player.id, club_id: @club.id,
      season_id: Season.current_season.id, status: "active")
    player
  end

  def get_detail
    get location_path(@location, sb_state: "free_game_detail", table_id: @table.id)
    assert_not_equal 302, response.status,
      "Redirect statt Detailseite — steht Carambus.config.carambus_api_url? (local_server?-Zweig)"
  end

  # ---------------------------------------------------------------------------
  # A. Eine Liste statt A/B-Spalten (AC-1)
  # ---------------------------------------------------------------------------

  test "A1: Detailseite rendert" do
    get_detail
    assert_response :success
  end

  test "A2: keine A/B-Radiobuttons mehr" do
    get_detail

    assert_select "input[type=radio][name=player_a_id]", 0,
      "die zweispaltige A/B-Eingabe ist entfallen"
    assert_select "input[type=radio][name=player_b_id]", 0
  end

  test "A3: jeder Spieler erscheint genau einmal als Auswahlknopf" do
    get_detail

    ids = css_select("button.player-choice").map { |b| b["data-player-id"] }
    assert ids.any?, "die Auswahlliste darf nicht leer sein"
    assert_equal ids.uniq.size, ids.size,
      "in EINER Liste darf kein Spieler doppelt stehen"
    assert_includes ids, @player_a.id.to_s
  end

  # ---------------------------------------------------------------------------
  # B. Paarungszeile (AC-2)
  # ---------------------------------------------------------------------------

  test "B1: die Paarungszeile hat zwei anklickbare Plaetze" do
    get_detail

    assert_select "#pairing_slot_0[onclick=?]", "clear_pairing_slot(0)", 1
    assert_select "#pairing_slot_1[onclick=?]", "clear_pairing_slot(1)", 1
  end

  test "B2: Kopfgruppen-Container vorhanden und initial versteckt" do
    get_detail
    assert_select "#recent-players.hidden", 1
  end

  # ---------------------------------------------------------------------------
  # C. Bestaetigen startet NICHT, der Auswahl-Link bleibt (AC-3)
  # ---------------------------------------------------------------------------

  test "C1: der Link zur Spielerauswahl bleibt erhalten" do
    get_detail
    assert_match(/javascript:players_mode\(\)/, response.body,
      "auf der Detailseite bleibt der Auswahl-Link — anders als im Schnellstart")
  end

  test "C2: es gibt keinen Startknopf im Auswahl-Modal" do
    get_detail
    assert_select "#start_selected_game", 0,
      "die Detailseite startet ueber ihren eigenen Weg, nicht aus dem Modal"
  end

  test "C3: die Dropdowns bleiben als Traeger der Auswahl" do
    get_detail
    assert_select "select#player_a_id", 1
    assert_select "select#player_b_id", 1
  end

  test "C4: die Dropdowns ziehen die Paarungszeile nach" do
    get_detail
    assert_select "select#player_a_id[onchange=?]", "sync_pairing_from_selects()", 1
    assert_select "select#player_b_id[onchange=?]", "sync_pairing_from_selects()", 1
  end

  # ---------------------------------------------------------------------------
  # D. Parameter-Header tragen die Namen (AC-4)
  # ---------------------------------------------------------------------------

  test "D1: keine literalen (A)/(B)-Header mehr bei Disziplin und Punktziel" do
    get_detail

    assert_no_match(/Disziplin \(A\)/, response.body)
    assert_no_match(/Disziplin \(B\)/, response.body)
    assert_no_match(/Punktziel \(A\)/, response.body)
    assert_no_match(/Punktziel \(B\)/, response.body)
  end

  test "D2: die Header binden den Namen reaktiv ein" do
    get_detail

    # Das Partial haengt den Namen per x-text an; ohne Auswahl faellt es auf A/B zurueck.
    assert_match(/x-text="name_a \|\| 'A'"/, response.body)
    assert_match(/x-text="name_b \|\| 'B'"/, response.body)
  end

  test "D3: das Alpine-Modell fuehrt beide Namen" do
    get_detail

    assert_select "#free_game_params", 1
    assert_match(/name_a:/, response.body)
    assert_match(/name_b:/, response.body)
  end

  test "D4: spielerunabhaengige Header bleiben ohne Namen" do
    get_detail

    # "Sätze (best of)" und "Mehrsatzspiel" gelten fuer beide Spieler — dort waere
    # ein Name schlicht falsch.
    assert_match(/Mehrsatzspiel/, response.body)
    assert_no_match(/Mehrsatzspiel<span x-text/, response.body)
  end

  # ---------------------------------------------------------------------------
  # F. Anlage-Dialog mit Wahl passiv/Gast (Plan 02-04, AC-1)
  # ---------------------------------------------------------------------------

  test "F1: der Anlage-Dialog bietet beide Statusarten an" do
    get_detail

    assert_select "#modal-new-player", 1
    assert_select "input[type=radio][name=participation_status][value=guest]", 1
    assert_select "input[type=radio][name=participation_status][value=passive]", 1
  end

  test "F2: Gast ist vorbelegt" do
    get_detail

    assert_select "input[type=radio][name=participation_status][value=guest][checked]", 1,
      "der haeufigere Fall am Tisch ist der Gast"
    assert_select "input[type=radio][name=participation_status][value=passive][checked]", 0
  end

  test "F3: die Beschriftungen kommen aus der Uebersetzung" do
    get_detail

    assert_match(/#{Regexp.escape(I18n.t("location.new_player.as_guest"))}/, response.body)
    assert_match(/#{Regexp.escape(I18n.t("location.new_player.as_passive"))}/, response.body)
    assert_no_match(/Anmeldung eines Gasts/, response.body,
      "die alte hartkodierte Ueberschrift ist ersetzt")
  end

  # ---------------------------------------------------------------------------
  # E. Ranking und Namensdarstellung (AC-1, Sortierung)
  # ---------------------------------------------------------------------------

  test "E1: das Ranking wird ohne Parameterbezug mitgeliefert" do
    get_detail
    assert_match(/window\.recentPlayers\s*=/, response.body)
    assert_match(/window\.playerNamesById\s*=/, response.body)
  end

  test "E2: nach einem gewerteten Trainingsspiel erscheinen dessen Spieler im Ranking" do
    game = Game.create!(id: @next_id + 1, data: {}, gname: "det_#{SecureRandom.hex(3)}")
    [[@player_a, "playera"], [@player_b, "playerb"]].each do |player, role|
      GameParticipation.create!(game: game, player: player, role: role, result: 40,
        data: {"discipline" => "Freie Partie klein", "balls_goal" => 40})
    end

    get_detail

    ranking = response.body[/window\.recentPlayers\s*=\s*(\[.*?\]);/m, 1].to_s
    ids = JSON.parse(ranking.presence || "[]")
    assert_includes ids, @player_a.id,
      "ohne Parameterbezug muss die dritte Kaskadenstufe greifen"
    assert_includes ids, @player_b.id
  end

  test "E3: Namen erscheinen als 'Vorname Nachname'" do
    get_detail
    assert_match(/Test DetailA/, response.body,
      "fl_name statt fullname — Sortierung und Anzeige duerfen nicht auseinanderlaufen")
  end
end
