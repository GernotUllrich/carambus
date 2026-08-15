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

  # Die Herkunft haengt am URL-MUSTER des Quellsystems, nicht an der Domain: jeder Landesverband
  # betreibt seine ClubCloud unter eigenem Namen, liefert aber dieselben Skripte aus.
  test "erkennt die Quelle am URL-Muster, nicht an der Domain" do
    tournament(@dreiband, source_url: "https://ndbv.de/sb_meisterschaft.php?p=20--2026/2027-46-")
    tournament(@dreiband, source_url: "https://www.blv-sa.de/sb_meisterschaft.php?p=21--2026/2027-2-")
    tournament(@dreiband, source_url: "https://bbv-billard.liga.nu/cgi-bin/WebObjects/nuLigaBILLARDDE.woa/wa/x")
    tournament(@dreiband, source_url: "https://ligen.billard.center/api/leagues/1")
    tournament(@dreiband, source_url: "https://tbv.carambus.de/tournaments/50000021")
    tournament(@dreiband, source_url: nil)

    kinds = Reports::CoverageData.for(Tournament).sources["#{@karambol.id}|#{@region.id}|#{@season.id}"]

    assert_equal 2, kinds[:cc], "beide CC-Installationen zaehlen als ClubCloud, trotz anderer Domain"
    assert_equal 1, kinds[:nu_liga]
    assert_equal 1, kinds[:liga_manager]
    assert_equal 1, kinds[:carambus]
    assert_equal 1, kinds[:none], "ohne source_url bleibt es bei 'keine Angabe' — nicht bei 'CC'"
  end

  # Betreiber 2026-08-06: der Altbestand ohne source_url stammt aus der BillardArea. Die Quelle ist
  # offline, deshalb gibt es keine URL — die `ba_id` ist die einzige Spur. Gegenprobe in den Daten:
  # von 4 719 Turnieren MIT source_url trug kein einziges eine ba_id.
  test "ohne source_url, aber mit ba_id ist BillardArea" do
    tournament(@dreiband, ba_id: 4711)
    tournament(@dreiband, source_url: nil, ba_id: nil)

    kinds = Reports::CoverageData.for(Tournament).sources["#{@karambol.id}|#{@region.id}|#{@season.id}"]

    assert_equal 1, kinds[:billard_area]
    assert_equal 1, kinds[:none], "ohne beide Spuren bleibt es bei 'keine Angabe'"
  end

  test "eine spaeter nachgescrapte CC-URL schlaegt die ba_id" do
    tournament(@dreiband, ba_id: 4712,
      source_url: "https://ndbv.de/sb_meisterschaft.php?p=20--2026/2027-46-")

    kinds = Reports::CoverageData.for(Tournament).sources["#{@karambol.id}|#{@region.id}|#{@season.id}"]

    assert_equal 1, kinds[:cc], "wo eine Quell-URL steht, gewinnt sie"
    assert_equal 0, kinds[:billard_area], "die ba_id darf daneben nicht mitzaehlen"
  end

  test "kennzeichnet Regionen ohne CC-Anschluss" do
    tournament(@dreiband)

    region = Reports::CoverageData.for(Tournament).regions.find { |r| r[:id] == @region.id }

    assert_equal Region::SHORTNAMES_CC.key?(@region.shortname), region[:cc],
      "das Flag muss der Liste folgen, die den Scrape wirklich steuert"
  end

  test "meta weist die Quellenverteilung aus" do
    tournament(@dreiband, source_url: "https://ndbv.de/sb_spielplan.php?p=20--2026/2027-1")

    meta = Reports::CoverageData.for(Tournament).meta

    assert_operator meta[:sources][:cc], :>=, 1
    assert meta[:sources].key?(:none), "die Gruppe ohne Quellenangabe muss sichtbar bleiben"
  end

  test "liefert dieselbe Form fuer Ligen" do
    League.create!(name: "Testliga 1", shortname: "TL1", season: @season,
      region_id: @region.id, discipline: @acht)

    result = Reports::CoverageData.for(League)

    assert_equal 1, result.cells["#{@pool.id}|#{@region.id}|#{@season.id}"]
    assert result.meta.key?(:with_branch_id), "meta muss die branch_id-Quote ausweisen"
  end
end
