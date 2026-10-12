# frozen_string_literal: true

require "test_helper"

# Deckt den CC-losen Short-Circuit ab (Plan 29-06): der neue get_updates-Parameter
# `import_entry_list` laesst die Authority die Meldeliste eines Region Servers frisch einlesen
# und liefert die entstandenen Versionen in derselben Antwort zurueck — analog update_tournament_from_cc,
# nur ohne ClubCloud. get_updates ist offen (kein Login), wie der reguläre Sync.
class VersionsControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # Plan 21-06: `update_carambus` gehoert NICHT zu den offenen Sync-Endpunkten.
  #
  # Befund aus der Brakeman-Sichtung 21-05 (Nebenbefund 1): `versions_controller.rb:6` nahm VIER
  # Aktionen vom `system_admin_only`-Gate aus, nicht drei. `get_updates`, `last_version` und
  # `current_revision` beantworten Sync-Anfragen anderer Server ohne Anmeldung — das ist gewollt
  # (H33). `update_carambus` dagegen beantwortet nichts: es startet `bin/deploy.sh` in einer
  # Shell (version.rb:147), synchron im Request-Thread. Der legitime Weg ist der Rake-Task
  # `carambus:update_carambus` (lib/tasks/carambus.rake:263); im ganzen Repo gibt es keinen
  # HTTP-Aufrufer.
  #
  # ⚠️ `Version.update_carambus` wird in JEDEM dieser Tests gestubbt, auch im Lauf gegen den
  # alten Code — ungestubbt deployt der Test die Entwicklungsmaschine.
  # ---------------------------------------------------------------------------

  def counting_update_carambus
    calls = 0
    Version.stub(:update_carambus, -> { calls += 1 }) { yield }
    calls
  end

  test "anonym loest update_carambus KEINEN Deploy aus" do
    calls = counting_update_carambus { post update_carambus_versions_url }

    assert_equal 0, calls, "Ein anonymer POST hat Version.update_carambus ausgefuehrt"
    assert response.redirect?, "Erwartet wird die Abweisung des system_admin_only-Gates"
  end

  test "ein angemeldeter Nicht-Admin loest update_carambus nicht aus" do
    sign_in users(:player)
    calls = counting_update_carambus { post update_carambus_versions_url }

    assert_equal 0, calls, "Ein angemeldeter Nicht-Admin hat Version.update_carambus ausgefuehrt"
  end

  test "ein System-Admin kommt bei update_carambus weiterhin durch" do
    sign_in users(:system_admin)
    calls = counting_update_carambus { post update_carambus_versions_url }

    assert_equal 1, calls, "Der berechtigte Weg muss offen bleiben"
  end

  test "die drei Sync-Endpunkte bleiben ohne Anmeldung erreichbar" do
    # Gegenprobe zur Boundary: ein Gate hier brach den Sync schon einmal (H33).
    get last_version_versions_url
    assert_response :success, "last_version darf nicht gegatet werden"

    get current_revision_versions_url
    assert_response :success, "current_revision darf nicht gegatet werden"
  end

  # Ein Fake-Importer, der nur `.call` beantwortet und die Konstruktor-Argumente einsammelt.
  def stub_importer(captured)
    ->(**kw) do
      captured.merge!(kw)
      (o = Object.new).define_singleton_method(:call) { nil }
      o
    end
  end

  test "import_entry_list löst den EntryListImporter für Region und Saison aus" do
    region = regions(:nbv)
    season = seasons(:current)
    captured = {}

    RegionServer::EntryListImporter.stub(:new, stub_importer(captured)) do
      get get_updates_versions_url(import_entry_list: region.id, season_id: season.id,
        region_id: region.id, last_version_id: 0)
    end

    assert_response :success
    assert_equal region.id, captured[:region]&.id
    assert_equal season.id, captured[:season]&.id
    assert_equal true, captured[:armed]
  end

  test "import_entry_list ohne season_id nimmt die aktuelle Saison" do
    region = regions(:nbv)
    captured = {}

    RegionServer::EntryListImporter.stub(:new, stub_importer(captured)) do
      get get_updates_versions_url(import_entry_list: region.id, region_id: region.id, last_version_id: 0)
    end

    assert_response :success
    # Fallback ist Season.current_season — nie ein beliebiger anderer Wert.
    assert_equal Season.current_season&.id, captured[:season]&.id,
      "ohne season_id => current_season (kein Fehlgriff)"
  end

  # Ohne den Parameter bleibt get_updates der reine Versions-Pull — der Importer darf NICHT laufen.
  test "get_updates ohne import_entry_list ruft den Importer nicht" do
    called = false
    RegionServer::EntryListImporter.stub(:new, ->(**) {
      called = true
      Object.new
    }) do
      get get_updates_versions_url(last_version_id: 0)
    end

    assert_response :success
    refute called
  end

  # Plan 02-01: last_version bekommt einen OPTIONALEN region_id-Filter. Ohne den Parameter
  # muss die Antwort exakt bleiben wie bisher — Local Server, die noch nicht aktualisiert
  # sind, fragen weiterhin ohne region_id und duerfen sich nicht anders verhalten.
  test "last_version ohne region_id liefert den globalen Hoechststand" do
    fremde = Version.create!(item_type: "Region", item_id: regions(:bbv).id,
      event: "update", region_id: regions(:bbv).id)

    get last_version_versions_url

    assert_response :success
    assert_equal fremde.id, JSON.parse(response.body)["last_version"]
  end

  # Der eigentliche Fix: die HOECHSTE Version gehoert hier bewusst einer FREMDEN Region.
  # Genau so entsteht der Effekt im Betrieb — die Authority scrapet fuer alle Verbaende, und
  # der Local Server meldete einen Rueckstand, der aus Records bestand, die er nie bekommt.
  # Der Aufbau ist absichtlich so gewaehlt, dass der Test ohne den Filter fehlschlaegt.
  test "last_version mit region_id ignoriert Versionen fremder Regionen" do
    eigene = Version.create!(item_type: "Region", item_id: regions(:nbv).id,
      event: "update", region_id: regions(:nbv).id)
    fremde = Version.create!(item_type: "Region", item_id: regions(:bbv).id,
      event: "update", region_id: regions(:bbv).id)
    assert fremde.id > eigene.id,
      "Testaufbau kaputt: die fremde Version muss die hoehere ID tragen"

    get last_version_versions_url(region_id: regions(:nbv).id)

    assert_response :success
    assert_equal eigene.id, JSON.parse(response.body)["last_version"]
  end

  # Plan 03-01: Die Antwort quittiert das ANGEWANDTE region_id. Ohne diese Quittung koennte
  # ein Client eine Authority, die filtert, nicht von einer alten unterscheiden, die den
  # Parameter ignoriert — die Zahl sieht in beiden Faellen gleich aus. Erst dadurch kann die
  # Statusanzeige "weiss ich nicht" von "kein Rueckstand" trennen.
  test "last_version quittiert das angewandte region_id" do
    get last_version_versions_url(region_id: regions(:nbv).id)

    assert_response :success
    assert_equal regions(:nbv).id, JSON.parse(response.body)["region_id"]
  end

  # Ohne Parameter ist der Schluessel vorhanden und null — vorhanden, damit der Client die
  # neue Authority ueberhaupt erkennt; null, weil nicht gefiltert wurde.
  test "last_version ohne region_id quittiert null" do
    get last_version_versions_url

    assert_response :success
    body = JSON.parse(response.body)
    assert body.key?("region_id"), "Schluessel muss vorhanden sein, sonst ist die Authority nicht erkennbar"
    assert_nil body["region_id"]
  end
end
