# frozen_string_literal: true

require "test_helper"

# Render-Gate fuer die PIN-Erstvergabe unter /admin/player_locals (Plan 02.1-01).
#
# ⚠️ Warum es diesen Test gibt: In diesem Projekt sind schon einmal Admin-Views "repariert"
# worden, ohne dass eine einzige davon tatsaechlich gerendert wurde — ERB-Compile und
# Runner-Smoke-Checks hatten den Fehler nicht gefangen. `Field::Password` ist genau so ein
# Fall: die Klasse laedt erst mit dem Dashboard, ein Tippfehler faellt sonst erst im Browser auf.
class AdminPlayerLocalsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    # `PlayerLocal` schreibt nur auf einem lokalen Server.
    @original_config = Carambus.config
    Carambus.config = OpenStruct.new(@original_config.to_h.merge(carambus_api_url: "http://localhost:3131"))
    @player = players(:nbv_ullrich)
    # `selectable_players` filtert auf den konfigurierten Club; die Fixtures haengen an 50000001.
    Carambus.config = OpenStruct.new(Carambus.config.to_h.merge(club_id: 50_000_001))
    # ⚠️ `Admin::ApplicationController#authenticate_admin` laesst ausschliesslich
    # `system_admin?` durch — ohne Anmeldung antwortet jede Admin-Route mit 302.
    sign_in users(:system_admin)
  end

  teardown do
    Carambus.config = @original_config
  end

  test "der Index verlinkt auf die Massenpflege" do
    get "/admin/player_locals"

    assert_response :success
    assert_includes response.body, "/admin/player_locals/bulk_edit"
    # ⚠️ Der ueberschriebene _index_header darf den Standard-Knopf nicht verdraengen.
    assert_includes response.body, "/admin/player_locals/new"
  end

  test "Index rendert" do
    PlayerLocal.create!(player: @player, email: "max@example.com")

    get "/admin/player_locals"

    assert_response :success
    assert_not_includes response.body, "We're sorry, but something went wrong"
  end

  test "das Anlage-Formular rendert und traegt ein Passwortfeld fuer den PIN" do
    get "/admin/player_locals/new"

    assert_response :success
    assert_not_includes response.body, "We're sorry, but something went wrong"
    # Administrate rendert `Field::Password` als <input type="password">.
    assert_match(/type="password"[^>]*name="player_local\[pin\]"|name="player_local\[pin\]"[^>]*type="password"/,
      response.body, "kein Passwortfeld fuer den PIN im Formular")
  end

  test "Show rendert und zeigt den PIN NICHT" do
    k = PlayerLocal.create!(player: @player, email: "max@example.com", pin: "4711")

    get "/admin/player_locals/#{k.id}"

    assert_response :success
    assert_not_includes response.body, "4711"
    assert_not_includes response.body, k.pin_digest
  end

  test "Index zeigt weder PIN noch Hash" do
    k = PlayerLocal.create!(player: @player, email: "max@example.com", pin: "4711")

    get "/admin/player_locals"

    assert_not_includes response.body, "4711"
    assert_not_includes response.body, k.pin_digest
  end
  test "das Bearbeiten-Formular spielt den PIN nicht zurueck" do
    k = PlayerLocal.create!(player: @player, email: "max@example.com", pin: "4711")

    get "/admin/player_locals/#{k.id}/edit"

    assert_response :success
    assert_not_includes response.body, "4711"
    assert_not_includes response.body, k.pin_digest
    # Das Feld ist da, aber leer — sonst waere der PIN beim naechsten Speichern weg.
    assert_match(/name="player_local\[pin\]"/, response.body)
    assert_no_match(/name="player_local\[pin\]"[^>]*value="."/, response.body)
  end

  test "Adresse speichern mit leerem PIN-Feld behaelt den PIN" do
    k = PlayerLocal.create!(player: @player, email: "max@example.com", pin: "4711")
    vorher = k.pin_digest

    patch "/admin/player_locals/#{k.id}",
      params: {player_local: {email: "neu@example.com", pin: ""}}

    assert_equal "neu@example.com", k.reload.email
    assert_equal vorher, k.pin_digest, "das leere Formularfeld hat den PIN geloescht"
  end
  # Betreiber-Abnahme 2026-08-30: nach dem Speichern zurueck zur Liste, nicht auf die
  # Detailseite. Administrate leitet von Haus aus auf SHOW — diese Tests halten die
  # Abweichung fest, damit sie ein Gem-Update nicht still zurueckdreht.
  test "Anlegen leitet auf die Liste, nicht auf die Detailseite" do
    post "/admin/player_locals",
      params: {player_local: {player_id: @player.id, email: "a@b.de", pin: "4711"}}

    assert_redirected_to "/admin/player_locals"
    assert_equal 1, PlayerLocal.count
  end

  test "Bearbeiten leitet ebenfalls auf die Liste" do
    k = PlayerLocal.create!(player: @player, email: "a@b.de")

    patch "/admin/player_locals/#{k.id}", params: {player_local: {email: "neu@b.de"}}

    assert_redirected_to "/admin/player_locals"
    assert_equal "neu@b.de", k.reload.email
  end

  test "ein abgelehnter PIN nennt den Grund sichtbar im Formular" do
    post "/admin/player_locals",
      params: {player_local: {player_id: @player.id, email: "a@b.de", pin: "1234"}}

    assert_response :unprocessable_entity
    assert_includes response.body, "zu leicht zu erraten"
    assert_equal 0, PlayerLocal.count, "ein trivialer PIN darf nicht angelegt werden"
  end

  test "ein zu kurzer PIN nennt den Grund sichtbar im Formular" do
    post "/admin/player_locals",
      params: {player_local: {player_id: @player.id, email: "a@b.de", pin: "12"}}

    assert_response :unprocessable_entity
    assert_includes response.body, "4 bis 8 Ziffern"
  end
  # ===================================================================================
  # Massenpflege der E-Mail-Adressen (Quick-Task 2026-08-30)
  # ===================================================================================

  def bulk(rows)
    patch "/admin/player_locals/bulk_update", params: {rows: rows}
  end

  test "die Massenpflege listet ALLE Clubmitglieder, auch ohne vorhandenen Datensatz" do
    get "/admin/player_locals/bulk_edit"

    assert_response :success
    PlayerLocal.selectable_players.each do |p|
      assert_includes response.body, p.fl_name, "#{p.fl_name} fehlt in der Tabelle"
    end
    assert_equal 0, PlayerLocal.count, "das blosse Anzeigen darf nichts anlegen"
  end

  test "mehrere Adressen in einem Zug" do
    a = players(:nbv_ullrich)
    b = players(:nbv_andresen)

    bulk({a.id => {email: "A@Example.COM"}, b.id => {email: "b@example.com"}})

    assert_redirected_to "/admin/player_locals/bulk_edit"
    assert_equal "a@example.com", PlayerLocal.find_by(player_id: a.id).email, "Normalisierung muss greifen"
    assert_equal "b@example.com", PlayerLocal.find_by(player_id: b.id).email
  end

  # ⚠️ Der teuerste denkbare Fehler: das Formular einmal leer abschicken und 23 leere
  # Kontakte erzeugen.
  test "leere Zeilen legen KEINE Datensaetze an" do
    zeilen = PlayerLocal.selectable_players.to_h { |p| [p.id, {email: "", consent: "0"}] }

    bulk(zeilen)

    assert_equal 0, PlayerLocal.count, "eine leere Zeile ohne Bestand darf nichts anlegen"
  end

  test "Haken setzen macht anschreibbar, Haken wegnehmen widerruft — die Adresse bleibt" do
    a = players(:nbv_ullrich)

    bulk({a.id => {email: "a@example.com", consent: "1"}})
    k = PlayerLocal.find_by(player_id: a.id)
    assert k.contactable?, "der Haken muss die Einwilligung setzen"

    bulk({a.id => {email: "a@example.com", consent: "0"}})
    k.reload
    refute k.contactable?, "der weggenommene Haken muss widerrufen"
    assert k.revoked?
    assert_equal "a@example.com", k.email, "der Widerruf darf die Adresse NICHT loeschen"
  end

  test "erneutes Anhaken nach Widerruf macht wieder anschreibbar" do
    a = players(:nbv_ullrich)
    bulk({a.id => {email: "a@example.com", consent: "1"}})
    bulk({a.id => {email: "a@example.com", consent: "0"}})
    bulk({a.id => {email: "a@example.com", consent: "1"}})

    k = PlayerLocal.find_by(player_id: a.id)
    assert k.contactable?
    assert_nil k.consent_revoked_at
  end

  # ⚠️ Eine fehlerhafte Zeile darf die uebrigen nicht mitreissen.
  test "eine ungueltige Adresse blockiert die gueltigen Zeilen nicht" do
    a = players(:nbv_ullrich)
    b = players(:nbv_andresen)

    bulk({a.id => {email: "kein-at-zeichen"}, b.id => {email: "b@example.com"}})

    assert_response :unprocessable_entity
    assert_equal "b@example.com", PlayerLocal.find_by(player_id: b.id)&.email,
      "die gueltige Zeile muss trotzdem gespeichert sein"
    assert_nil PlayerLocal.find_by(player_id: a.id), "die ungueltige nicht"
    assert_includes response.body, "kein-at-zeichen", "die Eingabe muss zurueckgezeigt werden"
  end

  # ⚠️ Der Zugriffsschutz dieser Aktion ist die Mitgliederliste, nicht die id aus dem Request.
  test "eine untergeschobene fremde player_id bleibt folgenlos" do
    fremd = Player.where.not(id: PlayerLocal.selectable_players.map(&:id)).first
    refute_nil fremd, "Testvoraussetzung: es muss einen Nicht-Clubspieler geben"

    bulk({fremd.id => {email: "fremd@example.com", consent: "1"}})

    assert_nil PlayerLocal.find_by(player_id: fremd.id),
      "nur Clubmitglieder duerfen ueber die Massenpflege entstehen"
  end

  test "ohne System-Admin ist die Massenpflege nicht erreichbar" do
    sign_out :user

    get "/admin/player_locals/bulk_edit"
    assert_response :redirect

    bulk({players(:nbv_ullrich).id => {email: "x@example.com"}})
    assert_equal 0, PlayerLocal.count
  end

end
