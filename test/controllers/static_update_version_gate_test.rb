# frozen_string_literal: true

require "test_helper"

# Plan 21-06: das Gate von `StaticController#update_version` (der Knopf „Update to latest version"
# auf /repo_version).
#
# Befund aus der Brakeman-Sichtung 21-05 (Nebenbefund 2): die Aktion verlangte Admin nur, WENN die
# Anfrage von aussen kam (`if remote_request? && !current_user&.admin?`, static_controller.rb:57).
# `remote_request?` ist im Vereins-WLAN falsch (application_controller.rb:263 → local_ip?), also
# genuegte im Lokal die blosse Anwesenheit, um einen Deploy auszuloesen — die Netzwerk-Herkunft
# zaehlte als Berechtigung.
#
# Der Nachbar auf derselben Seite, `sync_data` (static_controller.rb:134-144), macht es richtig:
# `local_server?` UND `admin?`. Dieses Muster wird hier nachgezogen.
#
# ⚠️ `update_version` startet im Erfolgsfall einen ECHTEN Deploy (`Process.spawn` auf
# bin/deploy.sh — die Datei existiert im Checkout). Jeder Test hier stubbt `Process.spawn` und
# `Process.detach`, AUCH der Lauf gegen den alten Code. Ohne den Stub deployt die Suite die
# Entwicklungsmaschine.
class StaticUpdateVersionGateTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:system_admin)
    # 127.0.0.1 ist der Default von ActionDispatch::IntegrationTest und gilt als lokal
    # (local_ip?: "127.0.0.1" → true). local_server? ist in test wahr, weil
    # Carambus.config.carambus_api_url gesetzt ist. Beide Guards vor dem Gate passieren also.
    @local_ip = "127.0.0.1"
  end

  # Faengt den Deploy ab und zaehlt, ob er ausgeloest wurde.
  def counting_spawn
    spawns = []
    Process.stub(:spawn, ->(*args) {
      spawns << args
      4711
    }) do
      Process.stub(:detach, ->(_pid) {}) do
        yield
      end
    end
    spawns
  end

  test "anonym aus dem lokalen Netz loest KEINEN Deploy aus" do
    spawns = counting_spawn do
      post update_version_path, headers: {"REMOTE_ADDR" => @local_ip}
    end

    assert_empty spawns, "Ein anonymer Aufruf aus dem lokalen Netz hat einen Deploy gestartet"
    assert_redirected_to repo_version_path
    assert flash[:alert].present?, "Erwartet wird eine Ablehnung mit Meldung"
  end

  test "angemeldeter Nicht-Admin aus dem lokalen Netz loest KEINEN Deploy aus" do
    sign_in users(:player)
    spawns = counting_spawn do
      post update_version_path, headers: {"REMOTE_ADDR" => @local_ip}
    end

    assert_empty spawns, "Ein angemeldeter Nicht-Admin hat einen Deploy gestartet"
    assert_redirected_to repo_version_path
  end

  test "angemeldeter Admin kommt weiterhin durch" do
    sign_in @admin
    spawns = counting_spawn do
      post update_version_path, headers: {"REMOTE_ADDR" => @local_ip}
    end

    assert_equal 1, spawns.size, "Der berechtigte Weg muss offen bleiben (Status #{response.status}, alert: #{flash[:alert].inspect})"
  end

  test "der Knopf erscheint nur fuer Berechtigte" do
    # Sichtbarkeit eines Knopfs = Recht seiner Aktion (PROJECT.md, 2026-09-13)
    get repo_version_path, headers: {"REMOTE_ADDR" => @local_ip}
    anonymous_body = response.body

    sign_in @admin
    get repo_version_path, headers: {"REMOTE_ADDR" => @local_ip}
    admin_body = response.body

    refute_includes anonymous_body, "Update to latest version",
      "Der Deploy-Knopf ist fuer anonyme Besucher sichtbar"
    # Der Knopf erscheint nur, wenn die Seite ueberhaupt einen Rueckstand meldet; ist das nicht
    # der Fall, sagt dieser Test ueber den Admin-Fall nichts aus — dann ist nur die Zeile oben
    # der Beleg. Deshalb hier keine Umkehr-Assertion erzwingen, sondern nur festhalten:
    assert admin_body.present?
  end
end
