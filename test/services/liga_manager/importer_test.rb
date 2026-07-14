# frozen_string_literal: true

require "test_helper"

module LigaManager
  # Tests des DB-schreibenden Struktur-Importers (10-01). Stub-Scraper statt Live-API; die
  # Carambus-Records werden inline angelegt. Prüft Match-Zählung, Idempotenz und Mutationsfreiheit
  # im dry-run. LocalProtector ist in Tests deaktiviert (test_helper).
  class ImporterTest < ActiveSupport::TestCase
    # Minimaler Scraper-Ersatz: liefert Fixture-nahe Hashes ohne HTTP.
    class StubScraper
      def seasons = [{"id" => 1}]

      def leagues(_season_id)
        [{"id" => 5, "name" => "Mehrkampf Oberliga", "game_type_name" => "Karambol"}]
      end

      def teams(_league_id)
        [{"id" => 15, "name" => "TuS Weida Mehrkampf 1", "team_number" => 1, "club_id" => 99}]
      end

      def clubs
        [
          {"id" => 99, "asso_no" => 16, "name" => "TuS Weida"},
          {"id" => 98, "asso_no" => 5, "name" => "1. Erfurter BC"},
          {"id" => 97, "asso_no" => 999, "name" => "SV Sömmerda"}
        ]
      end

      # Roster nur für LM-Club 99 (= @club_cc, asso_no 16); andere Vereine leer.
      def members(club_id)
        return [] unless club_id == 99

        [
          {"id" => 275, "first_name" => "Jens", "last_name" => "Schumann", "_status" => 1},  # eindeutig
          {"id" => 999, "first_name" => "Max", "last_name" => "Mustermann", "_status" => 1}, # Doppelname → ambiguous
          {"id" => 888, "first_name" => "Ghost", "last_name" => "Player", "_status" => 1},   # kein Roster-Treffer
          {"id" => 777, "first_name" => "Inaktiv", "last_name" => "Exmitglied", "_status" => 0} # inaktiv → gefiltert
        ]
      end

      # Rangliste je Disziplin (leagues/{id}/ranking): Spielername = "Nachname, Vorname".
      def ranking(_league_id)
        {
          "1band" => [
            {"Spielername" => "Schumann, Jens", "team_id" => 15, "player_id" => 275, "club_id" => 99},
            {"Spielername" => "Mustermann, Max", "team_id" => 15, "player_id" => 999, "club_id" => 99},
            {"Spielername" => "Player, Ghost", "team_id" => 15, "player_id" => 888, "club_id" => 99},
            {"Spielername" => "Fremd, Ohne Team", "team_id" => 4242, "player_id" => 1, "club_id" => 99}
          ],
          "cadre352" => [
            # derselbe Spieler in zweiter Disziplin desselben Teams → Dedup auf 1 Seeding
            {"Spielername" => "Schumann, Jens", "team_id" => 15, "player_id" => 275, "club_id" => 99}
          ]
        }
      end
    end

    setup do
      @region = Region.find_or_create_by!(name: "LM-Test-TBV") { |r| r.shortname = "LMTBV" }
      @season = Season.find_or_create_by!(name: "LM-Test 2025/2026")
      @discipline = Discipline.find_or_create_by!(name: "Karambol")
      @club_cc = Club.create!(region_id: @region.id, cc_id: 16, name: "TuS Weida", shortname: "TuSW")
      @club_ba = Club.create!(region_id: @region.id, ba_id: 5, name: "1. Erfurter BC", shortname: "1EBC")
      @league = League.create!(region_id: @region.id, season_id: @season.id, discipline: @discipline,
        name: "Mehrkampf Oberliga")
      @team = LeagueTeam.create!(league_id: @league.id, club_id: @club_cc.id, name: "TuS Weida Mehrkampf 1")

      # Vereins-Saison-Roster von @club_cc: ein eindeutiger Spieler + zwei gleichnamige (Ambiguität).
      @player_matched = Player.create!(firstname: "Jens", lastname: "Schumann")
      @player_amb1 = Player.create!(firstname: "Max", lastname: "Mustermann")
      @player_amb2 = Player.create!(firstname: "Max", lastname: "Mustermann")
      [@player_matched, @player_amb1, @player_amb2].each do |p|
        SeasonParticipation.create!(club_id: @club_cc.id, season_id: @season.id, player_id: p.id)
      end
    end

    def importer(armed: false)
      Importer.new(association_id: 1, region_id: @region.id, season_id: @season.id,
        armed: armed, scraper: StubScraper.new)
    end

    test "reconcile_clubs matcht über cc_id ODER ba_id, meldet unmatched" do
      r = importer.reconcile_clubs
      assert_equal 2, r[:matched]
      assert_equal ["999 — SV Sömmerda"], r[:unmatched]
    end

    test "dry-run schreibt keine source_url" do
      importer.reconcile_clubs
      assert_nil @club_cc.reload.source_url
      assert_nil @club_ba.reload.source_url
    end

    test "ARMED setzt source_url und ist idempotent" do
      r1 = importer(armed: true).reconcile_clubs
      assert_equal 2, r1[:updated]
      assert_equal "https://ligen.billard.center/api/clubs/public?association_id=1&asso_no=16",
        @club_cc.reload.source_url

      r2 = importer(armed: true).reconcile_clubs
      assert_equal 0, r2[:updated], "2. Lauf darf nichts mehr ändern (idempotent)"
    end

    test "import_leagues matcht League über Branch+Name und setzt source_url (ARMED)" do
      r = importer(armed: true).import_leagues
      assert_equal 1, r[:matched]
      assert_equal "https://ligen.billard.center/api/leagues/5", @league.reload.source_url
    end

    test "import_leagues matcht wortreihenfolge-insensitiv (Token-Sort)" do
      @league.update!(name: "Oberliga Mehrkampf") # umgestellt ggü. LM "Mehrkampf Oberliga"
      r = importer(armed: true).import_leagues
      assert_equal 1, r[:matched]
      assert_equal "https://ligen.billard.center/api/leagues/5", @league.reload.source_url
    end

    test "import_leagues matcht echte Wortvariante NICHT (bleibt unmatched)" do
      @league.update!(name: "Dreiband Staffel") # keine Token-Übereinstimmung mit "Mehrkampf Oberliga"
      r = importer(armed: true).import_leagues
      assert_equal 0, r[:matched]
      assert_equal 1, r[:unmatched].size
    end

    test "import_teams matcht Team über Verein+Team-Nummer" do
      r = importer(armed: true).import_teams
      assert_equal 1, r[:matched]
      assert_equal "https://ligen.billard.center/api/teams?league_id=5&id=15", @team.reload.source_url
    end

    test "reconcile_players matcht eindeutigen Namen und setzt source_url (ARMED)" do
      r = importer(armed: true).reconcile_players
      assert_equal 1, r[:matched]
      assert_equal "https://ligen.billard.center/api/members/public?club_id=99&id=275",
        @player_matched.reload.source_url
    end

    test "reconcile_players meldet Doppelnamen als ambiguous ohne Zuordnung" do
      r = importer(armed: true).reconcile_players
      assert_equal 1, r[:ambiguous].size
      assert_match(/Max Mustermann/, r[:ambiguous].first)
      assert_nil @player_amb1.reload.source_url
      assert_nil @player_amb2.reload.source_url
    end

    test "reconcile_players meldet member ohne Roster-Treffer als unmatched" do
      r = importer.reconcile_players
      assert(r[:unmatched].any? { |u| u.include?("Ghost Player") })
    end

    test "reconcile_players filtert inaktive LM-Mitglieder (_status != 1)" do
      r = importer.reconcile_players
      assert(r[:unmatched].none? { |u| u.include?("Inaktiv Exmitglied") },
        "inaktives Mitglied darf weder matched noch unmatched erzeugen")
    end

    test "reconcile_players ist idempotent im ARMED-Lauf" do
      importer(armed: true).reconcile_players
      r2 = importer(armed: true).reconcile_players
      assert_equal 0, r2[:updated]
    end

    test "reconcile_players dry-run schreibt keine source_url" do
      importer.reconcile_players
      assert_nil @player_matched.reload.source_url
    end

    test "voller dry-run mutiert keine Record-Anzahl" do
      counts = -> { [Club.count, League.count, LeagueTeam.count, Player.count, SeasonParticipation.count, Seeding.count] }
      before = counts.call
      importer.run
      assert_equal before, counts.call, "Importer legt keine Records an"
    end

    test "reconcile_seedings zählt bestehendes Seeding als matched, ohne Create" do
      Seeding.create!(league_team_id: @team.id, player_id: @player_matched.id)
      before = Seeding.count
      r = importer(armed: true).reconcile_seedings
      assert_equal 1, r[:seedings_matched]
      assert_equal 0, r[:seedings_created]
      assert_equal before, Seeding.count
    end

    test "reconcile_seedings legt fehlendes Seeding an (ARMED) und setzt SP-Provenienz" do
      assert_difference -> { Seeding.count }, 1 do
        r = importer(armed: true).reconcile_seedings
        assert_equal 1, r[:seedings_created]
        assert_equal 1, r[:sp_updated]
      end
      seeding = Seeding.find_by(league_team_id: @team.id, player_id: @player_matched.id)
      assert_not_nil seeding
      assert_equal "https://ligen.billard.center/api/members/public?club_id=99&id=275",
        SeasonParticipation.find_by(player_id: @player_matched.id, club_id: @club_cc.id,
          season_id: @season.id).source_url
    end

    test "reconcile_seedings ist idempotent im ARMED-Lauf" do
      importer(armed: true).reconcile_seedings
      assert_no_difference -> { Seeding.count } do
        r2 = importer(armed: true).reconcile_seedings
        assert_equal 0, r2[:seedings_created]
        assert_equal 1, r2[:seedings_matched]
      end
    end

    test "reconcile_seedings dry-run legt kein Seeding an" do
      assert_no_difference -> { Seeding.count } do
        r = importer.reconcile_seedings
        assert_equal 1, r[:seedings_created], "würde anlegen, aber dry-run schreibt nicht"
      end
    end

    test "reconcile_seedings dedupt denselben Spieler über mehrere Disziplin-Ranglisten" do
      assert_difference -> { Seeding.count }, 1 do
        r = importer(armed: true).reconcile_seedings
        assert_equal 1, r[:seedings_created], "Jens Schumann steht in 1band + cadre352 → 1 Seeding"
      end
    end

    test "reconcile_seedings meldet Doppelnamen als ambiguous und Ghost/Fremd-Team als unmatched" do
      r = importer.reconcile_seedings
      assert(r[:ambiguous].any? { |a| a.include?("Mustermann, Max") })
      assert(r[:unmatched].any? { |u| u.include?("Player, Ghost") })
      assert(r[:unmatched].any? { |u| u.include?("nicht migriert") })
    end

    test "assign_club_identity setzt cc_id auf eindeutigen Namens-Treffer (ARMED)" do
      club = Club.create!(region_id: @region.id, name: "SV Sömmerda", shortname: "SVS") # cc_id nil
      r = importer(armed: true).assign_club_identity({1567 => "Sömmerda"})
      assert_equal 1, r[:assigned]
      assert_equal 1567, club.reload.cc_id
    end

    test "assign_club_identity dry-run schreibt kein cc_id" do
      club = Club.create!(region_id: @region.id, name: "SV Sömmerda", shortname: "SVS")
      r = importer.assign_club_identity({1567 => "Sömmerda"})
      assert_equal 1, r[:would_assign]
      assert_nil club.reload.cc_id
    end

    test "assign_club_identity ist idempotent (2. Lauf ändert nichts)" do
      Club.create!(region_id: @region.id, name: "SV Sömmerda", shortname: "SVS")
      importer(armed: true).assign_club_identity({1567 => "Sömmerda"})
      r2 = importer(armed: true).assign_club_identity({1567 => "Sömmerda"})
      assert_equal 0, r2[:assigned]
    end

    test "assign_club_identity überspringt mehrdeutige Treffer (keine Zuordnung)" do
      Club.create!(region_id: @region.id, name: "SV Sömmerda Nord", shortname: "SVN")
      Club.create!(region_id: @region.id, name: "SV Sömmerda Süd", shortname: "SVSU")
      r = importer(armed: true).assign_club_identity({1567 => "Sömmerda"})
      assert_equal 0, r[:assigned]
      assert_equal 1, r[:skipped].size
    end

    test "assign_club_identity lässt ba_id unangetastet" do
      club = Club.create!(region_id: @region.id, name: "SV Sömmerda", shortname: "SVS", ba_id: 999)
      importer(armed: true).assign_club_identity({1567 => "Sömmerda"})
      assert_equal 999, club.reload.ba_id
      assert_equal 1567, club.reload.cc_id
    end
  end
end
