# frozen_string_literal: true

require "test_helper"

# Milestone v0.3 Plan 02-02 — umgekehrter Bedienablauf und Kopfgruppe "Zuletzt"
# auf der Schnellstart-Seite (LocationsController#show, sb_state=free_game).
#
# Vor 02-02: Spieler waehlen, dann Spiel-Knopf druecken (der bis dahin `disabled` war).
# Ab 02-02: Spiel-Knopf druecken oeffnet die Spielerauswahl, erst dort wird gestartet.
# Nur so sind Disziplin und Distanz bekannt, wenn die Auswahl aufgeht — Voraussetzung
# fuer das parameterbezogene Ranking.
#
# Testhinweise (uebernommen aus locations_terminate_finalize_test.rb):
#   - Ein User ist angemeldet, damit set_location nicht in den Scoreboard-Bypass laeuft.
#   - ⚠️ Games mit EXPLIZITER id >= Game::MIN_ID: in der Test-DB startet die Sequence
#     bei 1, und Game.training verlangt lokale IDs.
#   - ⚠️ Die Club-Verknuepfung der Location wird explizit aufgebaut; club_locations.yml
#     verknuepft ueber Label-Verweise, die die expliziten Club-IDs verfehlen.
class LocationsFreeGameRankingTest < ActionDispatch::IntegrationTest
  # VORBEUGEND (nicht als Ursache eines konkreten Fehlers belegt):
  # `LocalProtector` aktiviert `has_paper_trail` nur, solange
  # `Carambus.config.carambus_api_url` LEER ist (local_protector.rb:29) — ausgewertet
  # beim KLASSENLADEN. In der Testumgebung laden Modelle lazy
  # (`config.eager_load = false`, config/environments/test.rb:4). Wuerde ein Modell
  # erstmals geladen, waehrend die Config im setup gesetzt ist, bliebe PaperTrail
  # fuer den restlichen Lauf deaktiviert. Alles vorher zu laden schliesst das aus.
  #
  # ⚠️ Ehrlichkeitshalber: die beim Diagnostizieren beobachteten
  # `undefined method 'versions'`-Fehler treten auch OHNE diese Testdatei auf
  # (gemessen 2026-08-29) — sie sind vorbestehend, nicht von hier verursacht.
  Rails.application.eager_load!

  setup do
    # ⚠️ PFLICHT, nicht Kosmetik: Der gesamte Scoreboard-Zweig von
    # LocationsController#show haengt an `if local_server?`
    # (locations_controller.rb:116); dessen else-Zweig ist ein stiller
    # `redirect_back(fallback_location: root_path)` (Zeile 317) — ohne Flash, mit
    # angemeldetem User. `local_server?` liest `Carambus.config.carambus_api_url`,
    # also GLOBALEN Zustand, den andere Tests umschreiben (test/models/version_test.rb,
    # test/models/table_monitor/options_presenter_test.rb).
    #
    # Ohne dieses Setzen war die ganze Klasse im Suite-Vollauf mit Seed 777 rot
    # (302 statt 200), isoliert aber gruen — diagnostiziert am 2026-08-29.
    # Dieselbe Ursache steckt hinter den vorbestehenden
    # TournamentsControllerTest-Fehlern "auf dem API-Server wird abgewiesen".
    @original_config = Carambus.config
    Carambus.config = OpenStruct.new(@original_config.to_h.merge(carambus_api_url: "http://localhost:3131"))

    sign_in users(:admin)
    @location = locations(:one)
    @table = @location.tables.first
    @club = clubs(:bcw)
    ClubLocation.find_or_create_by!(club_id: @club.id, location_id: @location.id) do |cl|
      cl.status = "active"
    end
    @location.reload

    @player_a = create_member(50_100_711, "RankA")
    @player_b = create_member(50_100_712, "RankB")
    @next_id = Game::MIN_ID + 40_000
  end

  teardown do
    Carambus.config = @original_config if @original_config
    GameParticipation.where(player: [@player_a, @player_b].compact).destroy_all
    Game.where("created_at > ?", 1.minute.ago).destroy_all
    SeasonParticipation.where(player_id: [@player_a&.id, @player_b&.id].compact).destroy_all
    Player.where(id: [@player_a&.id, @player_b&.id].compact).destroy_all

    # ⚠️ PFLICHT, nicht Kosmetik: Der free_game-Zweig ruft Player.default_guest auf,
    # und die Methode LEGT fehlende Gast-Records an (player.rb:159-164) und merkt sie
    # sich in der Klassen-Instanzvariablen @default_guest (player.rb:81) — die
    # ueberlebt den Transaktions-Rollback dieses Tests. Ohne Ruecksetzen bekommen
    # nachfolgende Tests eine SeasonParticipation, die es nicht mehr gibt.
    # Belegt per Bisect 2026-08-29: ohne diese Zeile bricht der Suite-Vollauf ab.
    Player.instance_variable_set(:@default_guest, {a: {}, b: {}})
    ClubLocation.where(club_id: @club&.id, location_id: @location&.id).destroy_all
  end

  def create_member(id, lastname)
    player = Player.create!(id: id, firstname: "Test", lastname: lastname)
    SeasonParticipation.create!(player_id: player.id, club_id: @club.id,
      season_id: Season.current_season.id, status: "active")
    player
  end

  def get_free_game
    get location_path(@location, sb_state: "free_game", table_id: @table.id)
    # Frueherkennung: ein 302 hier bedeutet fast immer, dass local_server? false war
    # (siehe setup). Ohne diese Meldung schlagen die Assertions kryptisch fehl.
    assert_not_equal 302, response.status,
      "Redirect statt Scoreboard — steht Carambus.config.carambus_api_url? (local_server?-Zweig)"
  end

  # ---------------------------------------------------------------------------
  # A. Ablaufumkehr (AC-4)
  # ---------------------------------------------------------------------------

  test "A1: Schnellstart-Seite rendert" do
    get_free_game
    assert_response :success
  end

  test "A2: die Spiel-Knoepfe sind nicht mehr deaktiviert" do
    get_free_game

    assert_select "button.quick-start-btn", minimum: 1, &:present?
    assert_select "button.quick-start-btn[disabled]", 0,
      "seit 02-02 ist der Knopf der Einstieg in die Auswahl, nicht ihr Abschluss"
  end

  test "A3: die Knoepfe sind keine Submits mehr" do
    get_free_game

    assert_select "input[type=submit].quick-start-btn", 0,
      "der Knopf darf das Formular nicht mehr direkt abschicken"
    assert_select "button.quick-start-btn[type=button]", minimum: 1
  end

  test "A4: jeder Knopf traegt sein Formular und seinen Ranking-Schluessel" do
    get_free_game

    assert_select "button.quick-start-btn" do |buttons|
      buttons.each do |btn|
        assert btn["data-form-id"].present?, "ohne form-id findet der Start sein Formular nicht"
        assert btn.attributes.key?("data-ranking-key"), "ohne ranking-key bleibt die Kopfgruppe leer"
      end
    end
  end

  test "A5: die Formulare mit den Spielparametern bleiben erhalten" do
    get_free_game

    assert_select "form[action=?]", start_game_table_monitor_path(@table.table_monitor), minimum: 1
    assert_select "input[type=hidden][name=discipline_a]", minimum: 1
  end

  # ---------------------------------------------------------------------------
  # B. Startknopf im Modal (AC-5)
  # ---------------------------------------------------------------------------

  test "B1: das Modal hat einen Startknopf und einen Abbrechen-Knopf" do
    get_free_game

    assert_select "#start_selected_game", 1
    assert_select "#cancel", 1
  end

  test "B2: der Startknopf ruft start_selected_game auf" do
    get_free_game
    assert_select "#start_selected_game[href=?]", "javascript:start_selected_game()"
  end

  # ---------------------------------------------------------------------------
  # C. Kopfgruppe (AC-6)
  # ---------------------------------------------------------------------------

  test "C1: der Container fuer die Kopfgruppe ist vorhanden und initial versteckt" do
    get_free_game

    assert_select "#recent-players.hidden", 1,
      "ohne beruehrten Knopf darf keine Kopfgruppe sichtbar sein"
  end

  test "C2: ohne Trainingshistorie bleiben die Ranglisten leer" do
    get_free_game

    assert_match(/window\.recentPlayersByPreset\s*=/, response.body)
    # Jede Kombination ist vorhanden, aber unbesetzt.
    assert_no_match(/window\.recentPlayersByPreset\s*=\s*\{[^}]*\[\s*\d/, response.body)
  end

  test "C3: nach einem gewerteten Trainingsspiel erscheinen dessen Spieler unter dem passenden Schluessel" do
    # Vorbedingung absichern: ohne echte Presets waere dieser Test wertlos.
    assert karambol_discipline.present?,
      "Fixture-/Config-Annahme: die Tischart hat mindestens ein Preset mit Disziplin"

    create_training_game(discipline: karambol_discipline, balls_goal: karambol_balls_goal)

    get_free_game

    rankings = JSON.parse(ranking_json)
    key = TrainingPartnerRanking.preset_key(karambol_discipline, karambol_balls_goal)
    assert rankings.key?(key), "erwarteter Schluessel #{key.inspect} fehlt in #{rankings.keys.inspect}"
    assert_equal [@player_a.id, @player_b.id].sort, rankings[key].sort,
      "genau die beiden Spieler des Trainingsspiels gehoeren unter diesen Schluessel"
  end

  test "C3b: ein Preset mit anderer Distanz erhaelt dieselben Spieler nur ueber den Fallback" do
    assert karambol_discipline.present?
    create_training_game(discipline: karambol_discipline, balls_goal: karambol_balls_goal)

    get_free_game

    rankings = JSON.parse(ranking_json)
    andere = rankings.keys.reject { |k| k == TrainingPartnerRanking.preset_key(karambol_discipline, karambol_balls_goal) }
    assert andere.any?, "die Tischart muss mehr als ein Preset haben, sonst prueft dieser Test nichts"
    # Die Kaskade sorgt dafuer, dass auch andere Presets nicht leer ausgehen —
    # genau das haelt die Kopfgruppe im Kaltstart brauchbar.
    assert andere.any? { |k| rankings[k].include?(@player_a.id) },
      "die Fallback-Kaskade muss den Spieler auch unter abweichenden Parametern liefern"
  end

  test "C4: die Namen der Auswahlliste werden mitgeliefert" do
    get_free_game
    assert_match(/window\.playerNamesById\s*=/, response.body)
  end

  test "C5: die Vollliste enthaelt jeden Spieler genau einmal" do
    create_training_game(discipline: karambol_discipline, balls_goal: karambol_balls_goal)

    get_free_game

    # Der Spieler steht im Ranking UND weiterhin in der Vollliste — die Kopfgruppe ist
    # eine Abkuerzung, kein Ersatz.
    assert_select "button.player-choice[data-player-id=?]", @player_a.id.to_s, 1
    assert_select "button.player-choice[data-player-id=?]", @player_b.id.to_s, 1
  end

  # ---------------------------------------------------------------------------
  # D. Eine Liste statt A/B-Spalten, Paarungszeile (AC-6 bis AC-8)
  #
  # Betreiber-Erkenntnis am Checkpoint 2026-08-29: die A/B-Zuordnung ist bei der
  # Auswahl bedeutungslos, weil das Ausstossen die Reihenfolge bestimmt.
  # ---------------------------------------------------------------------------

  test "D1: es gibt keine A/B-Radiobuttons mehr" do
    get_free_game

    assert_select "input[type=radio][name=player_a_id]", 0,
      "die zweispaltige A/B-Eingabe ist entfallen"
    assert_select "input[type=radio][name=player_b_id]", 0
  end

  test "D2: jeder Spieler erscheint genau einmal als Auswahlknopf" do
    get_free_game

    ids = css_select("button.player-choice").map { |b| b["data-player-id"] }
    assert ids.any?, "die Auswahlliste darf nicht leer sein"
    assert_equal ids.uniq.size, ids.size,
      "in EINER Liste darf kein Spieler doppelt stehen (frueher je einmal fuer A und B)"
  end

  test "D3: die Paarungszeile hat zwei anklickbare Plaetze" do
    get_free_game

    assert_select "#pairing_slot_0", 1
    assert_select "#pairing_slot_1", 1
    assert_select "#pairing_slot_0[onclick=?]", "clear_pairing_slot(0)", 1
    assert_select "#pairing_slot_1[onclick=?]", "clear_pairing_slot(1)", 1
  end

  test "D4: die Auswahl startet leer — keine Gast-Vorbelegung mehr" do
    get_free_game

    assert_select "input[type=hidden][id=player_a_id][value=?]", "", 1,
      "eine Paarungszeile, die sich aufbaut, darf nicht vorbelegt starten"
    assert_select "input[type=hidden][id=player_b_id][value=?]", "", 1
  end

  test "D5: der Vorab-Knopf und die Spieler-Anzeige sind entfallen" do
    get_free_game

    assert_select "#select_players_btn", 0
    assert_select "#player_a_name", 0
    assert_select "#player_b_name", 0
  end

  # ---------------------------------------------------------------------------
  # Hilfsmethoden
  # ---------------------------------------------------------------------------

  # Erste Preset-Kombination der Tischart — genau die, fuer die der Controller
  # eine Rangliste vorberechnet.
  def first_preset
    key = case @table.table_kind&.name.to_s
    when /Pool/i then "pool"
    when /Snooker/i then "snooker"
    when /klein/i, /Small/i then "small_billard"
    when /groß|gross/i, /Match/i then "match_billard"
    else "small_billard"
    end
    groups = Carambus.config.quick_game_presets&.dig(key) || []
    buttons = groups.filter_map { |g| g.is_a?(Hash) ? g["buttons"] : nil }.flatten.compact
    TrainingPartnerRanking.params_from_preset(buttons.first || {})
  end

  def karambol_discipline = first_preset[:discipline]

  def karambol_balls_goal = first_preset[:balls_goal]

  def create_training_game(discipline:, balls_goal:)
    @next_id += 1
    game = Game.create!(id: @next_id, data: {}, gname: "rank_#{SecureRandom.hex(3)}")
    [[@player_a, "playera"], [@player_b, "playerb"]].each do |player, role|
      GameParticipation.create!(game: game, player: player, role: role, result: 40,
        data: {"discipline" => discipline, "balls_goal" => balls_goal}.compact)
    end
    game
  end

  def ranking_json
    response.body[/window\.recentPlayersByPreset\s*=\s*(\{.*?\});/m, 1].to_s
  end
end
