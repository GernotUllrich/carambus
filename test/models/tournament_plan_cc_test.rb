# frozen_string_literal: true

require "test_helper"

# Phase 21-03 T2: Modell-Tests für TournamentPlanCc.
#
# Deckt: Validierung, find-or-initialize-Pattern (T3-Syncer-Use-Case), Assoziation zu
# TournamentCc, LocalProtector-Integration (global record).
class TournamentPlanCcTest < ActiveSupport::TestCase
  # ------------------------------------------------------------------------
  # Validations
  # ------------------------------------------------------------------------
  test "valid with name + context (cc_id optional)" do
    plan = TournamentPlanCc.new(name: "Test-Plan", context: "nbv")
    assert plan.valid?, "Expected valid: #{plan.errors.full_messages.inspect}"
  end

  test "valid with cc_id + name + context" do
    plan = TournamentPlanCc.new(cc_id: 999, name: "Test-Plan-with-cc", context: "nbv")
    assert plan.valid?
  end

  test "invalid without name" do
    plan = TournamentPlanCc.new(cc_id: 999, context: "nbv")
    assert_not plan.valid?
    assert_includes plan.errors.full_messages.join, "Name"
  end

  # ------------------------------------------------------------------------
  # Syncer-Use-Case: find_or_initialize_by (T3-Pattern)
  # ------------------------------------------------------------------------
  test "find_or_initialize_by(cc_id:, context:) — existing record (idempotency)" do
    existing = tournament_plan_ccs(:nbv_einzel_einfach)
    found = TournamentPlanCc.find_or_initialize_by(cc_id: existing.cc_id, context: existing.context)
    assert found.persisted?
    assert_equal existing.id, found.id
  end

  test "find_or_initialize_by(cc_id:, context:) — new record" do
    fresh = TournamentPlanCc.find_or_initialize_by(cc_id: 999_888, context: "nbv")
    assert_not fresh.persisted?
    fresh.name = "Fresh Plan"
    assert fresh.save
    assert TournamentPlanCc.exists?(cc_id: 999_888, context: "nbv")
  end

  test "find_or_initialize_by(name:, context:) — name-only lookup for cc_id-less records" do
    name_only = tournament_plan_ccs(:nbv_name_only_sample)
    found = TournamentPlanCc.find_or_initialize_by(name: name_only.name, context: name_only.context)
    assert found.persisted?
    assert_nil found.cc_id
  end

  # ------------------------------------------------------------------------
  # Context-Scope (Region-Isolation)
  # ------------------------------------------------------------------------
  test "same name across contexts coexist (NBV + BBBV)" do
    nbv = tournament_plan_ccs(:nbv_einzel_einfach)        # name "Einzel-K.o.", context "nbv"
    bbbv = tournament_plan_ccs(:bbbv_other_region)        # name "Einzel-K.o.", context "bbbv"
    assert_equal nbv.name, bbbv.name
    assert_not_equal nbv.context, bbbv.context
    nbv_only = TournamentPlanCc.where(name: "Einzel-K.o.", context: "nbv")
    assert_equal 1, nbv_only.count
    assert_equal nbv.id, nbv_only.first.id
  end

  # ------------------------------------------------------------------------
  # Assoziation: TournamentCc.tournament_plan_cc
  # ------------------------------------------------------------------------
  test "TournamentCc#tournament_plan_cc lädt zugewiesenen Plan" do
    plan = tournament_plan_ccs(:nbv_einzel_einfach)
    tc = TournamentCc.new(cc_id: 12_345, context: "nbv", tournament_plan_cc: plan)
    assert_equal plan, tc.tournament_plan_cc
    assert_equal plan.id, tc.tournament_plan_cc_id
  end

  test "TournamentCc#tournament_plan_cc ist optional (= nil ohne Wert)" do
    tc = TournamentCc.new(cc_id: 12_346, context: "nbv")
    assert_nil tc.tournament_plan_cc
    # optional: true → kein presence-Validierungsfehler darauf
    tc.valid?
    assert_nil tc.errors[:tournament_plan_cc].presence
  end
end
