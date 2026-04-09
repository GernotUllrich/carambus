# frozen_string_literal: true

require "test_helper"

# Unit tests fuer RegionCc::LeagueSyncer.
# Verifiziert: Dispatcher-Muster, sync_leagues-Rueckgabewerte, Fehlerbehandlung.
# Alle HTTP-Anfragen werden via Minitest::Mock abgefangen — kein echtes Netzwerk.
class RegionCc::LeagueSyncerTest < ActiveSupport::TestCase
  setup do
    @region = regions(:nbv)
    @region_cc = RegionCc.create!(
      region: @region,
      name: "NBV Test",
      shortname: "nbv",
      context: "nbv",
      cc_id: 20,
      base_url: "https://test.club-cloud.de",
      username: "test",
      userpw: "test"
    )
    @client = Minitest::Mock.new
    @season = seasons(:current)
    # sync_leagues ruft Region.find_by_shortname("DBU").id auf — DBU muss existieren
    @dbu_region = Region.find_by_shortname("DBU") || Region.create!(
      name: "Deutscher Billard-Union", shortname: "DBU", id: 50_000_099
    )
  end

  teardown do
    @region_cc.destroy if @region_cc.persisted?
  end

  # ---------------------------------------------------------------------------
  # Test 1: sync_leagues gibt [leagues_array, nil] zurueck bei Erfolg
  # Ohne BranchCc-Eintraege fuer den Kontext gibt sync_leagues [[], nil] zurueck.
  # ---------------------------------------------------------------------------
  test "sync_leagues returns [leagues_array, nil] on success with empty BranchCc" do
    result = RegionCc::LeagueSyncer.call(
      region_cc: @region_cc,
      client: @client,
      operation: :sync_leagues,
      context: "nbv",
      season_name: @season.name,
      exclude_season_names: [],
      exclude_league_ba_ids: []
    )

    assert_kind_of Array, result
    assert_equal 2, result.size
    assert_kind_of Array, result[0]
    assert_nil result[1]
  end

  # ---------------------------------------------------------------------------
  # Test 2: sync_leagues gibt [[], error_string] zurueck bei StandardError
  # ---------------------------------------------------------------------------
  test "sync_leagues returns [[], error_string] when StandardError raised" do
    # Season existiert nicht => ArgumentError im sync_leagues, der als error_string zurueckgegeben wird
    result = RegionCc::LeagueSyncer.call(
      region_cc: @region_cc,
      client: @client,
      operation: :sync_leagues,
      context: "nbv",
      season_name: "UNBEKANNTE_SAISON_XYZ",
      exclude_season_names: [],
      exclude_league_ba_ids: []
    )

    assert_kind_of Array, result
    assert_equal 2, result.size
    assert_equal [], result[0]
    assert_kind_of String, result[1]
    assert_match(/unknown season name/, result[1])
  end

  # ---------------------------------------------------------------------------
  # Test 3: sync_team_players gibt leeres Array zurueck wenn kein league_team_cc vorhanden
  # ---------------------------------------------------------------------------
  test "sync_team_players returns empty array when league_team has no league_team_cc" do
    # LeagueTeam ohne league_team_cc => gibt leeres Array zurueck ohne HTTP-Anfrage
    league_team = Minitest::Mock.new
    league_team.expect(:league_team_cc, nil)
    league_team.expect(:league_team_cc, nil)

    result = RegionCc::LeagueSyncer.call(
      region_cc: @region_cc,
      client: @client,
      operation: :sync_team_players,
      league_team: league_team
    )

    assert_kind_of Array, result
    assert_empty result

    league_team.verify
  end

  # ---------------------------------------------------------------------------
  # Test 4: Unbekannte operation wirft ArgumentError
  # ---------------------------------------------------------------------------
  test "raises ArgumentError for unknown operation" do
    assert_raises(ArgumentError) do
      RegionCc::LeagueSyncer.call(
        region_cc: @region_cc,
        client: @client,
        operation: :invalid_operation_xyz
      )
    end
  end
end
