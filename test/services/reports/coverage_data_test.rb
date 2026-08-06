# frozen_string_literal: true

require "test_helper"

# Die Abdeckungsmatrix haengt an EINER heiklen Entscheidung: der Zweig kommt aus der Wurzel des
# Disziplin-Baums, nicht aus `branch_id`. Diese Tests halten genau das fest — inklusive des Falls,
# der die Spalte disqualifiziert: ein Record MIT falscher branch_id muss trotzdem richtig einsortiert
# werden.
class Reports::CoverageDataTest < ActiveSupport::TestCase
  setup do
    Branch.reset_discipline_ids_cache!

    @karambol = Branch.create!(name: "Karambol Test")
    @pool = Branch.create!(name: "Pool Test")
    @dreiband = Discipline.create!(name: "Dreiband Test", super_discipline: @karambol)
    @acht = Discipline.create!(name: "8-Ball Test", super_discipline: @pool)

    Branch.reset_discipline_ids_cache!

    @region = regions(:nbv)
    @season = seasons(:current)
  end

  teardown { Branch.reset_discipline_ids_cache! }

  def tournament(discipline, **attrs)
    Tournament.create!(
      {title: "T#{SecureRandom.hex(3)}", shortname: "S#{SecureRandom.hex(3)}",
       season: @season, organizer: @region, region_id: @region.id,
       discipline: discipline, date: Time.zone.local(2026, 10, 10, 10, 0)}.merge(attrs)
    )
  end

  test "ordnet ueber die Wurzel des Disziplin-Baums ein, nicht ueber branch_id" do
    # Die Falle: branch_id zeigt auf den FALSCHEN Zweig. Genau deshalb wird sie nicht benutzt.
    tournament(@dreiband, branch_id: @pool.id)

    result = Reports::CoverageData.for(Tournament)

    assert_equal 1, result.cells["#{@karambol.id}|#{@region.id}|#{@season.id}"],
      "die Unterdisziplin gehoert unter ihre Wurzel Karambol"
    assert_nil result.cells["#{@pool.id}|#{@region.id}|#{@season.id}"],
      "die abweichende branch_id darf nicht zaehlen"
  end

  test "zaehlt je Zweig, Region und Saison zusammen" do
    2.times { tournament(@dreiband) }
    tournament(@acht)

    result = Reports::CoverageData.for(Tournament)

    assert_equal 2, result.cells["#{@karambol.id}|#{@region.id}|#{@season.id}"]
    assert_equal 1, result.cells["#{@pool.id}|#{@region.id}|#{@season.id}"]
  end

  test "Turniere ohne Region bleiben draussen und werden in meta ausgewiesen" do
    tournament(@dreiband)
    ohne_region = tournament(@dreiband)
    ohne_region.update_columns(region_id: nil)

    result = Reports::CoverageData.for(Tournament)

    assert_equal 1, result.cells["#{@karambol.id}|#{@region.id}|#{@season.id}"]
    assert_operator result.meta[:without_region], :>=, 1
  end

  test "eine Disziplin ausserhalb der Zweig-Baeume wird gemeldet statt gezaehlt" do
    frei = Discipline.create!(name: "Freischwebend Test")
    Branch.reset_discipline_ids_cache!
    tournament(frei)

    result = Reports::CoverageData.for(Tournament)

    refute result.cells.keys.any? { |k| k.start_with?("#{frei.id}|") }
    assert_operator result.meta[:unmapped], :>=, 1
  end

  test "Regionen stehen nach Menge, Saisons chronologisch nach Namen" do
    tournament(@dreiband)

    result = Reports::CoverageData.for(Tournament)

    totals = result.regions.map do |r|
      result.cells.sum { |key, n| (key.split("|")[1].to_i == r[:id]) ? n : 0 }
    end
    assert_equal totals.sort.reverse, totals, "Regionen absteigend nach Gesamtmenge"
    assert_equal result.seasons.map { |s| s[:name] }.sort, result.seasons.map { |s| s[:name] },
      "Saisons chronologisch ueber den Namen (id/ba_id sind verrutscht)"
  end

  test "liefert dieselbe Form fuer Ligen" do
    League.create!(name: "Testliga 1", shortname: "TL1", season: @season,
      region_id: @region.id, discipline: @acht)

    result = Reports::CoverageData.for(League)

    assert_equal 1, result.cells["#{@pool.id}|#{@region.id}|#{@season.id}"]
    assert result.meta.key?(:with_branch_id), "meta muss die branch_id-Quote ausweisen"
  end
end
