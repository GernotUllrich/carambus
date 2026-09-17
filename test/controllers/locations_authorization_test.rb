# frozen_string_literal: true

require "test_helper"

# Plan 20-01: Rechte an den schreibenden Aktionen des LocationsController.
#
# Diese Datei ist zuerst als CHARAKTERISIERUNG entstanden: sie lief am unveraenderten Code und
# belegte, dass anonyme Besucher und Konten mit der Rolle "player" jede schreibende Aktion
# ausfuehren konnten. Erst danach kam das Gate.
#
# Gemessen wird am ZUSTAND (Location.count, geaendertes Attribut, Table.count, aufgerufener
# Kalender-Dienst), nicht am HTTP-Status: ein 422 oder ein 500 beweist kein Gate — es beweist
# nur, dass irgendetwas schiefging, nachdem der Rumpf erreicht war. Genau diese Falle musste
# 17-05 nachtraeglich korrigieren.
#
# Zwei Besonderheiten dieses Controllers:
#
#   1. `set_location` meldet jeden Besucher OHNE Anmeldung automatisch als `User.scoreboard` an
#      (`bypass_sign_in`, locations_controller.rb:654). Deshalb ist `authenticate_user!` auf
#      jeder Aktion mit :id wirkungslos — nur eine Rollenpruefung greift.
#   2. `User.scoreboard` liefert in der Testumgebung IMMER nil (user.rb:98,
#      `unless Rails.env == "test"`). Das Konto laesst sich also nicht durch eine Fixture
#      herstellen; der Auto-Login-Pfad wird per Stub geprueft (siehe unten).
class LocationsAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @location = locations(:one)
    @player = users(:one)             # role: player
    @club_admin = users(:club_admin)  # admin? == true
    @system_admin = users(:system_admin)
    @table_kind = table_kinds(:one)
    @league = leagues(:one)
  end

  # Fuehrt den Block einmal anonym und einmal als Konto mit Rolle "player" aus.
  # Die Flash-Meldung wird vor jedem Durchgang geleert: sonst laeuft ein durchgelassener
  # Aufruf mit der Absage seines Vorgaengers durch und der Test glaubt an ein Gate,
  # das gar nicht gegriffen hat (Falle aus 17-05).
  def each_unprivileged
    [["anonym", nil], ["player", @player]].each do |label, user|
      reset!
      sign_in user if user
      yield label
    end
  end

  def assert_denied(label, action)
    assert_response :redirect, "#{action} als #{label}: erwartete Absage (Redirect), bekam #{response.status}"
    assert_not_nil flash[:alert], "#{action} als #{label}: Absage ohne Meldung"
  end

  # ---------------------------------------------------------------------------
  # Stammdaten: anlegen
  # ---------------------------------------------------------------------------

  test "POST create — anonym und als Spieler wird kein Spiellokal angelegt" do
    each_unprivileged do |label|
      assert_no_difference "Location.count", "create als #{label} hat ein Spiellokal angelegt" do
        post locations_path, params: {location: {name: "Eingeschmuggelt #{label}", data: "{}"}}
      end
      assert_denied(label, "POST create")
    end
  end

  test "POST create — ein club_admin legt an wie bisher" do
    sign_in @club_admin
    assert_difference "Location.count", 1 do
      post locations_path, params: {location: {name: "Vom Admin angelegt", data: "{}"}}
    end
  end

  test "GET new — anonym und als Spieler kein Formular" do
    each_unprivileged do |label|
      get new_location_path
      assert_denied(label, "GET new")
    end
  end

  # ---------------------------------------------------------------------------
  # Stammdaten: aendern
  # ---------------------------------------------------------------------------

  test "PATCH update — anonym und als Spieler bleibt der Name unveraendert" do
    original = @location.name
    each_unprivileged do |label|
      patch location_path(@location), params: {location: {name: "Umbenannt durch #{label}", data: "{}"}}
      assert_equal original, @location.reload.name, "update als #{label} hat den Namen geaendert"
      assert_denied(label, "PATCH update")
    end
  end

  test "PATCH update — ein club_admin aendert wie bisher" do
    sign_in @club_admin
    patch location_path(@location), params: {location: {name: "Vom Admin umbenannt", data: "{}"}}
    assert_equal "Vom Admin umbenannt", @location.reload.name
  end

  test "GET edit — anonym und als Spieler kein Formular" do
    each_unprivileged do |label|
      get edit_location_path(@location)
      assert_denied(label, "GET edit")
    end
  end

  # ---------------------------------------------------------------------------
  # Stammdaten: loeschen
  # ---------------------------------------------------------------------------

  test "DELETE destroy — anonym und als Spieler bleibt das Spiellokal bestehen" do
    each_unprivileged do |label|
      opfer = Location.create!(name: "Loeschkandidat #{label}")
      assert_no_difference "Location.count", "destroy als #{label} hat geloescht" do
        delete location_path(opfer)
      end
      assert_denied(label, "DELETE destroy")
      opfer.destroy
    end
  end

  # ---------------------------------------------------------------------------
  # merge — destruktives Zusammenfuehren, collection-Route OHNE set_location
  # ---------------------------------------------------------------------------

  test "POST merge — anonym und als Spieler wird nichts zusammengefuehrt" do
    each_unprivileged do |label|
      ziel = Location.create!(name: "Merge-Ziel #{label}")
      quelle = Location.create!(name: "Merge-Quelle #{label}")
      assert_no_difference "Location.count", "merge als #{label} hat Spiellokale zusammengefuehrt" do
        post merge_locations_path, params: {merge: ziel.id, with: quelle.id.to_s}
      end
      assert_denied(label, "POST merge")
      quelle.destroy
      ziel.destroy
    end
  end

  test "POST merge — ein system_admin fuehrt zusammen wie bisher" do
    sign_in @system_admin
    ziel = Location.create!(name: "Merge-Ziel Admin")
    quelle = Location.create!(name: "Merge-Quelle Admin")
    assert_difference "Location.count", -1 do
      post merge_locations_path, params: {merge: ziel.id, with: quelle.id.to_s}
    end
    ziel.destroy
  end

  # ---------------------------------------------------------------------------
  # add_tables_to — erzeugt Tische
  # ---------------------------------------------------------------------------

  test "POST add_tables_to — anonym und als Spieler entstehen keine Tische" do
    each_unprivileged do |label|
      assert_no_difference "Table.count", "add_tables_to als #{label} hat Tische erzeugt" do
        post add_tables_to_location_path(@location), params: {table_kind_id: @table_kind.id, number: 2}
      end
      assert_denied(label, "POST add_tables_to")
    end
  end

  test "POST add_tables_to — ein club_admin legt Tische an wie bisher" do
    sign_in @club_admin
    assert_difference "Table.count", 2 do
      post add_tables_to_location_path(@location), params: {table_kind_id: @table_kind.id, number: 2}
    end
  end

  # ---------------------------------------------------------------------------
  # new_league_tournament
  # ---------------------------------------------------------------------------

  test "POST new_league_tournament — anonym und als Spieler kein Formular" do
    each_unprivileged do |label|
      post new_league_tournament_location_path(@location), params: {league_id: @league.id}
      assert_denied(label, "POST new_league_tournament")
    end
  end

  # ---------------------------------------------------------------------------
  # create_event — Tischreservierung am Scoreboard, schreibt in einen EXTERNEN Kalender
  #
  # Checkpoint-Entscheidung 2026-09-17: dieselbe Regel wie die uebrigen Aktionen. Grundlage waren
  # die Messwerte der Charakterisierung — anonym erreichte der Aufruf den Google-Kalender, und in
  # allen erhaltenen Logs ab Februar 2026 steht genau ein echter Aufruf (07.08.2026, HTTP 500).
  # Die Reservierungs-ANSICHT laeuft ueber `show` und ist von diesem Gate nicht betroffen.
  # ---------------------------------------------------------------------------

  def with_fake_calendar
    aufrufe = []
    fake_service = Object.new
    fake_service.define_singleton_method(:insert_event) do |calendar_id, event|
      aufrufe << [calendar_id, event]
      Struct.new(:id).new("evt-1")
    end
    GoogleCalendarService.stub(:calendar_service, fake_service) do
      GoogleCalendarService.stub(:calendar_id, "kalender-1") { yield }
    end
    aufrufe
  end

  def create_event_params(summary)
    {location: {summary: summary, date: "2026-10-01", start_time: "19:00", end_time: "21:00"}}
  end

  test "POST create_event — anonym und als Spieler wird kein Kalendertermin angelegt" do
    each_unprivileged do |label|
      aufrufe = with_fake_calendar do
        post create_event_location_path(@location), params: create_event_params("Reservierung #{label}")
      end
      assert_empty aufrufe, "create_event als #{label} hat den externen Kalender erreicht"
      assert_denied(label, "POST create_event")
    end
  end

  test "POST create_event — ein club_admin legt einen Termin an wie bisher" do
    sign_in @club_admin
    aufrufe = with_fake_calendar do
      post create_event_location_path(@location), params: create_event_params("Reservierung Admin")
    end
    assert_equal 1, aufrufe.size, "Der Admin erreichte den Kalender-Dienst nicht"
    assert_equal "kalender-1", aufrufe.first.first
  end

  # ---------------------------------------------------------------------------
  # Der Auto-Login aus set_location
  #
  # Belegt, dass ein Besucher OHNE eigene Anmeldung durch `set_location` als Scoreboard-Konto
  # angemeldet wird — und dass das Gate ihn trotzdem abweist, weil dieses Konto die Rolle
  # "player" traegt. Ohne den Stub ist `User.scoreboard` in der Testumgebung nil und der Pfad
  # laeuft gar nicht (user.rb:98).
  # ---------------------------------------------------------------------------

  test "set_location meldet anonyme Besucher als Scoreboard-Konto an — das Gate weist sie dennoch ab" do
    original = @location.name
    User.stub(:scoreboard, @player) do
      patch location_path(@location), params: {location: {name: "Durch das Scoreboard-Konto", data: "{}"}}
    end
    assert_equal original, @location.reload.name,
      "Das automatisch angemeldete Scoreboard-Konto konnte den Namen aendern"
    assert_response :redirect
    assert_not_nil flash[:alert]
  end

  # ---------------------------------------------------------------------------
  # Knoepfe folgen dem Recht ihrer Aktion (AC-5)
  #
  # 17-01 hat die Regel aufgestellt: Sichtbarkeit eines Knopfs = Pruefung seiner Aktion.
  # Der "Neu"-Knopf auf der Listenseite und der Edit-Knopf auf der Detailseite waren schon
  # richtig (`current_user&.admin?` auf einem `button_to`, wo `disabled:` wirkt) — geprueft
  # werden hier die drei Formulare, die es nicht waren.
  # ---------------------------------------------------------------------------

  test "add_tables_to-Formular erscheint nur fuer Admins" do
    get location_path(@location)
    assert_no_match(/add_tables_to/, response.body,
      "Das Formular zum Tische-Anlegen war fuer einen anonymen Besucher sichtbar")

    reset!
    sign_in @player
    get location_path(@location)
    assert_no_match(/add_tables_to/, response.body,
      "Das Formular zum Tische-Anlegen war fuer einen Spieler sichtbar")

    reset!
    sign_in @club_admin
    get location_path(@location)
    assert_match(/add_tables_to/, response.body,
      "Dem Admin fehlt das Formular zum Tische-Anlegen")
  end

  test "merge-Formular erscheint nur fuer Admins" do
    # Das Formular steht unter `unless local_server?` — sichtbar also nur im Authority-Modus.
    original = Carambus.config.carambus_api_url
    begin
      Carambus.config.carambus_api_url = nil

      sign_in @player
      get locations_path
      assert_no_match(/merge and delete slave/, response.body,
        "Das merge-Formular war fuer einen Spieler sichtbar")

      reset!
      sign_in @club_admin
      get locations_path
      assert_match(/merge and delete slave/, response.body,
        "Dem Admin fehlt das merge-Formular")
    ensure
      Carambus.config.carambus_api_url = original
    end
  end

  # ---------------------------------------------------------------------------
  # Anzeige und Scoreboard bleiben offen (AC-3)
  # ---------------------------------------------------------------------------

  test "GET index bleibt oeffentlich" do
    get locations_path
    assert_response :success
  end

  test "GET show bleibt oeffentlich" do
    get location_path(@location)
    assert_response :success
  end

  test "GET show mit sb_state bleibt fuer das Scoreboard erreichbar" do
    get location_path(@location, sb_state: "welcome")
    assert_includes [200, 302], response.status,
      "Scoreboard-Einstieg (sb_state) antwortete mit #{response.status}"
    assert_nil flash[:alert], "Scoreboard-Einstieg wurde mit einer Absage beantwortet"
  end

  test "GET toggle_dark_mode bleibt fuer angemeldete Spieler erreichbar" do
    sign_in @player
    get toggle_dark_mode_location_path(@location)
    assert_includes [200, 302], response.status
    assert_nil flash[:alert], "toggle_dark_mode wurde mit einer Absage beantwortet"
  end
end
