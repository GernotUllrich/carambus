# frozen_string_literal: true

require "test_helper"

# Plan 20-02 (v0.6 F4): Tests fuer ExternalTournament::CategoryQuery (Kategorie-/Klassen-Discovery).
# player_classes via discipline.player_classes (D-20-02-A); category_ccs region-scoped via
# context=shortname.downcase + disziplin-scoped via branch_ccs.discipline_id (D-20-02-C);
# reiches categories[] + flache Listen (D-20-02-D); genders M/F/U (D-20-02-E).
module ExternalTournament
  class CategoryQueryTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @region_cc = RegionCc.create!(region: @nbv, context: "nbv", cc_id: 70_001, shortname: "NBV",
        name: "CQ RegionCc")

      # Disziplin A (mit player_classes "2"/"1" zum Sortier-Check) + zugehoerige Sparte + Kategorien.
      @disc_a = Discipline.create!(name: "CQ-Dreiband klein", synonyms: "CQ-3B klein")
      PlayerClass.create!(discipline: @disc_a, shortname: "2")
      PlayerClass.create!(discipline: @disc_a, shortname: "1") # bewusst "schlechter" eingefuegt
      @branch_a = BranchCc.create!(discipline: @disc_a, region_cc: @region_cc, context: "nbv",
        cc_id: 71_001, name: "CQ-Sparte-A")
      @cat_damen = CategoryCc.create!(branch_cc: @branch_a, context: "nbv", cc_id: 72_001,
        name: "CQ-Damen", sex: "F", min_age: 0, max_age: 99, status: "Freigegeben")
      @cat_herren = CategoryCc.create!(branch_cc: @branch_a, context: "nbv", cc_id: 72_002,
        name: "CQ-Herren", sex: "M", min_age: 0, max_age: 99, status: "Freigegeben")
      @cat_senioren = CategoryCc.create!(branch_cc: @branch_a, context: "nbv", cc_id: 72_003,
        name: "CQ-Senioren", sex: "M", min_age: 50, max_age: 99, status: "Freigegeben")

      # Disziplin B (andere Sparte) -> Kategorie darf beim Filter auf A NICHT erscheinen.
      @disc_b = Discipline.create!(name: "CQ-Pool 9-Ball")
      @branch_b = BranchCc.create!(discipline: @disc_b, region_cc: @region_cc, context: "nbv",
        cc_id: 71_002, name: "CQ-Sparte-B")
      @cat_unisex = CategoryCc.create!(branch_cc: @branch_b, context: "nbv", cc_id: 72_004,
        name: "CQ-Unisex", sex: "U", min_age: 0, max_age: 99, status: "Freigegeben")
    end

    teardown do
      CategoryCc.where(cc_id: [72_001, 72_002, 72_003, 72_004]).delete_all
      BranchCc.where(cc_id: [71_001, 71_002], context: "nbv").delete_all
      PlayerClass.where(discipline_id: [@disc_a&.id, @disc_b&.id].compact).delete_all
      [@disc_a, @disc_b].compact.each(&:destroy)
      @region_cc&.destroy
    end

    test "mit Disziplin: player_classes sortiert + nur Sparte-A-Kategorien (AC-1)" do
      result = CategoryQuery.call(region: @nbv, discipline_name: "CQ-Dreiband klein")
      assert result.discipline_resolved
      assert_equal %w[2 1], result.player_classes, "player_classes nach PLAYER_CLASS_ORDER (worst->best)"

      assert_equal %w[CQ-Damen CQ-Herren CQ-Senioren], result.age_classes
      refute_includes result.age_classes, "CQ-Unisex", "Kategorie anderer Sparte darf nicht erscheinen"
      cat_names = result.categories.map { |c| c[:name] }
      refute_includes cat_names, "CQ-Unisex"
      senioren = result.categories.find { |c| c[:name] == "CQ-Senioren" }
      assert_equal 50, senioren[:min_age]
      assert_equal "Freigegeben", senioren[:status]
    end

    test "Disziplin per Synonym aufloesbar (AC-1)" do
      result = CategoryQuery.call(region: @nbv, discipline_name: "CQ-3B klein")
      assert result.discipline_resolved
      assert_equal %w[2 1], result.player_classes
    end

    test "ohne Disziplin: player_classes leer + region-weite Kategorien (AC-2)" do
      result = CategoryQuery.call(region: @nbv)
      assert result.discipline_resolved
      assert_equal [], result.player_classes, "Leistungsklassen sind inhaerent disziplin-gebunden"
      # region-weit: Kategorien beider Sparten sind enthalten.
      assert_includes result.age_classes, "CQ-Damen"
      assert_includes result.age_classes, "CQ-Unisex"
    end

    test "unaufloesbare Disziplin -> discipline_resolved=false (AC-3)" do
      result = CategoryQuery.call(region: @nbv, discipline_name: "CQ-gibt-es-nicht")
      refute result.discipline_resolved
      assert_equal [], result.categories
    end

    test "genders sortiert M vor F, U ans Ende (D-20-02-E)" do
      result = CategoryQuery.call(region: @nbv)
      assert_equal %w[M F U], result.genders
    end

    test "blank region -> alles leer (defensiv)" do
      result = CategoryQuery.call(region: nil)
      assert_equal [], result.player_classes
      assert_equal [], result.age_classes
      assert_equal [], result.genders
      assert_equal [], result.categories
    end
  end
end
