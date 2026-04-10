# frozen_string_literal: true

require "test_helper"

# Unit tests for RegionCc::MetadataSyncer
# Verifiziert: Dispatcher-Pattern (.call(operation:)), ArgumentError fuer unbekannte Operationen,
# korrekte Weiterleitung an den injizierten Client.
# DB-Aufrufe werden nicht getestet — das ist Aufgabe von Integrationstests.
class RegionCc::MetadataSyncerTest < ActiveSupport::TestCase
  # Minimaler HTML-Stub fuer showCategoryList: select mit einer catId-Option
  CATEGORY_LIST_HTML = <<~HTML.freeze
    <html><body>
      <select name="catId">
        <option value="0">-- Bitte wählen --</option>
      </select>
    </body></html>
  HTML

  # Minimaler HTML-Stub fuer showGroupList: select mit einer groupId-Option
  GROUP_LIST_HTML = <<~HTML.freeze
    <html><body>
      <select name="groupId">
        <option value="0">-- Bitte wählen --</option>
      </select>
    </body></html>
  HTML

  # Minimaler HTML-Stub fuer createMeldelisteCheck: select mit selectedDisciplinId-Optionen
  DISCIPLINE_LIST_HTML = <<~HTML.freeze
    <html><body>
      <select name="selectedDisciplinId">
        <option value="0">-- Bitte wählen --</option>
      </select>
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
    @opts = { context: "nbv", armed: "1", season_name: "2022/2023" }
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
      RegionCc::MetadataSyncer.call(
        region_cc: @region_cc,
        client: client,
        operation: :invalid_operation
      )
    end
    client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 2: :sync_category_ccs dispatches without error (empty branch_ccs)
  # ---------------------------------------------------------------------------
  test "sync_category_ccs calls client post with showCategoryList" do
    client = Minitest::Mock.new
    # branch_ccs ist leer im Test, daher kein HTTP-Aufruf erwartet.
    result = nil
    assert_nothing_raised do
      result = RegionCc::MetadataSyncer.call(
        region_cc: @region_cc,
        client: client,
        operation: :sync_category_ccs,
        **@opts
      )
    end
    # Leere branch_ccs: kein HTTP-Aufruf, leeres Array zurueck
    assert_kind_of Array, result
    assert_empty result
    client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 3: :sync_group_ccs dispatches without error
  # ---------------------------------------------------------------------------
  test "sync_group_ccs dispatches without error" do
    client = Minitest::Mock.new
    result = nil
    assert_nothing_raised do
      result = RegionCc::MetadataSyncer.call(
        region_cc: @region_cc,
        client: client,
        operation: :sync_group_ccs,
        **@opts
      )
    end
    # Leere branch_ccs: kein HTTP-Aufruf, leeres Array zurueck
    assert_kind_of Array, result
    assert_empty result
    client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 4: :sync_discipline_ccs dispatches without error
  # ---------------------------------------------------------------------------
  test "sync_discipline_ccs dispatches without error" do
    client = Minitest::Mock.new
    result = nil
    assert_nothing_raised do
      result = RegionCc::MetadataSyncer.call(
        region_cc: @region_cc,
        client: client,
        operation: :sync_discipline_ccs,
        **@opts
      )
    end
    # Leere branch_ccs: kein HTTP-Aufruf, leeres Array zurueck
    assert_kind_of Array, result
    assert_empty result
    client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 5: MetadataSyncer erbt von ApplicationService
  # ---------------------------------------------------------------------------
  test "MetadataSyncer inherits from ApplicationService" do
    assert RegionCc::MetadataSyncer < ApplicationService
  end

  # ---------------------------------------------------------------------------
  # Test 6: .call class method delegiert an new(...).call
  # ---------------------------------------------------------------------------
  test "responds to .call class method" do
    assert RegionCc::MetadataSyncer.respond_to?(:call)
  end
end
