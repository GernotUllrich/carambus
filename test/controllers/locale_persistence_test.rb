# frozen_string_literal: true

require "test_helper"

# Die gewaehlte Sprache ueberlebt den Seitenwechsel.
#
# Vorher galt `?locale=` genau EINEN Request: kein Link fuehrt den Parameter mit, also fiel
# jede Folgeseite auf User-Preference oder Browser-Header zurueck. Am Kiosk sah das aus wie
# eine wild gemischte Sprache — Einstieg englisch, jede weitere Seite deutsch
# (Betreiber-Befund 2026-08-30). Derselbe Effekt traf den Sprachumschalter im Website-Footer.
#
# Geprueft am Kalender, weil der ohne Anmeldung erreichbar ist und einen klar
# unterscheidbaren Titel traegt ("Termine ..." / "... fixtures").
class LocalePersistenceTest < ActionDispatch::IntegrationTest
  setup do
    @monat = Date.current.strftime("%Y-%m")
  end

  def deutsch?
    response.body.include?("Termine")
  end

  def englisch?
    response.body.include?("fixtures")
  end

  test "eine Sprachwahl gilt auch auf der naechsten Seite" do
    get "/calendar?month=#{@monat}&locale=en"
    assert_response :success
    assert englisch?, "die Wahl muss sofort greifen"

    get "/calendar?month=#{@monat}"
    assert_response :success
    assert englisch?, "und ohne den Parameter erhalten bleiben — das war der Kern des Fehlers"
  end

  test "eine neue Wahl schlaegt die gemerkte" do
    get "/calendar?month=#{@monat}&locale=en"
    get "/calendar?month=#{@monat}&locale=de"
    assert_response :success
    assert deutsch?

    get "/calendar?month=#{@monat}"
    assert_response :success
    assert deutsch?, "auch die Rueckschaltung muss haften"
  end

  test "ohne jede Wahl bleibt es beim Standard" do
    get "/calendar?month=#{@monat}"
    assert_response :success
    assert deutsch?, "default_locale ist :de"
  end

  # Sonst liesse sich ueber den URL beliebiger Unsinn in die Session schreiben.
  test "ein ungueltiger Wert landet nicht in der Session" do
    get "/calendar?month=#{@monat}&locale=en"
    get "/calendar?month=#{@monat}&locale=klingonisch"
    assert_response :success
    assert englisch?, "der Unsinn wird ignoriert, die gemerkte Wahl bleibt stehen"
  end

  # ⚠️ Regression zu Plan 40-01: die Preference des angemeldeten Scoreboard-Users ("de") darf
  # eine Umschaltung am Geraet nicht sofort wieder totschlagen — deshalb steht die Session in
  # `set_locale` VOR `locale_from_user`.
  test "die gemerkte Wahl schlaegt die Preference des angemeldeten Benutzers" do
    users(:admin).update!(preferences: (users(:admin).preferences || {}).merge("locale" => "de"))
    sign_in users(:admin)

    get "/calendar?month=#{@monat}"
    assert_response :success
    assert deutsch?, "ohne eigene Wahl gilt die Preference"

    get "/calendar?month=#{@monat}&locale=en"
    get "/calendar?month=#{@monat}"
    assert_response :success
    assert englisch?, "die bewusste Wahl am Geraet muss gewinnen"
  end

  # --- Kiosk: eine Sprache je Server ------------------------------------------------------
  #
  # Am Kiosk gibt es keine individuelle Wahl (Betreiber-Entscheidung 2026-08-30): die
  # Live-Seiten bekommen ihr HTML per Broadcast, serverseitig EINMAL gerendert und an alle
  # Abonnenten geschickt. Eine Wahl anzubieten, die der naechste Broadcast ueberschreibt,
  # waere schlechter als keine.

  def als_lokaler_server!(scoreboard_locale: "de")
    @original_config ||= Carambus.config
    Carambus.config = OpenStruct.new(
      @original_config.to_h.merge(carambus_api_url: "http://localhost:3131",
        scoreboard_locale: scoreboard_locale)
    )
  end

  def scoreboard_user!
    User.find_by(email: "scoreboard@carambus.de") ||
      User.create!(email: "scoreboard@carambus.de", password: "sb-test-passwort",
        first_name: "Score", last_name: "Board",
        accepted_terms_at: Time.current, accepted_privacy_at: Time.current,
        confirmed_at: Time.current)
  end

  teardown do
    Carambus.config = @original_config if @original_config
  end

  test "am Kiosk gilt die Serversprache" do
    als_lokaler_server!(scoreboard_locale: "en")
    sign_in scoreboard_user!

    get "/calendar?month=#{@monat}"
    assert_response :success
    assert englisch?, "auch der Kalender folgt der Serversprache, nicht dem Browser"
  end

  # ⚠️ Sonst waere genau der Sprachwechsel zurueck, der urspruenglich gestoert hat: eine
  # Umschaltung wirkt am Kiosk nicht, weil der naechste Broadcast sie ohnehin ueberschriebe.
  test "am Kiosk aendert eine Umschaltung nichts" do
    als_lokaler_server!(scoreboard_locale: "en")
    sign_in scoreboard_user!

    get "/calendar?month=#{@monat}&locale=de"
    assert_response :success
    assert englisch?, "die Serversprache bleibt massgeblich"
  end

  test "ohne gesetzte Serversprache bleibt es am Kiosk beim Standard" do
    als_lokaler_server!(scoreboard_locale: nil)
    sign_in scoreboard_user!

    get "/calendar?month=#{@monat}"
    assert_response :success
    assert deutsch?
  end

  # Ein Mensch, der sich am selben Rechner anmeldet, faellt bewusst in die Website-Logik.
  test "ein angemeldeter Mensch behaelt seine Wahl auch bei gesetzter Serversprache" do
    als_lokaler_server!(scoreboard_locale: "en")
    sign_in users(:admin)

    get "/calendar?month=#{@monat}&locale=de"
    assert_response :success
    assert deutsch?

    get "/calendar?month=#{@monat}"
    assert_response :success
    assert deutsch?, "die Serversprache gilt nur fuer Kiosk-Geraete"
  end

  # ⚠️ Der Broadcast-Pfad (`TableMonitorJob`) rendert ohne Request und liest ausschliesslich
  # `TableMonitor#display_locale`. Stuende die Serversprache nur im Controller, zeigte ein
  # Scoreboard sie beim Aufruf und fiele beim ersten Live-Update zurueck.
  test "der Broadcast-Pfad kennt dieselbe Serversprache" do
    als_lokaler_server!(scoreboard_locale: "en")
    monitor = locations(:one).tables.order(:id).first.table_monitor

    assert_nil monitor.display_locale,
      "display_locale meldet weiterhin nur explizit Konfiguriertes"
    assert_equal :en, monitor.effective_locale,
      "die Kette dahinter kennt die Serversprache — eine Stelle fuer beide Renderpfade"
  end
end
