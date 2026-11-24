# frozen_string_literal: true

require "test_helper"

class League::SeriesTableTest < ActiveSupport::TestCase
  BASE = 50_000_000 + 88_000

  setup do
    @region = regions(:bbl)
    @pool = disciplines(:branch_pool)
  end

  def league(id, name, season, **attrs)
    League.create!(id: BASE + id, name: name, shortname: "ST#{id}", organizer: @region,
      season: seasons(season), discipline: @pool, **attrs)
  end

  test "Zeile je Liga, Zelle je Saison, frühere Namen und Dubletten" do
    old = league(1, "Bezirksliga - Pool", :previous, synonyms: "Bezirksliga Pool\nBezirksliga - Pool", source_kind: "ba")
    league(2, "Bezirksliga - Pool", :current, source_kind: "club_cloud")
    Party.create!(id: BASE + 1, league: old)
    league(3, "Oberliga Pool", :previous)
    league(4, "Oberliga", :previous)
    league(5, "Oberliga - Pool", :current)

    region = League::SeriesTable.new.call.fetch(@region.shortname)
    rows = region["rows"].index_by(&:first)

    bezirk = rows.fetch("Bezirksliga - Pool")
    assert_equal "Pool", bezirk[1]
    assert_equal [1, 1, 0, "BA", 0], bezirk[2].fetch(seasons(:previous).name)
    assert_equal "CC", bezirk[2].fetch(seasons(:current).name)[3]
    assert_equal ["Bezirksliga Pool"], bezirk[3], "eigener Name zählt nicht als früherer"
    assert_equal 1, rows.fetch("Oberliga")[2].fetch(seasons(:previous).name)[4], "Dublette markiert"
    assert_equal region["seasons"], region["seasons"].sort.reverse
  end
end
