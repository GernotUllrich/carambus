# frozen_string_literal: true

require "test_helper"

# Tests for League::ClubCloudScraper ApplicationService.
# Verifies guard clauses, error handling, and delegation via WebMock stubs.
class League::ClubCloudScraperTest < ActiveSupport::TestCase
  TEST_ID_BASE = 50_000_000
  ID_OFFSET = 90_000

  @@counter = 0

  def next_id
    @@counter += 1
    TEST_ID_BASE + ID_OFFSET + (@@counter * 100)
  end

  def create_test_league
    base = next_id
    League.create!(
      id: base,
      name: "CC Scraper Test League #{base}",
      shortname: "CCST#{@@counter}",
      organizer: regions(:nbv),
      organizer_type: "Region",
      season: seasons(:current),
      discipline: disciplines(:carom_3band),
      cc_id: base
    )
  end

  # Without league_details: true, call returns early (guard clause)
  test "call returns without error when league_details not set" do
    league = create_test_league
    assert_nothing_raised do
      League::ClubCloudScraper.call(league: league)
    end
  end

  # With league_details: true and HTTP returning empty HTML — no team table found, returns without error
  test "call handles empty HTML response without error" do
    league = create_test_league
    stub_request(:get, /sb_spielplan\.php/)
      .to_return(status: 200, body: "<html><body><aside><section></section></aside></body></html>",
                 headers: { "Content-Type" => "text/html" })

    assert_nothing_raised do
      League::ClubCloudScraper.call(league: league, league_details: true)
    end
  end

  # With league_details: true and HTTP timeout — broad rescue swallows the error
  test "call handles HTTP timeout without propagating error" do
    league = create_test_league
    stub_request(:get, /sb_spielplan\.php/).to_timeout

    assert_nothing_raised do
      League::ClubCloudScraper.call(league: league, league_details: true)
    end
  end

  # Robustes Datums-Parsing: valide DD.MM.YYYY parsen, malformte Zellen → nil (kein stilles Garbage-Datum,
  # das früher als Party-Datum landete: "21.02.206"→0206, "21.2."→heute, "01.01.1970"→1970 usw.)
  test "parse_cc_datetime parses valid dates and rejects malformed cells" do
    s = League::ClubCloudScraper.new
    assert_equal "2026-02-21 20:00",
      s.send(:parse_cc_datetime, "21.02.2026<br>20:00 Uhr").strftime("%Y-%m-%d %H:%M")
    assert_equal "2025-11-01 00:00",
      s.send(:parse_cc_datetime, "Sa, 01.11.2025").strftime("%Y-%m-%d %H:%M")
    ["21.02.206", "21.02.20", "9.1.1", "21.2.", "01.01.1970", "31.13.2026", "Termin folgt", ""].each do |bad|
      assert_nil s.send(:parse_cc_datetime, bad), "#{bad.inspect} sollte nil ergeben (kein Garbage-Datum)"
    end
  end
  # --- NBV-Pool/Snooker 2026/2027 (Befund 2026-09-18): echte ndbv.de-Staffelseiten als Fixtures ---
  # Landesliga Pool (cc 359): vor Saisonbeginn KEINE Tabelle, stattdessen „Mannschaft"-Liste in <center>;
  #   Spielplan OHNE GASTGEBER-Spalte → 7 td je Zeile; 9 Teams, 72 Begegnungen.
  # Oberliga Pool (cc 357): Teil-Tabelle (2 Teams, 1 Spiel), 7-td-Zeilen, 8 Teams, 56 Begegnungen.
  # Landesliga Snooker (cc 350): Teil-Tabelle (4 von 6 Teams), MIT GASTGEBER → 8 td, 30 Begegnungen.
  CC_BASE = "https://ndbv.de/"

  def cc_doc(name)
    # binär lesen wie Net::HTTP (ASCII-8BIT) — sonst verschluckt libxml2 die HTML5-Tags (aside/section)
    Nokogiri::HTML(File.binread(Rails.root.join("test/fixtures/files/club_cloud/#{name}.html")))
  end

  def pool_league(cc_id)
    base = next_id
    League.create!(id: base, name: "CC Pool #{base}", shortname: "CCP#{@@counter}", organizer: regions(:nbv),
      organizer_type: "Region", season: seasons(:current), discipline: disciplines(:pool_8ball), cc_id: cc_id)
  end

  def scraper_for(league, doc_name)
    scraper = League::ClubCloudScraper.new(league: league, league_details: true)
    scraper.instance_variable_set(:@league_url, "#{CC_BASE}sb_spielplan.php?p=20--2026/2027-#{league.cc_id}")
    scraper
  end

  # Teams für parse_parties vorbelegen (parse_teams braucht HTTP für Team-/Vereinsseiten)
  def seed_teams(scraper, league, doc)
    teams = doc.css("aside > section > table").last.css("tr").select { |tr| tr.css("td").count >= 7 }
      .flat_map { |tr| [tr.css("td")[2].text.strip, tr.css("td")[6].text.strip] }.uniq
    cache = teams.each_with_index.map { |name, i| league.league_teams.create!(id: league.id + i + 1, name: name) }
    scraper.instance_variable_set(:@league_teams_cache, cache)
    teams
  end

  def without_report_links(doc)
    doc.css("a[href^='sb_spielbericht']").each { |a| a.replace(a.text) }
    doc
  end

  test "cc_team_entries liest vor Saisonbeginn die Mannschafts-Liste (keine Tabelle)" do
    league = pool_league(359)
    entries = scraper_for(league, nil).send(:cc_team_entries, cc_doc("ndbv_spielplan_landesliga_pool_2026_27"))
    assert_equal 9, entries.size
    name, link = entries.find { |n, _| n == "1. PBV Pinneberg 4" }
    assert_equal "1. PBV Pinneberg 4", name
    # Teamseite im gewohnten sb_mannschaft-Format, Staffel (11) aus der Seite, Team-ID an Position 5
    assert_equal "sb_mannschaft.php?p=20--2026/2027-359-11-1723", link
  end

  test "cc_team_entries liest die Tabellen-Übersicht wie bisher" do
    league = pool_league(357)
    entries = scraper_for(league, nil).send(:cc_team_entries, cc_doc("ndbv_spielplan_oberliga_pool_2026_27"))
    assert_equal [["1. PBV Pinneberg 2", "sb_mannschaft.php?p=20--2026/2027-357-0-1721"],
      ["1. PBV Pinneberg 1", "sb_mannschaft.php?p=20--2026/2027-357-0-1720"]], entries
  end

  test "parse_parties übernimmt 7-Spalten-Zeilen ohne GASTGEBER (Landesliga Pool)" do
    league = pool_league(359)
    doc = cc_doc("ndbv_spielplan_landesliga_pool_2026_27")
    scraper = scraper_for(league, nil)
    seed_teams(scraper, league, doc)
    scraper.send(:parse_parties, doc, CC_BASE)
    assert_equal 72, league.parties.count
  end

  test "parse_parties übernimmt 7-Spalten-Zeilen ohne GASTGEBER (Oberliga Pool)" do
    league = pool_league(357)
    doc = without_report_links(cc_doc("ndbv_spielplan_oberliga_pool_2026_27"))
    scraper = scraper_for(league, nil)
    seed_teams(scraper, league, doc)
    scraper.send(:parse_parties, doc, CC_BASE)
    assert_equal 56, league.parties.count
  end

  test "parse_parties übernimmt weiterhin 8-Spalten-Zeilen mit GASTGEBER (Snooker, Regression)" do
    league = pool_league(350)
    doc = without_report_links(cc_doc("ndbv_spielplan_landesliga_snooker_2026_27"))
    scraper = scraper_for(league, nil)
    assert_equal 6, seed_teams(scraper, league, doc).size
    scraper.send(:parse_parties, doc, CC_BASE)
    assert_equal 30, league.parties.count
  end
  # Teil-Tabelle (Oberliga Pool: nur 2 von 8 Teams haben schon gespielt): die übrigen Teams stehen nur im
  # Spielplan (Name + Vereinswappen, ohne Link) → aus dem Spielplan anlegen, Verein über die Wappen-Nr.
  def nbv_club(cc_id, name)
    Club.create!(id: next_id, name: name, shortname: name, cc_id: cc_id, region: regions(:nbv))
  end

  test "add_schedule_teams legt fehlende Teams aus dem Spielplan an (Teil-Tabelle)" do
    league = pool_league(357)
    pinneberg = nbv_club(1004, "1. PBV Pinneberg")
    queue = nbv_club(1009, "BC Queue Hamburg")
    known = league.league_teams.create!(id: league.id + 1, name: "1. PBV Pinneberg 1", cc_id: 1720, club: pinneberg)
    scraper = scraper_for(league, nil)
    scraper.instance_variable_set(:@region_id, regions(:nbv).id)
    scraper.instance_variable_set(:@league_teams_cache, [known])
    scraper.send(:add_schedule_teams, cc_doc("ndbv_spielplan_oberliga_pool_2026_27"))

    cache = scraper.instance_variable_get(:@league_teams_cache)
    # nur Teams mit bekanntem Verein (hier Pinneberg + Queue); unbekannte Vereine werden übersprungen
    assert_equal ["1. PBV Pinneberg 1", "1. PBV Pinneberg 2", "BC Queue Hamburg 3"], cache.map(&:name).sort
    queue3 = cache.find { |lt| lt.name == "BC Queue Hamburg 3" }
    assert queue3.persisted?
    assert_nil queue3.cc_id
    assert_equal queue.id, queue3.club_id
    assert_equal 1, league.league_teams.where(name: "1. PBV Pinneberg 1").count, "bekanntes Team nicht doppelt"

    # erneuter Lauf legt nichts doppelt an
    scraper.instance_variable_set(:@league_teams_cache, [known])
    scraper.send(:add_schedule_teams, cc_doc("ndbv_spielplan_oberliga_pool_2026_27"))
    assert_equal 3, league.league_teams.count
  end
end
