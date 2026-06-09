# frozen_string_literal: true

require "test_helper"

# Plan 23-01 T3b: RegistrationListQuery liest jetzt aus TournamentCc statt
# RegistrationListCc. Payload-Vertrag bleibt; Status-Filter ist no-op.
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

      # 3 NBV-TCcs mit meldeliste_cc_id: 2 in @season (verschiedene Kategorien),
      # 1 in @other_season für Saison-Filter-Check.
      @tcc_a = TournamentCc.create!(cc_id: 84_001, context: "nbv", name: "RLQT NDM Herren",
        season: @season.name, discipline: @disc_a, category_cc: @cat_herren,
        meldeliste_cc_id: 83_001,
        meldeliste_deadline: Date.new(2099, 6, 1),
        meldeliste_qualifying_date: Date.new(2099, 5, 1),
        tournament_start: Date.new(2099, 8, 1))
      @tcc_b = TournamentCc.create!(cc_id: 84_002, context: "nbv", name: "RLQT NDM Damen",
        season: @season.name, discipline: @disc_a, category_cc: @cat_damen,
        meldeliste_cc_id: 83_002,
        meldeliste_deadline: Date.new(2099, 7, 15),
        meldeliste_qualifying_date: Date.new(2099, 5, 1))
      @tcc_other = TournamentCc.create!(cc_id: 84_003, context: "nbv", name: "RLQT alt",
        season: @other_season.name, discipline: @disc_a, category_cc: @cat_herren,
        meldeliste_cc_id: 83_003,
        meldeliste_deadline: Date.new(2098, 6, 1))

      # 1 BBBV-TCc in @season — darf NIE im NBV-Scope erscheinen.
      @tcc_bbbv = TournamentCc.create!(cc_id: 84_004, context: "rlqt-bbbv", name: "RLQT BBBV",
        season: @season.name, discipline: @disc_a, category_cc: @cat_herren,
        meldeliste_cc_id: 83_004,
        meldeliste_deadline: Date.new(2099, 6, 1))

      # TCc ohne meldeliste_cc_id — wird gefiltert (kein Meldeliste-Anchor).
      @tcc_no_ml = TournamentCc.create!(cc_id: 84_005, context: "nbv", name: "RLQT ohne ML",
        season: @season.name, discipline: @disc_a, category_cc: @cat_herren)
    end

    teardown do
      TournamentCc.where(cc_id: [84_001, 84_002, 84_003, 84_004, 84_005]).delete_all
      CategoryCc.where(cc_id: [82_001, 82_002]).delete_all
      BranchCc.where(cc_id: [81_001]).delete_all
      RegionCc.where(cc_id: [80_001]).delete_all
      Season.where(name: ["RLQT-2099/2100", "RLQT-2098/2099"]).delete_all
      [@disc_a, @disc_b].compact.each(&:destroy)
      Region.where(id: 50_000_801).delete_all
    end

    test "basic: NBV-Region-Scope filtert BBBV raus, sortiert nach meldeliste_deadline" do
      r = RegistrationListQuery.call(region: @nbv, season: @season.name)
      assert r.season_resolved && r.discipline_resolved && r.category_resolved
      assert_equal @season.id, r.season.id
      cc_ids = r.items.map { |h| h[:cc_id] }
      assert_equal [83_001, 83_002], cc_ids, "deadline-ASC: 2099-06-01 vor 2099-07-15; BBBV ausgeschlossen"
      refute_includes cc_ids, 83_004, "BBBV-Record (context=rlqt-bbbv) darf nicht im NBV-Scope sein"
      refute_includes cc_ids, nil, "TCc ohne meldeliste_cc_id wird gefiltert"
    end

    test "default-resolver: season nil → Season.current_season" do
      Season.stub(:current_season, @season) do
        r = RegistrationListQuery.call(region: @nbv)
        assert r.season_resolved
        assert_equal @season.id, r.season.id
        assert_equal 2, r.items.size
      end
    end

    test "status-Filter ist no-op nach T3b (kein Persist-Status mehr)" do
      r_free = RegistrationListQuery.call(region: @nbv, season: @season.name, status: "Freigegeben")
      r_gemeldet = RegistrationListQuery.call(region: @nbv, season: @season.name, status: "Gemeldet")
      r_garbage = RegistrationListQuery.call(region: @nbv, season: @season.name, status: "Tippfehler")
      r_none = RegistrationListQuery.call(region: @nbv, season: @season.name)

      assert_equal r_none.items.map { |h| h[:cc_id] }, r_free.items.map { |h| h[:cc_id] },
        "status-Filter ist no-op: gleiche Ergebnisse wie ohne status"
      assert_equal r_none.items.map { |h| h[:cc_id] }, r_gemeldet.items.map { |h| h[:cc_id] }
      assert_equal r_none.items.map { |h| h[:cc_id] }, r_garbage.items.map { |h| h[:cc_id] }
    end

    test "discipline-Filter mit Synonym, falsche Disziplin nicht gematcht" do
      r = RegistrationListQuery.call(region: @nbv, season: @season.name, discipline: "RLQT-3B-Syn")
      assert r.discipline_resolved
      assert_equal 2, r.items.size

      r_b = RegistrationListQuery.call(region: @nbv, season: @season.name, discipline: "RLQT-Pool 9-Ball")
      assert r_b.discipline_resolved
      assert_equal 0, r_b.items.size
    end

    test "404-Signale: unaufloesbar season/discipline/category → resolved=false" do
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

    test "tournament_cc-Sub-Hash bleibt im Payload (Vertragstreue)" do
      r = RegistrationListQuery.call(region: @nbv, season: @season.name)
      item_a = r.items.find { |h| h[:cc_id] == 83_001 }

      assert_not_nil item_a[:tournament_cc]
      assert_equal @tcc_a.id, item_a[:tournament_cc][:id]
      assert_equal "RLQT NDM Herren", item_a[:tournament_cc][:name]
      assert_match(/\A2099-08-01/, item_a[:tournament_cc][:date].to_s)
    end

    test "category-Filter (exakter Name, region-scoped)" do
      r = RegistrationListQuery.call(region: @nbv, season: @season.name, category: "RLQT-Herren")
      assert r.category_resolved
      assert_equal [83_001], r.items.map { |h| h[:cc_id] }

      r_d = RegistrationListQuery.call(region: @nbv, season: @season.name, category: "RLQT-Damen")
      assert_equal [83_002], r_d.items.map { |h| h[:cc_id] }
    end

    test "Serialize-Payload-Vertrag (Schema bleibt)" do
      r = RegistrationListQuery.call(region: @nbv, season: @season.name, category: "RLQT-Herren")
      item = r.items.first
      assert_equal 83_001, item[:cc_id]
      assert_equal "RLQT NDM Herren", item[:name]
      assert_match(/\A2099-06-01/, item[:deadline].to_s)
      assert_match(/\A2099-05-01/, item[:qualifying_date].to_s)
      assert_nil item[:status], "status ist nil im T3b-Vertrag (kein Persist mehr)"
      assert_equal "RLQT-2099/2100", item[:season]
      assert_equal({id: @disc_a.id, name: "RLQT-Dreiband klein"}, item[:discipline])
      assert_equal({id: @cat_herren.id, name: "RLQT-Herren"}, item[:category_cc])
    end
  end
end
