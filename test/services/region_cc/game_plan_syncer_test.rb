# frozen_string_literal: true

require "test_helper"

# Unit tests for RegionCc::GamePlanSyncer
# Verifiziert: Dispatcher-Pattern (.call(operation:)), ArgumentError fuer unbekannte Operationen,
# korrekte Weiterleitung an den injizierten Client.
# DB-Aufrufe werden nicht getestet — das ist Aufgabe von Integrationstests.
class RegionCc::GamePlanSyncerTest < ActiveSupport::TestCase
  # Minimaler HTML-Stub fuer spielberichte: table mit Spielbericht-Kopfzeile
  GAME_PLAN_LIST_HTML = <<~HTML.freeze
    <html><body>
      <form>
        <table><tr><td>
          <table><tr><td>
            <table><tr><td>
              <table>
                <tr><th>Nr.</th><th>Spielbericht</th></tr>
              </table>
            </td></tr></table>
          </td></tr></table>
        </td></tr></table>
      </form>
    </body></html>
  HTML

  setup do
    @region = regions(:nbv)
    @region_cc = RegionCc.create!(
      region: @region,
      name: "NBV Test",
      shortname: "nbv",
      context: "nbv",
      cc_id: 20,
      base_url: "https://test.club-cloud.de",
      username: "u",
      userpw: "p"
    )
    @opts = { context: "nbv", armed: "1", season_name: "2022/2023",
              exclude_season_names: [], exclude_league_ba_ids: [] }
  end

  teardown do
    @region_cc.destroy if @region_cc&.persisted?
  end

  # ---------------------------------------------------------------------------
  # Test 1: unknown operation raises ArgumentError
  # ---------------------------------------------------------------------------
  test "raises ArgumentError for unknown operation" do
    client = Minitest::Mock.new
    assert_raises(ArgumentError) do
      RegionCc::GamePlanSyncer.call(
        region_cc: @region_cc,
        client: client,
        operation: :unknown_xyz
      )
    end
    client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 2: :sync_game_plans dispatches without error (empty branch_ccs)
  # ---------------------------------------------------------------------------
  test "sync_game_plans dispatches without error when no branch_ccs exist" do
    client = Minitest::Mock.new
    # region_cc.branch_ccs ist leer im Test — kein HTTP-Aufruf erwartet
    result = nil
    assert_nothing_raised do
      result = RegionCc::GamePlanSyncer.call(
        region_cc: @region_cc,
        client: client,
        operation: :sync_game_plans,
        **@opts
      )
    end
    # Leere branch_ccs: kein Ergebnis-Record erzeugt, kein HTTP-Aufruf
    assert_kind_of Array, result
    assert_empty result
    client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 3: :sync_game_details dispatches without error (empty branch_ccs)
  # ---------------------------------------------------------------------------
  test "sync_game_details dispatches without error when no branch_ccs exist" do
    client = Minitest::Mock.new
    result = nil
    assert_nothing_raised do
      result = RegionCc::GamePlanSyncer.call(
        region_cc: @region_cc,
        client: client,
        operation: :sync_game_details,
        **@opts
      )
    end
    # Leere branch_ccs: kein Ergebnis-Record erzeugt, kein HTTP-Aufruf
    assert_kind_of Array, result
    assert_empty result
    client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 4: GamePlanSyncer erbt von ApplicationService
  # ---------------------------------------------------------------------------
  test "GamePlanSyncer inherits from ApplicationService" do
    assert RegionCc::GamePlanSyncer < ApplicationService
  end

  # ---------------------------------------------------------------------------
  # Test 5: .call class method vorhanden
  # ---------------------------------------------------------------------------
  test "responds to .call class method" do
    assert RegionCc::GamePlanSyncer.respond_to?(:call)
  end

  # ---------------------------------------------------------------------------
  # Test 6: private sync methods sind nicht direkt aufrufbar
  # ---------------------------------------------------------------------------
  test "sync_game_plans and sync_game_details are private" do
    syncer = RegionCc::GamePlanSyncer.new(
      region_cc: @region_cc,
      client: nil,
      operation: :sync_game_plans
    )
    assert_raises(NoMethodError) { syncer.sync_game_plans }
    assert_raises(NoMethodError) { syncer.sync_game_details }
  end
end
