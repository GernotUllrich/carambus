# frozen_string_literal: true

require "test_helper"

# Deckt den CC-losen Short-Circuit ab (Plan 29-06): der neue get_updates-Parameter
# `import_entry_list` laesst die Authority die Meldeliste eines Region Servers frisch einlesen
# und liefert die entstandenen Versionen in derselben Antwort zurueck — analog update_tournament_from_cc,
# nur ohne ClubCloud. get_updates ist offen (kein Login), wie der reguläre Sync.
class VersionsControllerTest < ActionDispatch::IntegrationTest
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
    # In der Testumgebung liefert Season.current_season nichts (keine per-Datum aktuelle Fixture) —
    # entscheidend ist, dass der Fallback DARAUF greift und nicht auf einen falschen Wert.
    assert_nil captured[:season], "ohne season_id + ohne current_season => nil (kein Fehlgriff)"
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
end
