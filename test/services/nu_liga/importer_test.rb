# frozen_string_literal: true

require "test_helper"

module NuLiga
  class ImporterTest < ActiveSupport::TestCase
    # Guard-Stub: apply_source_url ruft record.class.skip_cable_ready_updates { record.update!(...) }.
    module FakeGuard
      def self.skip_cable_ready_updates = yield
    end

    FakeClub = Struct.new(:id, :cc_id, :ba_id, :name, :shortname, :source_url) do
      def update!(attrs) = attrs.each { |k, v| self[k] = v }

      def class = FakeGuard
    end

    # --- reconcile_clubs: VNr-primär + Namens-Gegenprobe (Fakes, netzfrei, kein DB) ---

    def clubs_importer
      Importer.new(federation: "BBV", region_id: 3, season_id: 17, armed: true, scraper: Object.new)
    end

    test "reconcile_clubs sets source_url on VNr matches and flags name mismatches" do
      imp = clubs_importer
      def imp.nuliga_clubs
        [{club_id: 383, name: "Snooker-Pool-Club Hof e.V.", vnr: 1743},
          {club_id: 400, name: "NuLiga Andersname e.V.", vnr: 1770},   # VNr matcht, Name weicht ab
          {club_id: 999, name: "Unbekannter BC", vnr: 8888}]           # kein VNr-Treffer
      end
      hof = FakeClub.new(1, 1743, 1743, "Snooker-Pool-Club Hof e.V.", "SPC Hof", nil)
      other = FakeClub.new(2, 1770, 1770, "Ganz anderer Verein e.V.", "GAV", nil)
      def imp.carambus_clubs
        {list: [], by_cc: {1743 => @hof, 1770 => @other}, by_ba: {1743 => @hof, 1770 => @other}}
      end
      imp.instance_variable_set(:@hof, hof)
      imp.instance_variable_set(:@other, other)

      r = imp.reconcile_clubs
      assert_equal 2, r[:matched]                         # 1743 + 1770
      assert_equal 2, r[:updated]                         # beide source_url gesetzt
      assert_equal "https://bbv-billard.liga.nu/cgi-bin/WebObjects/nuLigaBILLARDDE.woa/wa/clubInfoDisplay?club=383", hof.source_url
      assert_equal 1, r[:name_mismatches].size            # 1770: Name weicht ab
      assert_equal 1770, r[:name_mismatches].first[:vnr]
      assert_equal ["8888 — Unbekannter BC"], r[:unmatched]
    end

    test "reconcile_clubs in dry-run does not write source_url" do
      imp = Importer.new(federation: "BBV", region_id: 3, season_id: 17, armed: false, scraper: Object.new)
      def imp.nuliga_clubs = [{club_id: 383, name: "SPC Hof e.V.", vnr: 1743}]
      hof = FakeClub.new(1, 1743, 1743, "SPC Hof e.V.", "SPC Hof", nil)
      def imp.carambus_clubs = {list: [], by_cc: {1743 => @hof}, by_ba: {1743 => @hof}}
      imp.instance_variable_set(:@hof, hof)

      r = imp.reconcile_clubs
      assert_equal 1, r[:matched]
      assert_equal 1, r[:updated]        # "würde" ändern
      assert_nil hof.source_url          # dry-run: nichts geschrieben
    end

    # --- create_leagues / create_teams: find-or-create + Idempotenz (Test-DB + FakeScraper) ---

    class FakeScraper
      def initialize(leagues:, teams: {}, team_clubs: {}, clubs: {}, rosters: {})
        @leagues = leagues
        @teams = teams
        @team_clubs = team_clubs
        @clubs = clubs
        @rosters = rosters
      end

      def leagues(branch) = @leagues[branch] || []

      def group(group_id, branch:) = {teams: @teams[group_id] || []}

      def team(teamtable_id, group_id:, branch:) = {club: {club_id: @team_clubs[teamtable_id]}}

      def club(club_id) = @clubs[club_id]

      def player_ranking(group_id, branch:) = @rosters[group_id] || []
    end

    def setup
      @region = Region.create!(name: "NuLiga Test Region", shortname: "NLT#{rand(100000)}")
      @season = Season.create!(name: "NuLiga Test Season #{rand(100000)}")
      @discipline = Discipline.find_by(name: "Pool") || Discipline.create!(name: "Pool")
    end

    def build_importer(scraper, armed: true)
      Importer.new(federation: "BBV", region_id: @region.id, season_id: @season.id,
        branches: ["Pool"], armed: armed, scraper: scraper)
    end

    test "create_leagues creates a new league and is idempotent on re-run" do
      scraper = FakeScraper.new(leagues: {"Pool" => [{group_id: 9001, name: "NuLiga Testliga A"}]})

      r1 = build_importer(scraper).create_leagues
      assert_equal 1, r1[:created]
      league = League.find_by(region_id: @region.id, season_id: @season.id, name: "NuLiga Testliga A")
      assert league, "League should be created"
      assert_equal @discipline.id, league.discipline_id
      assert_match(/groupPage\?group=9001/, league.source_url)

      # 2. Lauf (frische Instanz) findet die Liga über den Natur-Key → 0 created
      r2 = build_importer(scraper).create_leagues
      assert_equal 0, r2[:created]
      assert_equal 1, r2[:matched]
    end

    test "create_leagues skips branch without a matching Discipline" do
      scraper = FakeScraper.new(leagues: {"Karambol" => [{group_id: 9002, name: "Karambol-Liga X"}]})
      imp = Importer.new(federation: "BBV", region_id: @region.id, season_id: @season.id,
        branches: ["Karambol"], armed: true, scraper: scraper)
      r = imp.create_leagues
      assert_equal 0, r[:created]
      assert_equal 1, r[:skipped].size
    end

    test "create_teams creates league teams with club via VNr and is idempotent" do
      club = Club.create!(region_id: @region.id, cc_id: 1743, name: "Test Club e.V.", shortname: "TC")
      scraper = FakeScraper.new(
        leagues: {"Pool" => [{group_id: 9003, name: "NuLiga Testliga B"}]},
        teams: {9003 => [{teamtable_id: 5001, name: "Test Team 1"}]},
        team_clubs: {5001 => 701},
        clubs: {701 => {club_id: 701, name: "Test Club e.V.", vnr: 1743}}
      )

      imp = build_importer(scraper)
      imp.create_leagues
      r1 = imp.create_teams
      assert_equal 1, r1[:created]
      lt = LeagueTeam.find_by(name: "Test Team 1")
      assert lt, "LeagueTeam should be created"
      assert_equal club.id, lt.club_id
      assert_match(/teamPortrait\?teamtable=5001/, lt.source_url)

      imp2 = build_importer(scraper)
      imp2.create_leagues
      r2 = imp2.create_teams
      assert_equal 0, r2[:created]
    end

    test "create_teams sets club_id nil for VNr name mismatch (16-02 fix)" do
      # Carambus-Club VNr 1770 heißt „Schwebheim", NuLiga-Club vnr 1770 heißt „Schweinfurt" → Mismatch.
      Club.create!(region_id: @region.id, cc_id: 1770, name: "1. BSV Schwebheim e.V.", shortname: "BSV Schwebheim")
      scraper = FakeScraper.new(
        leagues: {"Pool" => [{group_id: 9010, name: "NuLiga Testliga M"}]},
        teams: {9010 => [{teamtable_id: 5010, name: "1. BSV Schweinfurt"}]},
        team_clubs: {5010 => 810},
        clubs: {810 => {club_id: 810, name: "1. BSV Schweinfurt e.V.", vnr: 1770}}
      )
      imp = build_importer(scraper)
      imp.reconcile_clubs   # füllt @mismatch_vnrs (1770)
      imp.create_leagues
      r = imp.create_teams
      assert_equal 1, r[:club_mismatch].size
      lt = LeagueTeam.find_by(name: "1. BSV Schweinfurt")
      assert lt
      assert_nil lt.club_id, "club_id soll bei Namens-Mismatch nil sein, nicht der falsche Verein"
    end

    def player_scenario
      Club.find_or_create_by!(region_id: @region.id, cc_id: 1743) do |c|
        c.name = "Test Club e.V."
        c.shortname = "TC"
      end
      FakeScraper.new(
        leagues: {"Pool" => [{group_id: 9020, name: "NuLiga Testliga P"}]},
        teams: {9020 => [{teamtable_id: 5020, name: "Test Team P"}]},
        team_clubs: {5020 => 720},
        clubs: {720 => {club_id: 720, name: "Test Club e.V.", vnr: 1743}},
        rosters: {9020 => [
          {person_id: 111, name: "Bekannt, Anna", team_name: "Test Team P"},
          {person_id: 222, name: "Neuling, Bernd", team_name: "Test Team P"}
        ]}
      )
    end

    test "reconcile_players matches existing region player, creates missing, links SP" do
      # bestehender Region-Player, Name = NuLiga „Bekannt, Anna" → normalize matcht „Bekannt Anna"
      Player.create!(region_id: @region.id, lastname: "Bekannt", firstname: "Anna")
      imp = build_importer(player_scenario)
      imp.create_leagues
      imp.create_teams
      r = imp.reconcile_players

      assert_equal 1, r[:matched]      # Bekannt, Anna
      assert_equal 1, r[:created]      # Neuling, Bernd (neu)
      assert Player.find_by(region_id: @region.id, lastname: "Neuling", firstname: "Bernd"), "neuer Player angelegt"
      club = Club.find_by(cc_id: 1743)
      assert_operator SeasonParticipation.where(club_id: club.id, season_id: @season.id).count, :>=, 2
    end

    test "reconcile_seedings creates seedings for roster and is idempotent" do
      Player.create!(region_id: @region.id, lastname: "Bekannt", firstname: "Anna")
      imp = build_importer(player_scenario)
      imp.create_leagues
      imp.create_teams
      imp.reconcile_players
      r1 = imp.reconcile_seedings
      assert_operator r1[:seedings_created], :>=, 2
      lt = LeagueTeam.find_by(name: "Test Team P")
      assert_operator Seeding.where(league_team_id: lt.id).count, :>=, 2

      # frische Instanz, gleicher Scraper → alles vorhanden → 0 created
      imp2 = build_importer(player_scenario)
      imp2.create_leagues
      imp2.create_teams
      imp2.reconcile_players
      r2 = imp2.reconcile_seedings
      assert_equal 0, r2[:seedings_created]
    end

    test "reconcile_players in dry-run does not create players" do
      imp = build_importer(player_scenario, armed: false)
      imp.create_leagues
      imp.create_teams
      before = Player.where(region_id: @region.id).count
      imp.reconcile_players
      assert_equal before, Player.where(region_id: @region.id).count
    end
  end
end
