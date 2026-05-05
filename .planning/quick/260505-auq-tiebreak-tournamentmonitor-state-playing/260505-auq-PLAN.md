---
phase: 260505-auq
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - app/models/table_monitor.rb
  - test/models/table_monitor_test.rb
  - test/services/table_monitor/result_recorder_test.rb
autonomous: true
requirements:
  - QUICK-260505-auq-01
must_haves:
  truths:
    - "When the active TournamentMonitor#state is 'playing_finals' (i.e. playing_finals?), tiebreak_pending_block? returns true on tied scores even if game.data['tiebreak_required'] was never baked."
    - "When the active TournamentMonitor is in playing_finals?, ResultRecorder#tiebreak_pick_pending? returns true on tied scores at goal regardless of executor_params, modal switches to tiebreak_winner_choice, and the AASM :acknowledge_result event is blocked."
    - "Override does NOT fire when tournament_monitor is blank (training mode), nor when tournament_monitor.is_a?(PartyMonitor) (league flow), nor when state is anything other than playing_finals."
    - "Pre-existing predicates (Plan 38.7 D-04 4-level resolver, Plan 11 BK-2kombi auto-detect, Plan 38.7-09..13 executor_params paths) are preserved verbatim — the override is a single new clause prepended to the existing read sites."
    - "Plan 38.7 D-04 sparse-override semantics are NOT violated — explicit `false` at any executor_params level still wins over the playing_finals? override is NOT what we want; the user's directive is explicit: playing_finals? => ALWAYS tiebreak_on_draw, regardless of executor_params. The override therefore takes precedence over executor_params."
    - "test/concerns/local_protector_test.rb still passes (no MIN_ID protector regression)."
  artifacts:
    - path: "app/models/table_monitor.rb"
      provides: "playing_finals_force_tiebreak_required! private helper + first-line call from tiebreak_pending_block?"
      contains: "playing_finals_force_tiebreak_required!"
    - path: "test/models/table_monitor_test.rb"
      provides: "Regression tests for playing_finals? override on tiebreak_pending_block?"
      contains: "playing_finals"
    - path: "test/services/table_monitor/result_recorder_test.rb"
      provides: "Regression test for playing_finals? override propagating to tiebreak_pick_pending?"
      contains: "playing_finals"
  key_links:
    - from: "app/models/table_monitor.rb#tiebreak_pending_block? (line 1716)"
      to: "playing_finals_force_tiebreak_required! (new)"
      via: "first line of method body, before the existing tiebreak_required gate"
      pattern: "playing_finals_force_tiebreak_required!"
    - from: "app/services/table_monitor/result_recorder.rb#tiebreak_pick_pending? (line 348)"
      to: "@tm.tiebreak_pending_block? (existing) / NO change"
      via: "tiebreak_pick_pending? does NOT call tiebreak_pending_block?, it duplicates the gate. The override must be applied at game.data layer (via the new TableMonitor helper that mutates game.data) so BOTH read sites observe true after the helper runs."
      pattern: "playing_finals_force_tiebreak_required!"
    - from: "app/services/table_monitor/result_recorder.rb#tiebreak_pick_pending? (line 349)"
      to: "@tm.playing_finals_force_tiebreak_required! (NEW call, sibling to bk2_kombi_tiebreak_auto_detect!)"
      via: "second line, after bk2_kombi_tiebreak_auto_detect!, before the tiebreak_required==true gate"
      pattern: "playing_finals_force_tiebreak_required!"
    - from: "app/models/table_monitor.rb#tiebreak_pending_block? (line 1717)"
      to: "playing_finals_force_tiebreak_required! (new) — SAME helper called as first line"
      via: "Both read sites bake game.data['tiebreak_required']=true via the helper before reading the gate"
      pattern: "playing_finals_force_tiebreak_required!"
    - from: "app/models/table_monitor.rb#playing_finals_force_tiebreak_required! (new)"
      to: "tournament_monitor.is_a?(TournamentMonitor) && tournament_monitor.playing_finals?"
      via: "Uses existing polymorphic association + AASM-generated predicate; AASM-state predicate name confirmed at app/models/tournament_monitor.rb:70 (state :playing_finals)"
      pattern: "playing_finals?"
---

<objective>
Fix the missing-tiebreak-in-Finale bug from the 5. Grand Prix Einband screenshot
(Finale Kl. Tisch 1, Runde 4, both players 10:10 → "Endergebnis erfasst" /
"Nächstes Spiel" instead of tiebreak modal).

Per user's literal directive:

> Anstatt in den executor_params überall "tiebreak_on_draw":true einzutragen, wäre
> es viel einfacher den TournamentMonitor#state abzufragen. playing_finals? =>
> immer tiebreak_on_draw

Add ONE small guard at the existing tiebreak read sites: if the active
TournamentMonitor is in AASM state `playing_finals` (predicate
`playing_finals?`), force `tiebreak_required=true` on the in-flight game's data
regardless of any executor_params / Tournament.data / TournamentPlan
configuration. This makes the Finale-tiebreak rule a state-driven invariant of
the TournamentMonitor lifecycle, not a configuration knob to be set on every
plan.

Purpose: Stop hunting executor_params plumbing (Plans 38.7-09..13). The hard
rule is "tied in finals → tiebreak"; encode it where it belongs — at decision
time against the live AASM state.

Output: A single private helper on TableMonitor + 2 call sites + a regression
suite that pins the override behavior.
</objective>

<execution_context>
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/workflows/execute-plan.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@./CLAUDE.md
@.agents/skills/scenario-management/SKILL.md
@.agents/skills/extend-before-build/SKILL.md
@app/models/table_monitor.rb
@app/models/tournament_monitor.rb
@app/models/game.rb
@app/services/table_monitor/result_recorder.rb
@test/models/table_monitor_test.rb
@test/services/table_monitor/result_recorder_test.rb

<interfaces>
<!-- Investigation findings — exact file:line anchors for the executor. No -->
<!-- codebase exploration needed. -->

# 1. AASM state confirmed (app/models/tournament_monitor.rb:66-88)

```ruby
aasm column: "state" do
  state :new_tournament_monitor, initial: true, after_enter: [:do_reset_tournament_monitor]
  state :playing_groups, before_enter: :debug_log
  state :playing_finals, before_enter: :debug_log     # <- target predicate: playing_finals?
  state :tournament_finished
  state :party_result_reporting_mode
  state :closed
  ...
  event :start_playing_finals do
    transitions from: %i[new_tournament_monitor playing_groups playing_finals], to: :playing_finals
  end
  ...
end
```

AASM auto-generates `playing_finals?` predicate. NO custom predicate needed.

# 2. Polymorphic association (app/models/table_monitor.rb:53)

```ruby
belongs_to :tournament_monitor, polymorphic: true, optional: true
```

The polymorphic target may be `TournamentMonitor` OR `PartyMonitor`. Existing
code at table_monitor.rb:1763 already establishes the type-check pattern:

```ruby
return unless tournament_monitor.is_a?(TournamentMonitor)
```

PartyMonitor (league flow) MUST be skipped — it has its own playing_finals
semantics if any. Training mode (tournament_monitor blank) MUST also be skipped.

# 3. Decision-time read sites (the gate)

## Site A — TableMonitor#tiebreak_pending_block? (app/models/table_monitor.rb:1716)

```ruby
def tiebreak_pending_block?
  return false unless game&.data&.[]("tiebreak_required") == true
  return false if game.data["tiebreak_winner"].present?

  a = data&.dig("playera", "result").to_i
  b = data&.dig("playerb", "result").to_i
  if simple_set_game? && data["sets"].present?
    last_set = Array(data["sets"]).last
    a = last_set["Ergebnis1"].to_i
    b = last_set["Ergebnis2"].to_i
  end
  a == b
end
```

Used by AASM guard `tiebreak_not_pending?` on `:acknowledge_result` event
(table_monitor.rb:392). If this returns false on Finale + 10:10 (because
tiebreak_required was never baked), AASM allows acknowledge → state advances to
final_set_score → match closes → "Endergebnis erfasst" appears.

## Site B — ResultRecorder#tiebreak_pick_pending? (app/services/table_monitor/result_recorder.rb:348)

```ruby
def tiebreak_pick_pending?
  bk2_kombi_tiebreak_auto_detect!     # <- existing precedent: pre-mutation helper

  return false unless @tm.game&.data&.[]("tiebreak_required") == true
  return false if @tm.game.data["tiebreak_winner"].present?
  ...
end
```

Used in `perform_evaluate_result` at lines 451 and 468 to switch
`@tm.current_element` to "tiebreak_winner_choice" (modal target) when a
tiebreak pick is pending. If this returns false, the modal goes to
"confirm_result" and the operator confirms the result without ever seeing the
tiebreak picker.

# 4. Existing precedent — extend-before-build pattern in action

`ResultRecorder#bk2_kombi_tiebreak_auto_detect!` (result_recorder.rb:379-405) is
a pre-mutation helper called as the first line of `tiebreak_pick_pending?`. It
mutates `@tm.game.data['tiebreak_required'] = true` via
`@tm.game.deep_merge_data!` + `@tm.game.save!` BEFORE the gate check, so the
gate observes true on the same call.

The new helper follows this pattern verbatim — different trigger condition,
identical mechanism, identical persistence path.

# 5. Game#deep_merge_data! contract (app/models/game.rb:267)

```ruby
def deep_merge_data!(hash)
  h = data.dup
  h.deep_merge!(hash)
  return unless h != data
  data_will_change!
  self.data = JSON.parse(h.to_json)
  # save!  <- caller owns persistence
end
```

Caller MUST call `save!` afterward. Idempotent: returns early if no change. No
schema modification.

# 6. MIN_ID / LocalProtector consideration

Game `include LocalProtector` (game.rb:23). Tournament games on local servers
have id >= MIN_ID (50_000_000) per CLAUDE.md, so save! is allowed. The existing
`bk2_kombi_tiebreak_auto_detect!` calls `@tm.game.save!` on local-server games
in production today — same write path, same protection rules. No new exposure.

# 7. Test infrastructure

- `test/services/table_monitor/result_recorder_test.rb` — has Game + GP + TM
  fixture in setup (lines 28-102); tests use `recorder.send(:tiebreak_pick_pending?)`
  pattern (line 570).
- `test/models/table_monitor_test.rb` — has @tm fixture; tests use
  `update_columns(state: "set_over")` to bypass AASM (line 434).
- For the override tests we need to construct a `TournamentMonitor` with state
  "playing_finals" and associate it via the polymorphic belongs_to. Pattern:
  `tm.update!(tournament_monitor: tour_monitor)` after creating the TM with
  `state: "playing_finals"` via `update_columns` (AASM bypass — same trick used
  for set_over).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RED — write 5 regression tests pinning the playing_finals? override contract</name>
  <files>
    test/models/table_monitor_test.rb,
    test/services/table_monitor/result_recorder_test.rb
  </files>
  <behavior>
    All tests use the existing `@tm` / `@game` fixtures + a freshly created
    Tournament + TournamentMonitor row whose `state` is set via
    `update_columns(state: "playing_finals")` (AASM bypass — established
    pattern at table_monitor_test.rb:434, result_recorder_test.rb:434).

    Test M1 (in test/models/table_monitor_test.rb, append after the existing
    "T9 supplemental" block ~line 487):
    "playing_finals? override forces tiebreak_pending_block? true on tied scores even when tiebreak_required key is absent"
    - Setup: `@tm` data: free_game_form="karambol", playera/playerb each
      result=10, balls_goal=40, innings=30, allow_follow_up=false, innings_goal=30.
    - Game: data={} (NO tiebreak_required key).
    - Tournament + TournamentMonitor created; `tour_monitor.update_columns(state: "playing_finals")`.
    - `@tm.update!(tournament_monitor: tour_monitor); @tm.update_columns(game_id: game.id, state: "set_over"); @tm.reload`.
    - Assert: `@tm.tiebreak_pending_block?` == true (override fired).
    - Assert: `game.reload; game.data["tiebreak_required"]` == true (helper persisted).
    - Assert: `@tm.may_acknowledge_result?` == false (AASM gate honors override).

    Test M2:
    "playing_finals? override is a NO-OP when tournament_monitor is blank (training mode)"
    - Same data fixture as M1, but `@tm.tournament_monitor = nil`.
    - Game: data={} (NO tiebreak_required key).
    - Assert: `@tm.tiebreak_pending_block?` == false (no override, tied
      scores alone don't force tiebreak).
    - Assert: `game.reload; game.data["tiebreak_required"]` is NOT true
      (helper did not write).

    Test M3:
    "playing_finals? override is a NO-OP when tournament_monitor is in playing_groups state (group phase)"
    - Same as M1 but `tour_monitor.update_columns(state: "playing_groups")`.
    - Assert: `@tm.tiebreak_pending_block?` == false.
    - Assert: `game.reload; game.data["tiebreak_required"]` is NOT true.

    Test M4 (defense):
    "playing_finals? override is a NO-OP when tournament_monitor.is_a?(PartyMonitor) (league flow)"
    - Build a PartyMonitor (any state); `@tm.update!(tournament_monitor: party_monitor)`.
    - Assert: `@tm.tiebreak_pending_block?` == false.
    - Assert: `game.reload; game.data["tiebreak_required"]` is NOT true.
    - This proves the type-guard `tournament_monitor.is_a?(TournamentMonitor)`
      keeps the league-match flow untouched.

    Test R1 (in test/services/table_monitor/result_recorder_test.rb, append
    after the Gap-03 G3 block ~line 618):
    "playing_finals? override propagates through tiebreak_pick_pending? — Finale 10:10 forces modal to tiebreak_winner_choice"
    - Same fixture data as M1, applied via `@tm.deep_merge_data!(...)` /
      `@tm.save!` and `@game.update!(data: {})`.
    - Tournament + TournamentMonitor `state: "playing_finals"` via update_columns.
    - `@tm.update!(tournament_monitor: tour_monitor)`.
    - `recorder = TableMonitor::ResultRecorder.new(table_monitor: @tm)`
    - `result = recorder.send(:tiebreak_pick_pending?)`
    - Assert: `result` == true.
    - Assert: `@game.reload; @game.data["tiebreak_required"]` == true.

    Run all tests — all 5 MUST fail RED (override does not yet exist).

    NB: The Tournament fixture should reuse a minimal in-memory record:
    `tournament = Tournament.create!(title: "Quick260505 Finale", ...)` with
    just enough fields to satisfy `belongs_to :tournament` on
    TournamentMonitor. Match the minimal-create pattern from existing fixtures
    if any; otherwise inspect existing tests in
    `test/models/tournament_monitor_test.rb` for the canonical create.
  </behavior>
  <action>
    Append all 5 tests to the two files. DO NOT modify production code in this
    task. Run:
    ```
    bin/rails test test/models/table_monitor_test.rb -n /playing_finals/
    bin/rails test test/services/table_monitor/result_recorder_test.rb -n /playing_finals/
    ```
    Verify all 5 tests fail RED. Commit with conventional message
    `test(quick-260505-auq): RED regression tests for TournamentMonitor#playing_finals? tiebreak override`.

    If the Tournament factory shape is unfamiliar, peek at
    `test/models/tournament_monitor_test.rb` or
    `test/services/tournament_monitor/result_processor_test.rb` for canonical
    create patterns; do NOT introduce new test fixtures or factories. Use bare
    `Tournament.create!` / `TournamentMonitor.create!` with minimal fields and
    `update_columns(state: ...)` for AASM bypass.
  </action>
  <verify>
    <automated>bin/rails test test/models/table_monitor_test.rb test/services/table_monitor/result_recorder_test.rb 2>&amp;1 | tail -20</automated>
  </verify>
  <done>5 new tests added, all failing RED with descriptive failure messages, committed.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: GREEN — add playing_finals_force_tiebreak_required! helper + 2 call sites</name>
  <files>
    app/models/table_monitor.rb,
    app/services/table_monitor/result_recorder.rb
  </files>
  <behavior>
    All 5 RED tests from Task 1 turn GREEN.
    All existing tests in test/models/table_monitor_test.rb,
    test/services/table_monitor/result_recorder_test.rb,
    test/system/tiebreak_test.rb,
    test/integration/tiebreak_modal_form_wiring_test.rb,
    test/concerns/local_protector_test.rb
    remain GREEN.
    Phase 38.7 D-04 4-level resolver, Phase 38.7-11 BK-2kombi auto-detect, and
    Phase 38.7-09..13 executor_params paths are preserved verbatim (no edits to
    Game.derive_tiebreak_required, no edits to bk2_kombi_tiebreak_auto_detect!,
    no edits to GameSetup tiebreak baking).
  </behavior>
  <action>
    ## Edit 1 — app/models/table_monitor.rb

    Add a new private helper between the existing `tiebreak_pending_block?`
    (line 1716-1728) and `admin_ack_result` (line 1730). Place it AFTER
    `tiebreak_pending_block?` so it's adjacent to its only-in-this-file caller.

    ```ruby
    # Quick-260505-auq — TournamentMonitor#playing_finals? tiebreak override.
    #
    # Per user directive (2026-05-05): "playing_finals? => immer tiebreak_on_draw".
    # When the active TournamentMonitor is in AASM state :playing_finals, force
    # game.data['tiebreak_required'] = true regardless of executor_params /
    # Tournament.data / TournamentPlan / Discipline / GameSetup baking. This is
    # a hard rule of the tournament lifecycle, NOT a configurable knob.
    #
    # Skips when:
    #   - tournament_monitor is blank (training mode)
    #   - tournament_monitor.is_a?(PartyMonitor) (league flow — its own
    #     semantics; type-guard mirrors existing pattern at
    #     advance_tournament_round_if_present, table_monitor.rb:1763)
    #   - tournament_monitor.state != "playing_finals"
    #
    # Idempotent: returns early if game.data['tiebreak_required'] already true.
    # Pattern mirrors ResultRecorder#bk2_kombi_tiebreak_auto_detect!
    # (app/services/table_monitor/result_recorder.rb:379) — pre-mutation helper
    # called as first line of the gate predicate, so the gate observes true on
    # the same call.
    #
    # Persistence: Game#deep_merge_data! does NOT save (per its contract); we
    # call save! explicitly. LocalProtector compatible — tournament games on
    # local servers have id >= MIN_ID (50_000_000), and the existing
    # bk2_kombi_tiebreak_auto_detect! follows the same write pattern in
    # production today.
    def playing_finals_force_tiebreak_required!
      return unless game.present?
      return if game.data&.[]("tiebreak_required") == true # idempotent
      return unless tournament_monitor.present?
      return unless tournament_monitor.is_a?(TournamentMonitor)
      return unless tournament_monitor.playing_finals?

      Rails.logger.info "[TableMonitor##{id}] playing_finals? override: forcing " \
        "tiebreak_required=true on game=#{game.id} (TournamentMonitor=#{tournament_monitor.id})"
      game.deep_merge_data!("tiebreak_required" => true)
      game.save!
    end
    ```

    Then prepend the call to `tiebreak_pending_block?` (line 1716). Replace:

    ```ruby
    def tiebreak_pending_block?
      return false unless game&.data&.[]("tiebreak_required") == true
    ```

    with:

    ```ruby
    def tiebreak_pending_block?
      playing_finals_force_tiebreak_required!

      return false unless game&.data&.[]("tiebreak_required") == true
    ```

    The new helper is private (sits in the existing `private` section that
    starts higher up — verify by `grep -n "^  private" app/models/table_monitor.rb`
    that the insertion point is in scope; if not, place it under an explicit
    `private` directive or use `private :playing_finals_force_tiebreak_required!`).

    ## Edit 2 — app/services/table_monitor/result_recorder.rb

    Modify `tiebreak_pick_pending?` (line 348). Replace:

    ```ruby
    def tiebreak_pick_pending?
      bk2_kombi_tiebreak_auto_detect!

      return false unless @tm.game&.data&.[]("tiebreak_required") == true
    ```

    with:

    ```ruby
    def tiebreak_pick_pending?
      bk2_kombi_tiebreak_auto_detect!
      @tm.send(:playing_finals_force_tiebreak_required!)

      return false unless @tm.game&.data&.[]("tiebreak_required") == true
    ```

    Use `@tm.send(:playing_finals_force_tiebreak_required!)` to bypass the
    private visibility (the helper is private on TableMonitor; `send` is the
    established cross-class private-invocation pattern in this codebase — see
    e.g. `recorder.send(:tiebreak_pick_pending?)` in tests).

    Document the new line with a one-line comment:

    ```ruby
    # Quick-260505-auq: parallel pre-mutation — TournamentMonitor#playing_finals?
    # forces tiebreak_required=true regardless of any executor_params plumbing.
    @tm.send(:playing_finals_force_tiebreak_required!)
    ```

    ## Verification

    Run:
    ```
    bin/rails test test/models/table_monitor_test.rb test/services/table_monitor/result_recorder_test.rb
    bin/rails test test/system/tiebreak_test.rb
    bin/rails test test/integration/tiebreak_modal_form_wiring_test.rb
    bin/rails test test/concerns/local_protector_test.rb
    ```

    All 5 RED tests must turn GREEN. All pre-existing tests must remain GREEN
    (no regressions in the Phase 38.7 + 38.8 suites). Standardrb must pass on
    the 2 modified files.

    Commit with conventional message
    `fix(quick-260505-auq): TournamentMonitor#playing_finals? forces tiebreak_required=true at decision time`.
  </action>
  <verify>
    <automated>bundle exec standardrb app/models/table_monitor.rb app/services/table_monitor/result_recorder.rb &amp;&amp; bin/rails test test/models/table_monitor_test.rb test/services/table_monitor/result_recorder_test.rb test/system/tiebreak_test.rb test/integration/tiebreak_modal_form_wiring_test.rb test/concerns/local_protector_test.rb 2>&amp;1 | tail -30</automated>
  </verify>
  <done>
    Helper added, both call sites prepended, all 5 new tests GREEN, all 4
    existing tiebreak/protector test files remain GREEN, standardrb clean,
    committed.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>
    A single ~12-line private helper on TableMonitor + two call-site additions
    (one line each) that make `tiebreak_required=true` whenever the active
    TournamentMonitor is in AASM state `playing_finals`. Replaces the failed
    Phase 38.7-09..13 strategy of seeding `executor_params` with
    `tiebreak_on_draw: true` everywhere.

    Bug fixed: 5. Grand Prix Einband Finale 10:10 → tiebreak modal appears
    instead of "Endergebnis erfasst" / "Nächstes Spiel".
  </what-built>
  <how-to-verify>
    1. Verify the test suites pass:
       ```
       cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
       bin/rails test test/models/table_monitor_test.rb \
         test/services/table_monitor/result_recorder_test.rb \
         test/system/tiebreak_test.rb \
         test/integration/tiebreak_modal_form_wiring_test.rb \
         test/concerns/local_protector_test.rb
       ```
       Expect: 0 failures, 0 errors. New tests count = +5.

    2. Manual reproduction (optional, only if convenient — the regression
       suite is the primary verification):
       - Start a Finale phase tournament (TournamentMonitor in
         `playing_finals` state) on local dev.
       - Bring a karambol/Einband match to GD=0 (e.g. 10:10 with
         balls_goal=40 — note the bug screenshot was at goal=40 but the
         override fires at any tied result, not only at goal).
       - Click Endergebnis-erfassen / acknowledge → expect tiebreak modal
         (`tiebreak_winner_choice`), NOT "Endergebnis erfasst" /
         "Nächstes Spiel".

    3. Cross-scenario portability check (no commit/deploy yet):
       - Helper is in app/models/table_monitor.rb — ships via the same git
         pull path as every other change.
       - No new dependencies, no migration, no schema changes, no
         carambus.yml additions.
       - Per scenario-management SKILL: this run is in carambus_bcw
         (debugging-mode-style edit). After human verify, the user will
         decide whether to mirror to carambus_master and push, OR commit
         from carambus_bcw and pull-back to master per the SKILL's
         debugging-mode workflow (lines 113-131).

    4. Skim the diff one more time:
       ```
       git diff app/models/table_monitor.rb app/services/table_monitor/result_recorder.rb
       ```
       Expect: ~25-30 lines added (helper + 2 one-line call additions),
       0 lines deleted.
  </how-to-verify>
  <resume-signal>
    Type "approved" to mark the quick task complete (final-commit + STATE.md
    update), or describe any regressions / surprise diffs you spotted.
  </resume-signal>
</task>

</tasks>

<verification>
- All 5 new tests GREEN (3 in table_monitor_test.rb, 2 in result_recorder_test.rb — Task 1 lists 4 + 1; verify final count matches plan).
- All pre-existing tests in:
  - test/models/table_monitor_test.rb (Phase 38.7 D-08 AASM guard tests)
  - test/services/table_monitor/result_recorder_test.rb (Phase 38.7-11 Gap-03 auto-detect tests + Phase 38.8 final_match_score tests)
  - test/system/tiebreak_test.rb (Phase 38.7-08 system tests)
  - test/integration/tiebreak_modal_form_wiring_test.rb (Phase 38.7-13 Gap-05 wiring)
  - test/concerns/local_protector_test.rb (MIN_ID protection — must NOT regress)
  remain GREEN.
- standardrb clean on the 2 modified production files.
- No edits to:
  - app/models/game.rb (Game.derive_tiebreak_required preserved)
  - app/services/table_monitor/game_setup.rb (Plan 09 + Plan 04 baking preserved)
  - app/services/table_monitor/result_recorder.rb#bk2_kombi_tiebreak_auto_detect! (Plan 11 preserved)
  - any view, controller, reflex (Plan 12 + Plan 13 wiring preserved)
- No new dependencies, migrations, or schema changes.
- Per CLAUDE.md: frozen_string_literal preserved, German business comments preserved.
- Per scenario-management SKILL: this run targets carambus_bcw (debugging-mode-style). Decision to mirror to master or pull-back deferred to human-verify checkpoint.
- Per extend-before-build SKILL: ONE new private helper (~12 LOC) + 2 one-line call additions; NO new state machine, NO new column, NO parallel control flow. Helper is structurally a sibling of bk2_kombi_tiebreak_auto_detect! — same pattern, different trigger.
</verification>

<success_criteria>
- The plan's must_haves.truths all hold against running tests.
- The 5. Grand Prix Einband Finale 10:10 bug no longer reproduces in the test
  fixture (Test R1 in result_recorder_test.rb).
- Phase 38.7 D-04 sparse-override semantics intact for non-finals games (Tests
  M2, M3, M4 prove the override is scoped).
- The patch is portable across all 4 scenarios (carambus_master,
  carambus_bcw, carambus_phat, carambus_api) — touches only Ruby model + Ruby
  service, both ship via standard git pull.
</success_criteria>

<output>
After completion, create
`.planning/quick/260505-auq-tiebreak-tournamentmonitor-state-playing/260505-auq-SUMMARY.md`
documenting:
- Final test counts (added / passing / regressions).
- The exact code added (helper + 2 one-line call additions).
- Why this approach replaces the executor_params plumbing strategy of Phase
  38.7-09..13 (extend-before-build at the actual decision site).
- Any surprises during RED→GREEN (Tournament fixture shape, AASM bypass
  patterns, etc.).
- Note on scenario-management workflow used (debugging-mode-style edit in
  carambus_bcw vs. canonical edit in carambus_master) and post-commit sync
  decision.
</output>
