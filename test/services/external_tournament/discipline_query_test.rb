# frozen_string_literal: true

require "test_helper"

# Plan 20-01 (v0.6 F3): Tests fuer ExternalTournament::DisciplineQuery (Disziplin-Discovery).
# Region-Relevanz (D-20-01-A): Disziplinen mit PlayerRankings ODER Tournaments in der Region.
# Normalisiertes Payload (D-20-01-D) + volle TournamentPlan-Felder inkl. Executor (D-20-01-E).
module ExternalTournament
  class DisciplineQueryTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @season = Season.create!(name: "DQ-2099/2100")

      # Disziplin A: per PlayerRanking region-relevant + DTP-Matrix (2 Klassen auf einem Plan).
      @table_kind = TableKind.create!(name: "DQ Small Billard")
      @super = Discipline.create!(name: "DQ-Dreiband")
      @disc_a = Discipline.create!(name: "DQ-Dreiband klein", synonyms: "DQ-3B klein",
        table_kind: @table_kind, super_discipline: @super)
      @pc1 = PlayerClass.create!(discipline: @disc_a, shortname: "2")
      @pc2 = PlayerClass.create!(discipline: @disc_a, shortname: "1") # bewusst "schlechter" eingefuegt
      @plan = TournamentPlan.create!(name: "DQ-Default8", players: 8, tables: 2, ngroups: 1, nrepeats: 1,
        rulesystem: "DQ-RS", executor_class: "DQ::Exec", executor_params: "k: v",
        more_description: "mehr", even_more_description: "noch mehr")
      DisciplineTournamentPlan.create!(discipline: @disc_a, tournament_plan: @plan,
        players: 8, player_class: "1", points: 40, innings: 20)
      DisciplineTournamentPlan.create!(discipline: @disc_a, tournament_plan: @plan,
        players: 8, player_class: "2", points: 30, innings: 20)
      @player = Player.create!(firstname: "DQ", lastname: "Tester", region_id: @nbv.id, cc_id: 198_001, dbu_nr: 98_001)
      PlayerRanking.create!(region_id: @nbv.id, season_id: @season.id, discipline_id: @disc_a.id,
        player_id: @player.id, rank: 1, gd: 1.0)

      # Disziplin B: per Tournament region-relevant, OHNE DTP -> parameters [].
      @disc_b = Discipline.create!(name: "DQ-Freie Partie klein")
      @tournament = Tournament.new(title: "DQ-Tourn", region_id: @nbv.id, discipline_id: @disc_b.id,
        season_id: @season.id)
      @tournament.save(validate: false) # Tournament verlangt season+organizer+data; Query liest nur region/discipline

      # Disziplin C: KEIN Region-Bezug -> darf nicht erscheinen.
      @disc_c = Discipline.create!(name: "DQ-Snooker irrelevant")
    end

    teardown do
      DisciplineTournamentPlan.where(discipline_id: [@disc_a&.id, @disc_b&.id, @disc_c&.id].compact).delete_all
      PlayerRanking.where(discipline_id: @disc_a&.id).delete_all
      Player.where(id: @player&.id).delete_all
      Tournament.where(id: @tournament&.id).delete_all
      @plan&.destroy
      [@disc_a, @disc_b, @disc_c, @super].compact.each(&:destroy)
      [@pc1, @pc2].compact.each { |pc| pc.destroy if PlayerClass.exists?(pc.id) }
      @table_kind&.destroy
      @season&.destroy
    end

    test "nur region-relevante Disziplinen (Rankings ODER Tournaments), C fehlt (AC-1)" do
      result = DisciplineQuery.call(region: @nbv)
      names = result.disciplines.map { |d| d[:name] }
      assert_includes names, "DQ-Dreiband klein", "Disziplin mit Ranking-Bezug"
      assert_includes names, "DQ-Freie Partie klein", "Disziplin mit Tournament-Bezug"
      refute_includes names, "DQ-Snooker irrelevant", "Disziplin ohne Region-Bezug darf nicht erscheinen"
    end

    test "Disziplin-Meta: synonyms ohne Namen, table_kind, super_discipline, player_classes (AC-1)" do
      result = DisciplineQuery.call(region: @nbv)
      a = result.disciplines.find { |d| d[:name] == "DQ-Dreiband klein" }
      assert_equal "DQ Small Billard", a[:table_kind]
      assert_equal "DQ-Dreiband", a[:super_discipline]
      refute_includes a[:synonyms], "DQ-Dreiband klein", "der Name selbst ist kein Synonym (D-15-02)"
      assert_includes a[:synonyms], "DQ-3B klein"
      # PLAYER_CLASS_ORDER ist worst->best (7,6,5,4,3,2,1,...) -> "2" vor "1".
      assert_equal %w[2 1], a[:player_classes], "player_classes nach PLAYER_CLASS_ORDER (2 vor 1)"
    end

    test "Disziplin ohne DTP-Zeilen -> parameters [] (AC-1)" do
      result = DisciplineQuery.call(region: @nbv)
      b = result.disciplines.find { |d| d[:name] == "DQ-Freie Partie klein" }
      assert_equal [], b[:parameters]
    end

    test "normalisierte DTP-Matrix: parameters referenzieren Plan per Name (AC-2)" do
      result = DisciplineQuery.call(region: @nbv)
      a = result.disciplines.find { |d| d[:name] == "DQ-Dreiband klein" }
      assert_equal 2, a[:parameters].size
      first = a[:parameters].first
      assert_equal "DQ-Default8", first[:tournament_plan]
      assert_equal 8, first[:players]
      assert_equal "1", first[:player_class]
      assert_equal 40, first[:points]
      assert_equal 20, first[:innings]
      # Referenz-Integritaet: jeder parameters-Plan-Name ist Key im tournament_plans-Dict.
      a[:parameters].each do |row|
        assert_includes result.tournament_plans.keys, row[:tournament_plan]
      end
    end

    test "tournament_plans-Dict: volle Felder inkl. Executor (AC-2 / D-20-01-E)" do
      result = DisciplineQuery.call(region: @nbv)
      plan = result.tournament_plans["DQ-Default8"]
      assert_not_nil plan
      assert_equal 8, plan[:players]
      assert_equal 2, plan[:tables]
      assert_equal 1, plan[:ngroups]
      assert_equal 1, plan[:nrepeats]
      assert_equal "DQ-RS", plan[:rulesystem]
      assert_equal "DQ::Exec", plan[:executor_class]
      assert_equal "k: v", plan[:executor_params]
      assert_equal "mehr", plan[:more_description]
      assert_equal "noch mehr", plan[:even_more_description]
    end

    test "blank region -> leeres Ergebnis (defensiv)" do
      result = DisciplineQuery.call(region: nil)
      assert_equal [], result.disciplines
      assert_equal({}, result.tournament_plans)
    end
  end
end
