# frozen_string_literal: true

require "test_helper"

# Der Kalender-Link auf der Scoreboard-Welcome-Page (LocationsController#show,
# sb_state=welcome). An einem Spielort mit nur EINER Tischart-Sparte traegt er sie als
# `branch` mit; an einem gemischten Ort nicht.
class LocationsWelcomeCalendarLinkTest < ActionDispatch::IntegrationTest
  setup do
    # ⚠️ PFLICHT: der ganze Scoreboard-Zweig haengt an `if local_server?`
    # (locations_controller.rb:116), dessen else-Zweig ein STILLER redirect_back ist.
    # `local_server?` liest Carambus.config — globalen Zustand, den andere Tests
    # umschreiben (version_test.rb, options_presenter_test.rb). Muster aus
    # locations_free_game_ranking_test.rb.
    @original_config = Carambus.config
    Carambus.config = OpenStruct.new(@original_config.to_h.merge(carambus_api_url: "http://localhost:3131"))

    sign_in users(:admin)
    @location = locations(:one)
    @location.tables.destroy_all
    @next_table_id = 50_910_000
  end

  teardown do
    Carambus.config = @original_config
  end

  def table_kind!(name)
    TableKind.find_or_create_by!(name: name) { |tk| tk.short = name.first(2) }
  end

  def tisch!(kind_name)
    @next_table_id += 1
    Table.create!(id: @next_table_id, name: "Tisch #{@next_table_id}",
      location: @location, table_kind: table_kind!(kind_name))
  end

  def welcome!
    get location_url(@location, sb_state: "welcome")
  end

  test "die Welcome-Page traegt einen Link zum Terminkalender" do
    tisch!("Match Billard")

    welcome!
    assert_response :success
    assert_select "a#calendar", {count: 1}, "genau ein Kalender-Knopf"
  end

  # Der Fall BC Wedel: kleines und Match Billard sind beide doppelt belegt.
  test "ein Karambol-Ort schraenkt auf Karambol UND Kegel ein" do
    tisch!("Match Billard")
    tisch!("Small Billard")

    welcome!
    assert_response :success
    assert_select "a#calendar[href=?]", calendar_path(branch: "Karambol,Kegel")
  end

  # Der Fall Pinneberg: hier greift der Filter jetzt ebenfalls.
  test "ein Pool-und-Snooker-Ort schraenkt auf genau diese beiden ein" do
    tisch!("Pool")
    tisch!("Snooker")

    welcome!
    assert_response :success
    assert_select "a#calendar[href=?]", calendar_path(branch: "Pool,Snooker")
  end

  test "ein Ort ohne Tische verlinkt den Kalender ohne Einschraenkung" do
    welcome!
    assert_response :success
    assert_select "a#calendar[href=?]", calendar_path
  end

  test "ein Ort, der alle Sparten abdeckt, verlinkt ohne Einschraenkung" do
    tisch!("Pool")
    tisch!("Snooker")
    tisch!("Small Billard")

    welcome!
    assert_response :success
    assert_select "a#calendar[href=?]", calendar_path, {count: 1},
      "der Parameter wuerde nichts wegfiltern"
  end

  test "der bestehende Reservierungs-Knopf bleibt daneben stehen" do
    tisch!("Match Billard")

    welcome!
    assert_response :success
    assert_select "a#reservations", {count: 1},
      "der Kalender-Link tritt hinzu, er ersetzt nichts"
  end

  # ⚠️ Am Kiosk gibt es bewusst KEINEN Sprachumschalter mehr: die Anzeigesprache kommt aus
  # `Carambus.config.scoreboard_locale` (Betreiber-Entscheidung 2026-08-30). Eine Wahl
  # anzubieten, die der naechste Broadcast ueberschreibt, waere schlechter als keine.
  test "die Welcome-Page traegt keinen Sprachumschalter" do
    tisch!("Match Billard")

    welcome!
    assert_response :success
    assert_select "a#language", {count: 0}
  end

  # Die Tastensteuerung sprang auf `#language` — ein Element, das es seit Plan 40-02 nicht mehr
  # gibt. `getElementById(null).focus()` warf und brach die ganze Fernbedienungs-Navigation.
  test "die Tastensteuerung springt nur auf Elemente, die es gibt" do
    tisch!("Match Billard")

    welcome!
    assert_response :success
    refute_match(/"intro":\s*"language"/, response.body,
      "der verwaiste Sprung muss weg sein")

    %w[start intro reservations calendar].each do |id|
      assert_select "##{id}", {minimum: 1}, "die Navigation zeigt auf ##{id}"
    end
  end
end
