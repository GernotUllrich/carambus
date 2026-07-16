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
        [
          {"id" => 15, "name" => "TuS Weida Mehrkampf 1", "team_number" => 1, "club_id" => 99},
          {"id" => 16, "name" => "1. Erfurter BC 1", "team_number" => 1, "club_id" => 98}
        ]
      end

      # Begegnungen (match_plans): 81 bestehend+Ergebnis, 82 bestehend+leer (→ füllen),
      # 83 fehlend (→ anlegen), 84 Team fehlt in Carambus (→ unmatched).
      def match_plans(_league_id)
        [
          {"id" => 81, "home_team_id" => 15, "away_team_id" => 16, "scheduled_date" => "2025-10-01",
           "matchpoints" => {"total_home_points" => "5", "total_guest_points" => "3"},
           "home_team_name" => "TuS Weida Mehrkampf 1", "away_team_name" => "1. Erfurter BC 1"},
          {"id" => 82, "home_team_id" => 16, "away_team_id" => 15, "scheduled_date" => "2025-11-01",
           "matchpoints" => {"total_home_points" => "2", "total_guest_points" => "6"},
           "home_team_name" => "1. Erfurter BC 1", "away_team_name" => "TuS Weida Mehrkampf 1"},
          {"id" => 83, "home_team_id" => 15, "away_team_id" => 16, "scheduled_date" => "2026-01-15",
           "matchpoints" => {"total_home_points" => "7", "total_guest_points" => "1"},
           "home_team_name" => "TuS Weida Mehrkampf 1", "away_team_name" => "1. Erfurter BC 1"},
          {"id" => 84, "home_team_id" => 4242, "away_team_id" => 15, "scheduled_date" => "2026-02-01",
           "matchpoints" => {"total_home_points" => "3", "total_guest_points" => "3"},
           "home_team_name" => "Fremd 1", "away_team_name" => "TuS Weida Mehrkampf 1"}
        ]
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

      # Spielbericht je match_plan: Spiel 1 vollständig, Spiel 2 mit unbekannter Disziplin + Spieler.
      def match_report(match_plan_id)
        return {final_score: nil, games: []} unless match_plan_id.to_s == "81"

        {final_score: {home: 2, guest: 1},
         games: [
           {position: 1, discipline: "Dreiband", home_player: "Schumann, Jens", away_player: "Gast, Anton",
            set_result: "2:0", match_points: "2:0", stats: {factor: 1, balls: {home: 120, guest: 90}}},
           {position: 2, discipline: "UnbekannteDisziplinXYZ", home_player: "Niemand, Unbekannt",
            away_player: "Gast, Anton", set_result: "0:2", match_points: "0:2", stats: nil}
         ]}
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
      @team_b = LeagueTeam.create!(league_id: @league.id, club_id: @club_ba.id, name: "1. Erfurter BC 1")

      # Bestehende Begegnungen: eine mit Ergebnis (81), eine mit LEEREM Ergebnis (82 → füllbar).
      @party_ab = Party.create!(league_id: @league.id, league_team_a_id: @team.id, league_team_b_id: @team_b.id,
        date: "2025-10-01", data: {"result" => "5:3"})
      @party_ba_empty = Party.create!(league_id: @league.id, league_team_a_id: @team_b.id, league_team_b_id: @team.id,
        date: "2025-11-01", data: {"result" => ""})

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

    # Für import_party_games: @party_ab bekommt match-plans-source_url; Seedings der beiden Teams
    # (Heim Jens Schumann, Gast Anton Gast) + Disziplin "Dreiband" mit Synonym.
    def setup_party_games_scenario
      @party_ab.update!(source_url: "https://ligen.billard.center/api/match-plans/81")
      @away_player = Player.create!(firstname: "Anton", lastname: "Gast")
      Seeding.create!(league_team_id: @team.id, player_id: @player_matched.id)
      Seeding.create!(league_team_id: @team_b.id, player_id: @away_player.id)
      d = Discipline.find_or_create_by!(name: "Dreiband")
      d.update!(synonyms: "Dreiband") unless d.synonyms.to_s.split("\n").include?("Dreiband")
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
      assert_equal 2, r[:matched] # @team (15) + @team_b (16)
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
      counts = -> { [Club.count, League.count, LeagueTeam.count, Player.count, SeasonParticipation.count, Seeding.count, Party.count, PartyGame.count] }
      before = counts.call
      importer.run
      assert_equal before, counts.call, "Importer legt keine Records an"
    end

    test "import_party_games legt Einzelspiele an (ARMED)" do
      setup_party_games_scenario
      assert_difference -> { PartyGame.where(party_id: @party_ab.id).count }, 2 do
        r = importer(armed: true).import_party_games
        assert_equal 1, r[:parties_processed]
        assert_equal 2, r[:games_created]
      end
      g1 = PartyGame.find_by(party_id: @party_ab.id, seqno: 1)
      assert_equal "Spiel 1::Dreiband", g1.name
      assert_equal "Dreiband", g1.discipline&.name
      assert_equal @player_matched.id, g1.player_a_id
      assert_equal @away_player.id, g1.player_b_id
      assert_equal "2:0", g1.data["result"]
    end

    test "import_party_games ist robust bei unbekannter Disziplin/Spieler" do
      setup_party_games_scenario
      r = importer(armed: true).import_party_games
      g2 = PartyGame.find_by(party_id: @party_ab.id, seqno: 2)
      assert_not_nil g2
      assert_nil g2.discipline_id
      assert_nil g2.player_a_id
      assert_equal @away_player.id, g2.player_b_id
      assert_operator r[:disciplines_unmatched], :>=, 1
      assert_operator r[:players_unmatched], :>=, 1
    end

    test "import_party_games ist idempotent (2. ARMED-Lauf)" do
      setup_party_games_scenario
      importer(armed: true).import_party_games
      assert_no_difference -> { PartyGame.count } do
        r2 = importer(armed: true).import_party_games
        assert_equal 0, r2[:games_created]
      end
    end

    test "import_party_games dry-run schreibt nicht" do
      setup_party_games_scenario
      assert_no_difference -> { PartyGame.count } do
        r = importer.import_party_games
        assert_equal 2, r[:games_created]
      end
    end

    test "import_party_games überspringt Party ohne match-plans-source_url" do
      r = importer.import_party_games
      assert_operator r[:parties_skipped], :>=, 1
    end

    test "import_party_games lässt Party mit bestehenden Einzelspielen unberührt" do
      setup_party_games_scenario
      PartyGame.create!(party_id: @party_ab.id, seqno: 1, name: "bestehend")
      r = importer(armed: true).import_party_games
      assert_equal 0, r[:parties_processed]
    end

    test "check_game_plans meldet ok bei gleicher Spielanzahl (read-only, kein Schreiben)" do
      gp = GamePlan.create!(name: "TP", data: {"rows" => [
        {"type" => "Neue Runde"}, {"seqno" => 1, "type" => "Dreiband"}, {"seqno" => 2, "type" => "Dreiband"}
      ]})
      @league.update!(game_plan_id: gp.id)
      before = [GamePlan.count, PartyGame.count]
      rows = importer.check_game_plans
      row = rows.find { |r| r[:league] == @league.name }
      assert_equal 2, row[:gameplan_games] # zwei seqno-Zeilen im GamePlan
      assert_equal 2, row[:lm_games]       # StubScraper.match_report(81) liefert 2 Spiele
      assert_equal :ok, row[:status]
      assert_equal before, [GamePlan.count, PartyGame.count], "check ist read-only"
    end

    test "reconcile_parties: matched/filled/created/unmatched Übersicht (dry-run)" do
      r = importer.reconcile_parties
      assert_equal 2, r[:matched]       # 81 (@party_ab) + 82 (@party_ba_empty)
      assert_equal 1, r[:created]       # 83 fehlt
      assert_equal 1, r[:filled]        # 82 leer → würde füllen
      assert_equal 1, r[:unmatched].size # 84 (Team 4242 fehlt)
    end

    test "reconcile_parties setzt source_url, ohne bestehendes Ergebnis zu ändern (ARMED)" do
      importer(armed: true).reconcile_parties
      assert_equal "5:3", @party_ab.reload.data["result"], "vorhandenes Ergebnis unverändert"
      assert_match %r{/api/match-plans/81}, @party_ab.source_url
    end

    test "reconcile_parties füllt leeres Ergebnis (ARMED)" do
      importer(armed: true).reconcile_parties
      assert_equal "2:6", @party_ba_empty.reload.data["result"]
    end

    test "reconcile_parties legt fehlende Begegnung an (ARMED) mit korrekten Feldern" do
      assert_difference -> { Party.count }, 1 do
        importer(armed: true).reconcile_parties
      end
      p = Party.find_by(source_url: "https://ligen.billard.center/api/match-plans/83")
      assert_not_nil p
      assert_equal @league.id, p.league_id
      assert_equal [@team.id, @team_b.id], [p.league_team_a_id, p.league_team_b_id]
      assert_equal @team.id, p.host_league_team_id
      assert_equal "2026-01-15", p.date.to_date.to_s
      assert_equal "7:1", p.data["result"]
    end

    test "reconcile_parties ist idempotent (2. ARMED-Lauf)" do
      importer(armed: true).reconcile_parties
      r2 = importer(armed: true).reconcile_parties
      assert_equal 0, r2[:created]
      assert_equal 0, r2[:updated]
      assert_equal 0, r2[:filled]
    end

    test "reconcile_parties dry-run schreibt nicht" do
      assert_no_difference -> { Party.count } do
        r = importer.reconcile_parties
        assert_equal 1, r[:created]
      end
      assert_equal "", @party_ba_empty.reload.data["result"], "dry-run füllt nicht"
    end

    test "reconcile_parties meldet Begegnung mit fehlendem Team als unmatched" do
      r = importer.reconcile_parties
      assert(r[:unmatched].any? { |u| u.include?("Fremd 1") })
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

    # Phase 12 (v0.4 TBV-Cutover): Zielsaison-Auflösung für Cron/Tasks.
    test "resolve_season_id: explizites Argument hat Vorrang vor current_season" do
      fake = Struct.new(:id).new(1234)
      Season.stub(:current_season, fake) do
        assert_equal 17, Importer.resolve_season_id("17")
        assert_equal 42, Importer.resolve_season_id("42")
      end
    end

    test "resolve_season_id: ohne Argument → Season.current_season" do
      fake = Struct.new(:id).new(1234)
      Season.stub(:current_season, fake) do
        assert_equal 1234, Importer.resolve_season_id(nil)
        assert_equal 1234, Importer.resolve_season_id(""), "leerer String zählt als nicht gesetzt (presence)"
      end
    end

    test "resolve_season_id: Fallback 17, wenn keine current_season existiert" do
      Season.stub(:current_season, nil) do
        assert_equal 17, Importer.resolve_season_id(nil)
      end
    end
  end
end
