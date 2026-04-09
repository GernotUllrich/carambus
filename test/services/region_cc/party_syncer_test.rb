# frozen_string_literal: true

require "test_helper"

# Unit tests for RegionCc::PartySyncer
# Verifiziert: Dispatcher-Pattern (.call(operation:)), ArgumentError fuer unbekannte Operationen,
# korrekte Weiterleitung an den injizierten Client.
# DB-Aufrufe werden nicht getestet — das ist Aufgabe von Integrationstests.
class RegionCc::PartySyncerTest < ActiveSupport::TestCase
  # Minimaler HTML-Stub fuer admin_report_showLeague: table mit Spieltag-Kopfzeile
  LEAGUE_REPORT_HTML = <<~HTML.freeze
    <html><body>
      <table><tr><td>
        <table><tr><td>
          <table>
            <tr><th>Nr.</th><th>Spieltag</th></tr>
          </table>
        </td></tr></table>
      </td></tr></table>
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
    @opts = { season_name: "2022/2023", armed: "1" }
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
      RegionCc::PartySyncer.call(
        region_cc: @region_cc,
        client: client,
        operation: :nonexistent_op
      )
    end
    client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 2: :sync_parties dispatches without error (empty BranchCcs)
  # ---------------------------------------------------------------------------
  test "sync_parties dispatches without error when no BranchCcs exist for context" do
    client = Minitest::Mock.new
    # BranchCc.where(context: "nbv") ist leer im Test — kein HTTP-Aufruf erwartet
    result = RegionCc::PartySyncer.call(
      region_cc: @region_cc,
      client: client,
      operation: :sync_parties,
      **@opts
    )
    assert_equal [[], []], result
    client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 3: :sync_party_games dispatches without error (empty list)
  # ---------------------------------------------------------------------------
  test "sync_party_games dispatches without error for empty parties_todo_ids" do
    client = Minitest::Mock.new
    assert_nothing_raised do
      RegionCc::PartySyncer.call(
        region_cc: @region_cc,
        client: client,
        operation: :sync_party_games,
        parties_todo_ids: [],
        **@opts
      )
    end
    client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 4: PartySyncer erbt von ApplicationService
  # ---------------------------------------------------------------------------
  test "PartySyncer inherits from ApplicationService" do
    assert RegionCc::PartySyncer < ApplicationService
  end

  # ---------------------------------------------------------------------------
  # Test 5: .call class method vorhanden
  # ---------------------------------------------------------------------------
  test "responds to .call class method" do
    assert RegionCc::PartySyncer.respond_to?(:call)
  end

  # ---------------------------------------------------------------------------
  # Test 6: private sync methods nicht direkt aufrufbar
  # ---------------------------------------------------------------------------
  test "sync_parties and sync_party_games are private" do
    syncer = RegionCc::PartySyncer.new(
      region_cc: @region_cc,
      client: nil,
      operation: :sync_parties
    )
    assert_raises(NoMethodError) { syncer.sync_parties }
    assert_raises(NoMethodError) { syncer.sync_party_games([]) }
  end

  # ---------------------------------------------------------------------------
  # Test 7: parties_todo_ids Keyword-Argument wird korrekt gespeichert
  # ---------------------------------------------------------------------------
  test "stores parties_todo_ids on initialization" do
    ids = [1, 2, 3]
    syncer = RegionCc::PartySyncer.new(
      region_cc: @region_cc,
      client: nil,
      operation: :sync_party_games,
      parties_todo_ids: ids
    )
    # Privates Attribut via send prüfen
    assert_equal ids, syncer.send(:instance_variable_get, :@parties_todo_ids)
  end
end
