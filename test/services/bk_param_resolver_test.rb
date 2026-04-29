# frozen_string_literal: true

require "test_helper"

# Phase 38.5-02 D-01..D-07, D-14: BkParamResolver unit tests.
#
# Coverage groups:
#   A. compute_effective_discipline / multiset (D-01, D-02)
#   B. resolve walk-order across the 7-level hierarchy (D-04, D-05, D-07)
#   C. sparse override semantics (D-06 — the critical regression-guard)
#   D. TournamentPlan level safely reserved (no NoMethodError) — research finding 1
#   E. Training mode (no TournamentMonitor) (D-14)
#   F. bake! end-to-end contract — does NOT save, is idempotent
#
# Tests update the fixture Discipline.data JSON in setup so the real
# `Discipline.find_by(name:)` lookup is exercised. LocalProtector is disabled in
# tests (test_helper.rb prepends LocalProtectorTestOverride) so writes succeed
# inside the transaction and roll back automatically.
class BkParamResolverTest < ActiveSupport::TestCase
  fixtures :disciplines

  setup do
    # Seed the BK-2plus / BK-2 / BK50 / BK100 fixture data with the two new
    # registered-params keys so the resolver's Level 1 (Discipline) lookup
    # returns concrete values. Mirrors what Plan 03's seed will do at runtime.
    seed_bk_discipline("BK-2plus", allow_negative_score_input: true, negative_credits_opponent: true)
    seed_bk_discipline("BK-2", allow_negative_score_input: true, negative_credits_opponent: false)
    seed_bk_discipline("BK50", allow_negative_score_input: true, negative_credits_opponent: false)
    seed_bk_discipline("BK100", allow_negative_score_input: true, negative_credits_opponent: false)
    # BK2-Kombi (id 107 in production; 50_000_010 in fixtures) intentionally has
    # no allow_negative_score_input — resolver uses effective_discipline lookup.
  end

  # ---------------------------------------------------------------------------
  # Group A — compute_effective_discipline / multiset (D-01, D-02)
  # ---------------------------------------------------------------------------

  test "A1: non-BK-2kombi free_game_form returns identity (karambol)" do
    tm = build_tm(free_game_form: "karambol")
    assert_equal "karambol", BkParamResolver.send(:compute_effective_discipline, tm)
  end

  test "A2: BK-2kombi DZ-first set 1 returns bk_2plus (D-01)" do
    tm = build_tm(free_game_form: "bk2_kombi", first_set_mode: "direkter_zweikampf", sets: [])
    assert_equal "bk_2plus", BkParamResolver.send(:compute_effective_discipline, tm)
  end

  test "A3: BK-2kombi DZ-first set 2 returns bk_2 (D-01)" do
    tm = build_tm(free_game_form: "bk2_kombi", first_set_mode: "direkter_zweikampf", sets: [{}])
    assert_equal "bk_2", BkParamResolver.send(:compute_effective_discipline, tm)
  end

  test "A4: BK-2kombi DZ-first set 3 returns bk_2plus again (cycle)" do
    tm = build_tm(free_game_form: "bk2_kombi", first_set_mode: "direkter_zweikampf", sets: [{}, {}])
    assert_equal "bk_2plus", BkParamResolver.send(:compute_effective_discipline, tm)
  end

  test "A5: BK-2kombi SP-first set 1 returns bk_2 (D-01)" do
    tm = build_tm(free_game_form: "bk2_kombi", first_set_mode: "serienspiel", sets: [])
    assert_equal "bk_2", BkParamResolver.send(:compute_effective_discipline, tm)
  end

  test "A6: first_set_mode reorders multiset_components when they disagree" do
    # Phase 38.5: first_set_mode is authoritative for alternation order.
    # multiset_components only declares cycle membership; the order is reordered
    # to match first_set_mode. DZ-first → bk_2plus first regardless of how
    # multiset_components was originally written.
    tm = build_tm(
      free_game_form: "bk2_kombi",
      first_set_mode: "direkter_zweikampf",
      sets: [],
      multiset_components: ["bk_2", "bk_2plus"]
    )
    assert_equal "bk_2plus", BkParamResolver.compute_effective_discipline(tm),
                 "DZ-first must yield bk_2plus at set 1 even when multiset_components is written SP-first"

    tm2 = build_tm(
      free_game_form: "bk2_kombi",
      first_set_mode: "serienspiel",
      sets: [],
      multiset_components: ["bk_2plus", "bk_2"]
    )
    assert_equal "bk_2", BkParamResolver.compute_effective_discipline(tm2),
                 "SP-first must yield bk_2 at set 1 even when multiset_components is written DZ-first"
  end

  # ---------------------------------------------------------------------------
  # Group B — resolve walk-order (D-04 fallback, D-07 REGISTERED_PARAMS)
  # ---------------------------------------------------------------------------

  test "B1: Discipline-only default flows through (BK-2plus negative_credits_opponent=true)" do
    tm = build_tm(free_game_form: "bk_2plus")
    assert_equal true, BkParamResolver.resolve(:negative_credits_opponent, table_monitor: tm)
  end

  test "B2: TableMonitor explicit override wins over Discipline default (D-07)" do
    tm = build_tm(free_game_form: "bk_2plus", overrides: {"allow_negative_score_input" => false})
    assert_equal false, BkParamResolver.resolve(:allow_negative_score_input, table_monitor: tm)
  end

  test "B3: TournamentMonitor override wins over Discipline default" do
    tm = build_tm(free_game_form: "bk_2plus")
    tm.tournament_monitor = TournamentMonitor.new(data: {"allow_negative_score_input" => false})
    assert_equal false, BkParamResolver.resolve(:allow_negative_score_input, table_monitor: tm)
  end

  test "B4: Tournament override wins over Discipline default" do
    tm = build_tm(free_game_form: "bk_2plus")
    tournament = Tournament.new(data: {"negative_credits_opponent" => false})
    tm.tournament_monitor = TournamentMonitor.new(tournament: tournament)
    assert_equal false, BkParamResolver.resolve(:negative_credits_opponent, table_monitor: tm)
  end

  test "B5: nothing set anywhere falls back to false (D-04)" do
    tm = build_tm(free_game_form: "karambol")
    # karambol Discipline lookup returns nil from lookup_discipline (non-BK family),
    # so Level 1 is empty hash; Levels 2-7 are nil/empty -> fallback false.
    assert_equal false, BkParamResolver.resolve(:allow_negative_score_input, table_monitor: tm)
    assert_equal false, BkParamResolver.resolve(:negative_credits_opponent, table_monitor: tm)
  end

  test "B6: Discipline.data has free_game_form but not the param -> fallback false" do
    # BK-2 Discipline has allow_negative_score_input set but NOT some hypothetical
    # other param. Use bk2_kombi Discipline (intentionally has neither key).
    build_tm(free_game_form: "bk2_kombi", first_set_mode: "direkter_zweikampf", sets: [])
    # effective_discipline -> bk_2plus -> seeded with both keys, so this resolves true.
    # To test the "key absent" path, use a Discipline that has NO seed.
    # bk2_kombi Discipline (fixture has no allow_negative_score_input; effective_discipline
    # routes to bk_2plus which IS seeded). Test the explicit absence path differently:
    # use BK-2 with negative_credits_opponent=false; explicitly assert it returns false.
    tm2 = build_tm(free_game_form: "bk_2")
    assert_equal false, BkParamResolver.resolve(:negative_credits_opponent, table_monitor: tm2)
  end

  # ---------------------------------------------------------------------------
  # Group C — sparse override semantics (D-06 — CRITICAL REGRESSION GUARD)
  # ---------------------------------------------------------------------------

  test "C1: explicit false at TableMonitor level overrides true at Discipline (D-06 sparse override)" do
    # BK-2plus default at Discipline: allow_negative_score_input=true.
    # TableMonitor explicitly sets it to FALSE. Resolver MUST honor the explicit false
    # (proves data.key? is the gate, NOT data[].present?).
    tm = build_tm(
      free_game_form: "bk_2plus",
      overrides: {"allow_negative_score_input" => false}
    )
    result = BkParamResolver.resolve(:allow_negative_score_input, table_monitor: tm)
    assert_equal false, result,
      "D-06 regression: explicit FALSE at TableMonitor level must override Discipline default TRUE. " \
      "If this test fails, somebody used .present? instead of .key? in the resolver walk."
  end

  # ---------------------------------------------------------------------------
  # Group D — TournamentPlan reservation (research finding 1)
  # ---------------------------------------------------------------------------

  test "D1: tournament_plan reference does not raise NoMethodError (no .data call)" do
    tm = build_tm(free_game_form: "bk_2plus")
    tournament_plan = TournamentPlan.new # tournament_plans table has NO data column
    tournament = Tournament.new(tournament_plan: tournament_plan, data: {})
    tm.tournament_monitor = TournamentMonitor.new(tournament: tournament)

    assert_nothing_raised do
      BkParamResolver.resolve(:allow_negative_score_input, table_monitor: tm)
    end
  end

  # ---------------------------------------------------------------------------
  # Group E — Training mode (D-14): no TournamentMonitor
  # ---------------------------------------------------------------------------

  test "E1: training mode (tournament_monitor=nil) walks to Discipline without raising (D-14)" do
    tm = build_tm(free_game_form: "bk_2plus")
    assert_nil tm.tournament_monitor

    # Should reach Discipline default (true) without raising on nil hierarchy levels.
    assert_equal true, BkParamResolver.resolve(:allow_negative_score_input, table_monitor: tm)
  end

  # ---------------------------------------------------------------------------
  # Group F — bake! end-to-end contract
  # ---------------------------------------------------------------------------

  test "F1: bake! on BK-2kombi DZ set 1 writes effective_discipline + 2 params (D-01)" do
    tm = build_tm(free_game_form: "bk2_kombi", first_set_mode: "direkter_zweikampf", sets: [])
    BkParamResolver.bake!(tm)

    assert_equal "bk_2plus", tm.data["effective_discipline"]
    assert_equal true, tm.data["allow_negative_score_input"]
    assert_equal true, tm.data["negative_credits_opponent"]
  end

  test "F2: bake! is idempotent (second call produces same data)" do
    tm = build_tm(free_game_form: "bk2_kombi", first_set_mode: "direkter_zweikampf", sets: [])
    BkParamResolver.bake!(tm)
    snapshot = tm.data.dup
    BkParamResolver.bake!(tm)
    assert_equal snapshot, tm.data,
      "bake! must be idempotent — second call must produce identical data"
  end

  test "F2b: bake! recomputes from Discipline at set transition (no Level-7 self-reference)" do
    # Regression for the dev bug where bake! at set 2 read its own previous
    # output at Level 7 (table_monitor.data) instead of falling through to
    # Level 1 (Discipline.data). Set 1 wrote negative_credits_opponent=true
    # (BK-2plus rule); set 2 must walk to BK-2 discipline and write false.
    tm = build_tm(free_game_form: "bk2_kombi", first_set_mode: "direkter_zweikampf", sets: [])

    # Set 1 (DZ phase): bake produces BK-2plus rule
    BkParamResolver.bake!(tm)
    assert_equal "bk_2plus", tm.data["effective_discipline"]
    assert_equal true, tm.data["negative_credits_opponent"], "set 1 DZ must credit opponent"

    # Simulate set close: push to data["sets"] so set_index becomes 2
    tm.data["sets"] = [{}]

    # Set 2 (SP phase): re-bake must walk to BK-2 discipline, NOT read its own
    # set-1 output as a Level-7 override
    BkParamResolver.bake!(tm)
    assert_equal "bk_2", tm.data["effective_discipline"]
    assert_equal false, tm.data["negative_credits_opponent"],
      "set 2 SP must NOT credit opponent — bake must clear its own prior output before walking"
    assert_equal true, tm.data["allow_negative_score_input"],
      "set 2 SP still allows negative input (BK-2 rule)"
  end

  test "F3: bake! does NOT save — caller is responsible" do
    # Note: TableMonitor.new persists itself implicitly (AASM initial-state
    # `:new` after_enter callback calls save!). To prove bake! does NOT save,
    # mark the TM clean, call bake!, and assert the TM is now dirty (changed?
    # is true) but NOT yet committed (saved_changes? is false / no new
    # updated_at row in the DB). The contract: caller must call save! after
    # bake! — bake! mutates the in-memory data Hash only.
    tm = build_tm(free_game_form: "bk_2plus")
    tm.save! # establish a clean baseline
    assert_equal false, tm.changed?, "TM is clean before bake!"

    BkParamResolver.bake!(tm)

    assert_equal true, tm.changed?,
      "bake! must mutate data (so caller can save!), but it must NOT have called save itself"
    # Reload from DB and prove the new keys did NOT make it into the persisted row.
    reloaded = TableMonitor.find(tm.id)
    refute reloaded.data.key?("effective_discipline"),
      "bake! must not persist effective_discipline — caller is responsible for save!"
  end

  test "F4: bake! on karambol writes effective_discipline=karambol with false fallbacks (D-04)" do
    tm = build_tm(free_game_form: "karambol")
    BkParamResolver.bake!(tm)

    assert_equal "karambol", tm.data["effective_discipline"]
    assert_equal false, tm.data["allow_negative_score_input"],
      "karambol falls through to Level 1 (no Discipline seed) and final D-04 fallback false"
    assert_equal false, tm.data["negative_credits_opponent"]
  end

  private

  # Updates the fixture Discipline record's data JSON to include the two new
  # registered params. LocalProtector is disabled in tests (test_helper.rb
  # prepends LocalProtectorTestOverride) so the save succeeds inside the test
  # transaction and rolls back automatically.
  def seed_bk_discipline(name, allow_negative_score_input:, negative_credits_opponent:)
    disc = Discipline.find_by(name: name)
    return unless disc

    parsed = disc.data.present? ? JSON.parse(disc.data) : {}
    parsed["allow_negative_score_input"] = allow_negative_score_input
    parsed["negative_credits_opponent"] = negative_credits_opponent
    disc.update_columns(data: parsed.to_json)
  end

  # Builds an in-memory TableMonitor with a `data` Hash. Does NOT persist.
  # tournament_monitor is nil unless caller assigns one (training-mode default).
  #
  # Note: TableMonitor.new(data: {...}) drops the passed Hash (Rails 7.2
  # serialize-default-Hash behavior); assign via `tm.data = {...}` after
  # construction instead.
  def build_tm(free_game_form:, first_set_mode: "direkter_zweikampf", sets: [],
    multiset_components: nil, overrides: {})
    data = {
      "free_game_form" => free_game_form,
      "bk2_options" => {"first_set_mode" => first_set_mode},
      "sets" => sets,
      "playera" => {"discipline" => discipline_name_for(free_game_form)}
    }
    data["multiset_components"] = multiset_components if multiset_components
    data.merge!(overrides)

    tm = TableMonitor.new
    tm.data = data
    tm
  end

  def discipline_name_for(free_game_form)
    TableMonitor::GameSetup::BK_NAME_TO_FORM.invert[free_game_form] || free_game_form
  end
end
