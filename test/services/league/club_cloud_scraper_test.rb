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

  # BLVN 2022/23: verein-details.php liefert für aufgelöste Vereine HTTP 410 ohne Tabelle. Früher brach
  # daran der ganze Liga-Scrape vor den Partien ab (`css` auf nil) — 15 von 18 Ligen blieben fast leer.
  test "parse_linked_teams übersteht eine fehlende Vereinsseite (HTTP 410)" do
    league = pool_league(31)
    club = nbv_club(3065, "BC Weg")
    team_page = "<html><body><aside><section><table></table><table></table>" \
      "<table><tr><td><a href='verein-details.php?p=19---3065'>BC Weg</a></td></tr></table></section></aside></body></html>"
    stub_request(:get, "#{CC_BASE}sb_mannschaft.php?p=19--2022/2023-31-0-175").to_return(status: 200, body: team_page)
    stub_request(:get, "#{CC_BASE}verein-details.php?p=19---3065").to_return(status: 410, body: "")
    scraper = scraper_for(league, nil)
    scraper.instance_variable_set(:@clubs_cache, [])
    scraper.instance_variable_set(:@league_teams_cache, [])

    scraper.send(:parse_linked_teams, [["BC Weg 1", "sb_mannschaft.php?p=19--2022/2023-31-0-175"]], CC_BASE)

    team = league.league_teams.find_by(cc_id: 175)
    assert team, "Team trotz fehlender Vereinsseite angelegt"
    assert_equal club.id, team.club_id
  end

  # DBU-Rescrape 2026-11-25: Auf billard-union.net übernimmt der Scraper die DBU-Nr. von der Vereinsseite.
  # Bei HTTP 410 blieb sie nil und wurde trotzdem geschrieben — 34 Vereine verloren ihre dbu_nr.
  DBU_BASE = "https://billard-union.net/"

  def dbu_team_page(club_cc_id)
    "<html><body><aside><section><table></table><table></table>" \
      "<table><tr><td><a href='verein-details.php?p=10---#{club_cc_id}'>BC Dbu</a></td></tr></table></section></aside></body></html>"
  end

  test "parse_linked_teams lässt die dbu_nr stehen, wenn die DBU-Vereinsseite fehlt (HTTP 410)" do
    league = pool_league(51)
    club = Club.create!(id: next_id, name: "BC Dbu", shortname: "BC Dbu", dbu_nr: 1851, region: regions(:nbv))
    stub_request(:get, "#{DBU_BASE}sb_mannschaft.php?p=10--2022/2023-51-0-185").to_return(status: 200, body: dbu_team_page(1851))
    stub_request(:get, "#{DBU_BASE}verein-details.php?p=10---1851").to_return(status: 410, body: "")
    scraper = scraper_for(league, nil)
    scraper.instance_variable_set(:@clubs_cache, [])
    scraper.instance_variable_set(:@league_teams_cache, [])

    scraper.send(:parse_linked_teams, [["BC Dbu 1", "sb_mannschaft.php?p=10--2022/2023-51-0-185"]], DBU_BASE)

    assert_equal 1851, club.reload.dbu_nr
    assert_equal club.id, league.league_teams.find_by(cc_id: 185)&.club_id
  end

  test "parse_linked_teams übernimmt eine gelesene DBU-Nr. weiterhin" do
    league = pool_league(52)
    club = Club.create!(id: next_id, name: "BC Dbu", shortname: "BC Dbu", region: regions(:nbv))
    club_page = "<html><body><aside><section><table><tr><td>DBU-Nr.</td><td>1852</td></tr></table></section></aside></body></html>"
    stub_request(:get, "#{DBU_BASE}sb_mannschaft.php?p=10--2022/2023-52-0-186").to_return(status: 200, body: dbu_team_page(1852))
    stub_request(:get, "#{DBU_BASE}verein-details.php?p=10---1852").to_return(status: 200, body: club_page)
    scraper = scraper_for(league, nil)
    scraper.instance_variable_set(:@clubs_cache, [])
    scraper.instance_variable_set(:@league_teams_cache, [])

    scraper.send(:parse_linked_teams, [["BC Dbu 1", "sb_mannschaft.php?p=10--2022/2023-52-0-186"]], DBU_BASE)

    assert_equal 1852, club.reload.dbu_nr
  end

  # BLVN 2022/23: Spielernamen mit Tabulatoren; ein unbekannter Spieler brach früher (raise) die ganze Liga ab.
  test "parse_linked_teams bereinigt Namen, nimmt Namens-Treffer nur eindeutig und überspringt Unbekannte" do
    league = pool_league(41)
    club = nbv_club(3070, "PBC Nord")
    unique = Player.create!(id: next_id, firstname: "Richard", lastname: "Degenhardt")
    twins = 2.times.map { Player.create!(id: next_id, firstname: "Jan", lastname: "Fischer") }
    row = ->(name, nr) { "<tr><td><a href='#'>x</a></td><td><a href='sb_spieler.php?p=19--2022/2023-41-#{nr}'>#{name}</a></td></tr>" }
    team_page = "<html><body><aside><section><table></table><table></table><table>" \
      "<tr><td><a href='verein-details.php?p=19---3070'>PBC Nord</a></td></tr>" +
      row.call("Richard\t\t\t Degenhardt", 10238) + row.call("Jan\t\t Fischer", 10342) + row.call("Rainald Lamping", 10746) +
      "</table></section></aside></body></html>"
    stub_request(:get, "#{CC_BASE}sb_mannschaft.php?p=19--2022/2023-41-0-176").to_return(status: 200, body: team_page)
    stub_request(:get, "#{CC_BASE}verein-details.php?p=19---3070").to_return(status: 410, body: "")
    scraper = scraper_for(league, nil)
    scraper.instance_variable_set(:@clubs_cache, [])
    scraper.instance_variable_set(:@league_teams_cache, [])

    scraper.send(:parse_linked_teams, [["PBC Nord 1", "sb_mannschaft.php?p=19--2022/2023-41-0-176"]], CC_BASE)

    team = league.league_teams.find_by!(cc_id: 176)
    assert_equal club.id, team.club_id
    assert_equal [unique.id], Seeding.where(league_team: team).pluck(:player_id), "nur der eindeutige Spieler"
    assert_nil twins.first.reload.cc_id, "Namensvetter bekommt keine fremde cc_id"
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

  # Doppelmitgliedschaft (2026-11-25: „Team 1.PBC Mahlow 2: Verein cc_id 11208 unbekannt — übersprungen“):
  # Der Verein ist anderswo beheimatet, seine NBV-cc_id steht nur in ClubCcEntry.
  test "add_schedule_teams findet einen anderswo beheimateten Verein über ClubCcEntry" do
    league = pool_league(358)
    home = Region.create!(name: "Heimatverband e.V.", shortname: "HOMV", cc_id: 22, public_cc_url_base: "https://home-cc.example/")
    queue = Club.create!(id: next_id, name: "BC Queue Hamburg", shortname: "BC Queue Hamburg", cc_id: 2739, region: home)
    ClubCcEntry.record!(queue, regions(:nbv), 1009)
    scraper = scraper_for(league, nil)
    scraper.instance_variable_set(:@region_id, regions(:nbv).id)
    scraper.instance_variable_set(:@league_teams_cache, [])

    scraper.send(:add_schedule_teams, cc_doc("ndbv_spielplan_oberliga_pool_2026_27"))

    team = league.league_teams.find_by!(name: "BC Queue Hamburg 3")
    assert_equal queue.id, team.club_id
    assert_equal 2739, queue.reload.cc_id, "Heimat-cc_id bleibt"
  end
end
