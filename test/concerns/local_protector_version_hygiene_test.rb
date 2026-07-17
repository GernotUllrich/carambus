# frozen_string_literal: true

require "test_helper"

# Version-Hygiene (LocalProtector / PaperTrail)
#
# Auf der Authority (carambus_api_url leer) konfiguriert LocalProtector
# has_paper_trail so, dass beim Speichern eines globalen Records KEINE Version
# entstehen soll, wenn sich nur operative Felder (updated_at, sync_date) ändern.
# Fachliche Änderungen erzeugen weiterhin genau eine Version mit vollständigem
# changeset (Sync braucht alle Spalten).
#
# Diese Tests sind das SOLL (AC-1..3 aus 19-01-PLAN). Vor dem Fix
# (skip: statt unless:) laufen die operative-only-Fälle ROT.
class LocalProtectorVersionHygieneTest < ActiveSupport::TestCase
  setup do
    skip_unless_api_server
    @pt_was_enabled = PaperTrail.request.enabled?
    PaperTrail.request.enabled = true
    assert Region.column_names.include?("sync_date"),
      "Region muss eine sync_date-Spalte haben (Testvoraussetzung)"
  end

  teardown do
    PaperTrail.request.enabled = @pt_was_enabled
  end

  # AC-1: operative-only-Änderung erzeugt keine Version
  test "sync_date-only Update erzeugt keine Version" do
    region = Region.create!(name: "ZZ Hygiene A", shortname: "ZZHA")
    assert_no_difference -> { region.versions.count } do
      region.update!(sync_date: Time.current)
    end
  end

  # AC-1: touch (nur updated_at) erzeugt keine Version
  test "touch (updated_at) erzeugt keine Version" do
    region = Region.create!(name: "ZZ Hygiene B", shortname: "ZZHB")
    assert_no_difference -> { region.versions.count } do
      region.touch
    end
  end

  # AC-2: fachliche Änderung erzeugt genau eine Version mit vollständigem changeset
  test "fachliche Änderung erzeugt genau eine Version mit name im changeset" do
    region = Region.create!(name: "ZZ Hygiene C", shortname: "ZZHC")
    assert_difference -> { region.versions.count }, 1 do
      region.update!(name: "ZZ Hygiene C2")
    end
    assert_includes region.versions.last.changeset.keys, "name",
      "changeset muss die fachliche Spalte 'name' enthalten (volle Serialisierung)"
  end

  # AC-3: Create erzeugt genau eine Version
  test "Create erzeugt genau eine Version" do
    region = nil
    assert_difference -> { PaperTrail::Version.where(item_type: "Region").count }, 1 do
      region = Region.create!(name: "ZZ Hygiene D", shortname: "ZZHD")
    end
    assert_equal 1, region.versions.count
  end

  # AC-3: fachlich + operativ gemeinsam → genau eine Version
  test "gemischte fachlich+operative Änderung erzeugt genau eine Version" do
    region = Region.create!(name: "ZZ Hygiene E", shortname: "ZZHE")
    assert_difference -> { region.versions.count }, 1 do
      region.update!(name: "ZZ Hygiene E2", sync_date: Time.current)
    end
  end
end
