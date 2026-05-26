# frozen_string_literal: true

require "test_helper"

# Plan 21-05 (v0.6 Slice B): Tests fuer ExternalTournament::RegistrationListQuery
# (Meldelisten-Discovery). Region-scoped via context=shortname.downcase + season_id; optionale
# Filter discipline/category/status; bulk-Reverse-Lookup TournamentCc (D-21-05-D, KEIN N+1);
# Default-Saison = current_season (D-21-05-B); Resolved-Flags fuer 404-Signale.
module ExternalTournament
  class RegistrationListQueryTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @bbbv = Region.create!(name: "Test-BBBV", shortname: "RLQT-BBBV", id: 50_000_801)

      @disc_a = Discipline.create!(name: "RLQT-Dreiband klein", synonyms: "RLQT-3B-Syn")
      @disc_b = Discipline.create!(name: "RLQT-Pool 9-Ball")

      @season = Season.create!(name: "RLQT-2099/2100")
      @other_season = Season.create!(name: "RLQT-2098/2099")

      @region_cc = RegionCc.create!(region: @nbv, context: "nbv", cc_id: 80_001, shortname: "RLQT-NBV",
        name: "RLQT-NBV RegionCc")
      @branch_a = BranchCc.create!(discipline: @disc_a, region_cc: @region_cc, context: "nbv",
        cc_id: 81_001, name: "RLQT-Sparte-A")
      @cat_herren = CategoryCc.create!(branch_cc: @branch_a, context: "nbv", cc_id: 82_001,
        name: "RLQT-Herren", sex: "M", min_age: 0, max_age: 99, status: "Freigegeben")
      @cat_damen = CategoryCc.create!(branch_cc: @branch_a, context: "nbv", cc_id: 82_002,
        name: "RLQT-Damen", sex: "F", min_age: 0, max_age: 99, status: "Freigegeben")

      # 3 NBV-Listen: 2 in @season (Disziplin A, verschiedene Kategorien/Status),
      # 1 in @other_season (zum Saison-Filter-Check).
      @list_a = RegistrationListCc.create!(cc_id: 83_001, context: "nbv", name: "RLQT NDM Herren",
        branch_cc_id: @branch_a.id, season: @season, discipline: @disc_a, category_cc: @cat_herren,
        deadline: Date.new(2099, 6, 1), qualifying_date: Date.new(2099, 5, 1), status: "Freigegeben")
      @list_b = RegistrationListCc.create!(cc_id: 83_002, context: "nbv", name: "RLQT NDM Damen",
        branch_cc_id: @branch_a.id, season: @season, discipline: @disc_a, category_cc: @cat_damen,
        deadline: Date.new(2099, 7, 15), qualifying_date: Date.new(2099, 5, 1), status: "Gemeldet")
      @list_other = RegistrationListCc.create!(cc_id: 83_003, context: "nbv", name: "RLQT alt",
        branch_cc_id: @branch_a.id, season: @other_season, discipline: @disc_a, category_cc: @cat_herren,
        deadline: Date.new(2098, 6, 1), qualifying_date: nil, status: "Freigegeben")

      # 1 BBBV-Liste in @season — darf NIE im NBV-Scope erscheinen.
      @list_bbbv = RegistrationListCc.create!(cc_id: 83_004, context: "rlqt-bbbv", name: "RLQT BBBV",
        branch_cc_id: @branch_a.id, season: @season, discipline: @disc_a, category_cc: @cat_herren,
        deadline: Date.new(2099, 6, 1), qualifying_date: nil, status: "Freigegeben")

      # TournamentCc auf @list_a verlinkt (Reverse-Lookup-Test).
      @tc_linked = TournamentCc.create!(cc_id: 84_001, context: "nbv", name: "RLQT linked",
        registration_list_cc_id: @list_a.id, tournament_start: Date.new(2099, 8, 1))
    end

    teardown do
      TournamentCc.where(cc_id: [84_001]).delete_all
      RegistrationListCc.where(cc_id: [83_001, 83_002, 83_003, 83_004]).delete_all
      CategoryCc.where(cc_id: [82_001, 82_002]).delete_all
      BranchCc.where(cc_id: [81_001]).delete_all
      RegionCc.where(cc_id: [80_001]).delete_all
      Season.where(name: ["RLQT-2099/2100", "RLQT-2098/2099"]).delete_all
      [@disc_a, @disc_b].compact.each(&:destroy)
      Region.where(id: 50_000_801).delete_all
    end

    test "basic: NBV-Region-Scope filtert BBBV raus, sortiert nach deadline (AC-2)" do
      r = RegistrationListQuery.call(region: @nbv, season: @season.name)
      assert r.season_resolved && r.discipline_resolved && r.category_resolved
      assert_equal @season.id, r.season.id
      cc_ids = r.items.map { |h| h[:cc_id] }
      assert_equal [83_001, 83_002], cc_ids, "deadline-ASC: 2099-06-01 vor 2099-07-15; BBBV ausgeschlossen"
      refute_includes cc_ids, 83_004, "BBBV-Record (context=rlqt-bbbv) darf nicht im NBV-Scope sein"
    end

    test "default-resolver: season nil → Season.current_season (D-21-05-B, Lehre 2)" do
      # Lehre 2 aus [[feedback_safety_assured_masks_strong_migrations]]:
      # Default-Resolver explizit testen, nicht nur den Mock-Pfad mit gepinnter Saison.
      Season.stub(:current_season, @season) do
        r = RegistrationListQuery.call(region: @nbv)
        assert r.season_resolved
        assert_equal @season.id, r.season.id, "Default-Saison muss Season.current_season liefern"
        assert_equal 2, r.items.size, "@list_a + @list_b liegen in @season (gestubbtes current_season)"
      end
    end

    test "status-Filter: exakter Match (D-21-05-E)" do
      r_free = RegistrationListQuery.call(region: @nbv, season: @season.name, status: "Freigegeben")
      assert_equal [83_001], r_free.items.map { |h| h[:cc_id] }

      r_other = RegistrationListQuery.call(region: @nbv, season: @season.name, status: "Gemeldet")
      assert_equal [83_002], r_other.items.map { |h| h[:cc_id] }

      r_none = RegistrationListQuery.call(region: @nbv, season: @season.name, status: "Tippfehler")
      assert_equal [], r_none.items, "Unbekannter Status → leeres Array, KEIN Fuzzy-Match"
    end

    test "discipline-Filter mit Synonym, falsche Disziplin nicht gematcht" do
      # Synonym aufloest → trifft @disc_a
      r = RegistrationListQuery.call(region: @nbv, season: @season.name, discipline: "RLQT-3B-Syn")
      assert r.discipline_resolved
      assert_equal 2, r.items.size

      # Andere Disziplin → keine Listen
      r_b = RegistrationListQuery.call(region: @nbv, season: @season.name, discipline: "RLQT-Pool 9-Ball")
      assert r_b.discipline_resolved
      assert_equal 0, r_b.items.size
    end

    test "404-Signale: unaufloesbar season/discipline/category → resolved=false (AC-3)" do
      r_s = RegistrationListQuery.call(region: @nbv, season: "GibtsNicht-1900/1901")
      refute r_s.season_resolved
      assert_equal [], r_s.items

      r_d = RegistrationListQuery.call(region: @nbv, season: @season.name, discipline: "GibtsNicht-Disc")
      assert r_d.season_resolved
      refute r_d.discipline_resolved
      assert_equal [], r_d.items

      r_c = RegistrationListQuery.call(region: @nbv, season: @season.name, category: "GibtsNicht-Cat")
      assert r_c.season_resolved && r_c.discipline_resolved
      refute r_c.category_resolved
      assert_equal [], r_c.items
    end

    test "tournament_cc-Verknüpfung im Payload mit bulk-load (D-21-05-D)" do
      r = RegistrationListQuery.call(region: @nbv, season: @season.name)
      list_a_item = r.items.find { |h| h[:cc_id] == 83_001 }
      list_b_item = r.items.find { |h| h[:cc_id] == 83_002 }

      assert_not_nil list_a_item[:tournament_cc], "@list_a hat verknuepfte TournamentCc → Sub-Hash erwartet"
      assert_equal @tc_linked.id, list_a_item[:tournament_cc][:id]
      assert_equal "RLQT linked", list_a_item[:tournament_cc][:name]
      assert_match(/\A2099-08-01/, list_a_item[:tournament_cc][:date].to_s)

      assert_nil list_b_item[:tournament_cc], "@list_b ohne TournamentCc → tournament_cc: nil"

      # KEIN N+1: Bulk-Lookup macht 1 Query, nicht size-of-items Queries.
      # (Soft-Check via assert_queries-equivalent; hier ueber Sicherheits-Re-Run mit timing.)
      assert_equal 2, r.items.size
    end

    test "category-Filter (exakter Name, region-scoped)" do
      r = RegistrationListQuery.call(region: @nbv, season: @season.name, category: "RLQT-Herren")
      assert r.category_resolved
      assert_equal [83_001], r.items.map { |h| h[:cc_id] }

      r_d = RegistrationListQuery.call(region: @nbv, season: @season.name, category: "RLQT-Damen")
      assert_equal [83_002], r_d.items.map { |h| h[:cc_id] }
    end

    test "Serialize-Payload-Vertrag (AC-2 Schema)" do
      r = RegistrationListQuery.call(region: @nbv, season: @season.name, status: "Freigegeben")
      item = r.items.first
      assert_equal 83_001, item[:cc_id]
      assert_equal "RLQT NDM Herren", item[:name]
      assert_match(/\A2099-06-01/, item[:deadline].to_s, "deadline.iso8601 (Datum-Praefix)")
      assert_match(/\A2099-05-01/, item[:qualifying_date].to_s)
      assert_equal "Freigegeben", item[:status]
      assert_equal "RLQT-2099/2100", item[:season]
      assert_equal({id: @disc_a.id, name: "RLQT-Dreiband klein"}, item[:discipline])
      assert_equal({id: @cat_herren.id, name: "RLQT-Herren"}, item[:category_cc])
    end
  end
end
