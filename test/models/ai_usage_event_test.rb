# frozen_string_literal: true

require "test_helper"

# Phase 49-01: AiUsageEvent berechnet est_cost_eur aus Token-Spalten + Modell-Raten.
class AiUsageEventTest < ActiveSupport::TestCase
  test "est_cost_eur aus Haiku-Raten beim Speichern (input + output)" do
    e = AiUsageEvent.create!(scenario_context: "nbv", user_id: 1, persona: "sportwart",
      model: "claude-haiku-4-5-20251001", input_tokens: 1_000_000, output_tokens: 1_000_000)
    r = AiUsageEvent::MODEL_RATES_EUR_PER_MTOK["claude-haiku-4-5-20251001"]
    assert_in_delta r[:input] + r[:output], e.est_cost_eur.to_f, 0.0001
  end

  test "est_cost_eur aus Sonnet-Raten inkl. Cache-Tokens" do
    e = AiUsageEvent.create!(scenario_context: "nbv", model: "claude-sonnet-4-6",
      input_tokens: 1_000_000, output_tokens: 0,
      cache_creation_tokens: 1_000_000, cache_read_tokens: 1_000_000)
    r = AiUsageEvent::MODEL_RATES_EUR_PER_MTOK["claude-sonnet-4-6"]
    assert_in_delta r[:input] + r[:cache_write] + r[:cache_read], e.est_cost_eur.to_f, 0.0001
  end

  test "unbekanntes Modell → est_cost_eur 0,0 ohne Crash" do
    e = AiUsageEvent.create!(scenario_context: "nbv", model: "fremd-modell-x", input_tokens: 999)
    assert_equal 0.0, e.est_cost_eur.to_f
  end

  # 49-01: record_turn schreibt je Modell EINEN Event (Haiku→Sonnet-Hybrid = 2 Zeilen/Turn).
  test "record_turn schreibt je Modell einen Event mit Attribution" do
    u = users(:one)
    ubm = {
      "claude-haiku-4-5-20251001" => {input: 100, output: 20, cache_creation: 0, cache_read: 0},
      "claude-sonnet-4-6" => {input: 200, output: 50, cache_creation: 10, cache_read: 5}
    }
    assert_difference("AiUsageEvent.count", 2) do
      AiUsageEvent.record_turn(usage_by_model: ubm, user: u, scenario: "nbv")
    end
    haiku = AiUsageEvent.find_by(model: "claude-haiku-4-5-20251001")
    assert_equal "nbv", haiku.scenario_context
    assert_equal u.id, haiku.user_id
    assert_equal 100, haiku.input_tokens
    assert_operator haiku.est_cost_eur.to_f, :>, 0
    sonnet = AiUsageEvent.find_by(model: "claude-sonnet-4-6")
    assert_equal 10, sonnet.cache_creation_tokens
    assert_equal 5, sonnet.cache_read_tokens
  end

  test "record_turn mit leerem usage_by_model schreibt nichts" do
    assert_no_difference("AiUsageEvent.count") do
      AiUsageEvent.record_turn(usage_by_model: {}, user: users(:one), scenario: "nbv")
    end
  end

  # 49-02: cost_report aggregiert pro Scenario + MODELL + Zeit-Bucket — Haiku/Sonnet getrennt.
  test "cost_report splittet pro Scenario, Modell und Tag" do
    t1 = Time.zone.local(2026, 6, 28, 10)
    t2 = Time.zone.local(2026, 6, 29, 10)
    AiUsageEvent.create!(scenario_context: "nbv", model: "claude-haiku-4-5-20251001", input_tokens: 1_000_000, created_at: t1)
    AiUsageEvent.create!(scenario_context: "nbv", model: "claude-haiku-4-5-20251001", input_tokens: 1_000_000, created_at: t1)
    AiUsageEvent.create!(scenario_context: "nbv", model: "claude-sonnet-4-6", input_tokens: 1_000_000, created_at: t1)
    AiUsageEvent.create!(scenario_context: "bcw", model: "claude-sonnet-4-6", input_tokens: 1_000_000, created_at: t2)

    rep = AiUsageEvent.cost_report(bucket: :day)
    # nbv am selben Tag in zwei getrennte Modell-Zeilen aufgesplittet
    nbv_haiku = rep.find { |r| r[:scenario] == "nbv" && r[:model] == "claude-haiku-4-5-20251001" }
    nbv_sonnet = rep.find { |r| r[:scenario] == "nbv" && r[:model] == "claude-sonnet-4-6" }
    assert_equal 2, nbv_haiku[:events]
    assert_equal 2_000_000, nbv_haiku[:input]
    assert_equal 1, nbv_sonnet[:events]
    assert_operator nbv_haiku[:cost_eur], :>, 0
    # Sonnet (1M In) ist teurer als ein einzelner Haiku-Turn (1M In) → Split macht's sichtbar
    assert_operator nbv_sonnet[:cost_eur], :>, nbv_haiku[:cost_eur] / 2
    assert(rep.any? { |r| r[:scenario] == "bcw" }, "bcw-Scenario getrennt aggregiert")
  end
end
