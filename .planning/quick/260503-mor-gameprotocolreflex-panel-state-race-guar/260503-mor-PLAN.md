---
phase: quick-260503-mor
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - app/reflexes/game_protocol_reflex.rb
  - test/reflexes/game_protocol_reflex_test.rb
autonomous: true
requirements:
  - QUICK-260503-MOR-01
must_haves:
  truths:
    - "Once panel_state == 'protocol_final', GameProtocolReflex#open_protocol does NOT downgrade it to 'protocol'."
    - "Once panel_state == 'protocol_final', GameProtocolReflex#switch_to_edit_mode does NOT downgrade it to 'protocol_edit'."
    - "Once panel_state == 'protocol_final', GameProtocolReflex#switch_to_view_mode does NOT downgrade it to 'protocol'."
    - "current_element ('confirm_result' or 'tiebreak_winner_choice') is preserved when any of these reflexes fire on a protocol_final TableMonitor."
    - "Stale-DOM clicks on the Spielprotokoll-Button after AASM has advanced to set_over render the existing protocol_final modal instead of regressing state."
  artifacts:
    - path: "app/reflexes/game_protocol_reflex.rb"
      provides: "Three guarded reflex entry points (open_protocol, switch_to_edit_mode, switch_to_view_mode) that bail out early when panel_state == 'protocol_final'."
      contains: 'panel_state == "protocol_final"'
    - path: "test/reflexes/game_protocol_reflex_test.rb"
      provides: "Three regression tests (R1-R3) locking the no-downgrade invariant for each affected reflex method."
      contains: "protocol_final"
  key_links:
    - from: "app/reflexes/game_protocol_reflex.rb"
      to: "TableMonitor#panel_state"
      via: "early-return guard at the top of three reflex methods"
      pattern: 'panel_state == "protocol_final"'
    - from: "test/reflexes/game_protocol_reflex_test.rb"
      to: "GameProtocolReflex"
      via: ".allocate + define_singleton_method dispatch (matches existing T1-T5 pattern)"
      pattern: "GameProtocolReflex.allocate"
---

<objective>
Close a long-standing intermittent race condition: when a set ends in a draw, the AASM after-callback in `TableMonitor#set_game_over` (table_monitor.rb:543-548) sets `panel_state = "protocol_final"` and `current_element = "confirm_result"` (later "tiebreak_winner_choice" once the ResultRecorder detects a pending tiebreak), but the CableReady push to the scoreboard can arrive late. While the operator still sees the stale DOM with the visible Spielprotokoll-Button, a click fires `GameProtocolReflex#open_protocol` (or `switch_to_edit_mode` / `switch_to_view_mode`), and those reflexes unconditionally overwrite `panel_state` — downgrading `protocol_final` → `protocol` (or `protocol_edit`), losing the tiebreak fieldset and the "Ergebnis bestätigen" wiring. The user reproduced this at the BCW Grand Prix on 2026-05-02.

**Fix:** small early-return guard at the top of each of the three vulnerable reflex methods, in the spirit of the project's `extend-before-build` SKILL — no new helper, no refactor. When `panel_state == "protocol_final"`, the reflex re-renders the modal in its current state (so the operator's click is not silently discarded) and returns. The `morph :nothing` first line is preserved.

Purpose: protect the `protocol_final` invariant during the brief window between `set_game_over` and the CableReady DOM update so the operator can always reach the tiebreak choice even on a stale click.

Output:
- `app/reflexes/game_protocol_reflex.rb` — three 4-line guards added (one per affected method).
- `test/reflexes/game_protocol_reflex_test.rb` — three new regression tests (R1, R2, R3) appended to the existing T1-T5 suite, locking the no-downgrade contract.
</objective>

<execution_context>
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/workflows/execute-plan.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.agents/skills/extend-before-build/SKILL.md
@app/reflexes/game_protocol_reflex.rb
@app/models/table_monitor.rb
@app/views/table_monitors/_game_protocol_modal.html.erb
@app/views/table_monitors/_scoreboard.html.erb
@test/reflexes/game_protocol_reflex_test.rb
@test/integration/tiebreak_modal_form_wiring_test.rb

<interfaces>
<!-- Key contracts the executor must respect. Extracted directly from the codebase so no exploration is required. -->

From app/reflexes/game_protocol_reflex.rb (current state, BEFORE the fix):

```ruby
class GameProtocolReflex < ApplicationReflex
  before_reflex :load_table_monitor   # sets @table_monitor

  def open_protocol
    morph :nothing
    Rails.logger.debug { "🎯 GameProtocolReflex#open_protocol" }
    @table_monitor.suppress_broadcast = true
    @table_monitor.panel_state = "protocol"          # ← VULNERABLE: overwrites protocol_final
    @table_monitor.save!
    @table_monitor.suppress_broadcast = false
    send_modal_update(render_protocol_modal)
  end

  def switch_to_edit_mode
    morph :nothing
    @table_monitor.suppress_broadcast = true
    @table_monitor.panel_state = "protocol_edit"     # ← VULNERABLE
    @table_monitor.save!
    @table_monitor.suppress_broadcast = false
    send_modal_update(render_protocol_modal)
  end

  def switch_to_view_mode
    morph :nothing
    @table_monitor.suppress_broadcast = true
    @table_monitor.panel_state = "protocol"          # ← VULNERABLE
    @table_monitor.save!
    @table_monitor.suppress_broadcast = false
    send_modal_update(render_protocol_modal)
  end
end
```

From app/models/table_monitor.rb:

```ruby
def set_game_over
  # AASM after-callback when state transitions into set_over
  if state == "set_over"
    assign_attributes(panel_state: "protocol_final", current_element: "confirm_result")
    data_will_change!
    save
  end
end

def protocol_modal_should_be_open?
  %w[protocol protocol_edit protocol_final].include?(panel_state)
end

def final_protocol_modal_should_be_open?
  panel_state == "protocol_final"
end
```

From the existing test suite (test/reflexes/game_protocol_reflex_test.rb), the established
dispatch pattern for reflex unit tests is:

```ruby
@reflex = GameProtocolReflex.allocate
@reflex.instance_variable_set(:@table_monitor, @tm)
@reflex.define_singleton_method(:send_modal_update) { |_html| nil }
@reflex.define_singleton_method(:morph) { |_target| nil }
@reflex.define_singleton_method(:render_protocol_modal) { "<div>modal</div>" }
```

The setup also uses `@tm.update_columns(panel_state: "protocol_final", current_element: "tiebreak_winner_choice")` — exactly the state we need to reproduce the race.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1 (RED): Add 3 regression tests for the no-downgrade invariant</name>
  <files>test/reflexes/game_protocol_reflex_test.rb</files>
  <behavior>
    Append three new test methods at the end of the existing `GameProtocolReflexTest` class, after T5. Each test seeds the TableMonitor in `panel_state == "protocol_final"` (the existing setup already does this) and asserts the no-downgrade invariant for one of the three vulnerable reflex methods.

    - R1 (open_protocol): with current_element="tiebreak_winner_choice", call `@reflex.open_protocol`. Reload `@tm`. Assert `panel_state == "protocol_final"` AND `current_element == "tiebreak_winner_choice"`.
    - R2 (switch_to_edit_mode): same setup. Call `@reflex.switch_to_edit_mode`. Reload. Assert both fields unchanged (still "protocol_final" / "tiebreak_winner_choice").
    - R3 (switch_to_view_mode): use `current_element = "confirm_result"` (the other valid protocol_final marker per `set_game_over`). Call `@reflex.switch_to_view_mode`. Reload. Assert `panel_state == "protocol_final"` AND `current_element == "confirm_result"`.

    For R3, switch the marker via `@tm.update_columns(current_element: "confirm_result")` then `@tm.reload` BEFORE invoking the reflex (mirrors T5's pattern at line 109).

    No params stub is needed for these reflexes (none of open_protocol / switch_to_edit_mode / switch_to_view_mode read `params`). The `send_modal_update` / `morph` / `render_protocol_modal` stubs from the existing setup block are sufficient — but each test should ALSO assert that `send_modal_update` is invoked (so the operator's click is not silently dropped). Use a small counter or `define_singleton_method` override:

    ```ruby
    modal_update_calls = 0
    @reflex.define_singleton_method(:send_modal_update) { |_html| modal_update_calls += 1 }
    @reflex.open_protocol
    assert_equal 1, modal_update_calls, "open_protocol on protocol_final must re-render the modal"
    ```

    Tests R1, R2, R3 MUST FAIL on the unmodified reflex (RED) — the current implementation overwrites panel_state → "protocol" (or "protocol_edit"), so the assertion `panel_state == "protocol_final"` will fail with diff Expected "protocol_final" / Actual "protocol".

    Comment block above the three new tests explains the race condition (cite the user report from 2026-05-02 BCW Grand Prix and the `extend-before-build` SKILL guard pattern). Keep the comment concise — 6-10 lines, mirror the in-line documentation style used by R1-T5 in this file.
  </behavior>
  <action>
    1. Open `test/reflexes/game_protocol_reflex_test.rb`.
    2. After T5 (last test, ends approx line 121), insert a comment block describing the regression suite (Phase quick-260503-mor — panel_state race guard).
    3. Append three new test methods R1, R2, R3 as described in `<behavior>` above. They reuse the existing `setup` block (which already seeds `panel_state: "protocol_final"`, `current_element: "tiebreak_winner_choice"`).
    4. R3 must reset `current_element` to `"confirm_result"` to cover the second valid marker.
    5. Each test must assert (a) panel_state stays "protocol_final" after the reflex fires AND (b) current_element is unchanged AND (c) `send_modal_update` was invoked exactly once (the operator's click must not be silently discarded — they must see the modal again).
    6. Run only the new tests to confirm they FAIL (RED): `bin/rails test test/reflexes/game_protocol_reflex_test.rb`. Expected: 3 failures (R1, R2, R3) with messages indicating panel_state regressed to "protocol" / "protocol_edit". The 5 existing tests (T1-T5) must continue to pass — do not edit them.
    7. Commit RED: conventional message `test(quick-260503-mor): add 3 RED regression tests for protocol_final no-downgrade guard`.
  </action>
  <verify>
    <automated>bin/rails test test/reflexes/game_protocol_reflex_test.rb 2>&amp;1 | tail -25</automated>
  </verify>
  <done>
    - File `test/reflexes/game_protocol_reflex_test.rb` has 3 NEW tests (R1, R2, R3) appended after T5.
    - Running the file yields exactly 3 FAILURES (one per new test) and 5 PASSES (T1-T5).
    - Each failure message names panel_state regression ("protocol_final" expected, "protocol" or "protocol_edit" actual).
    - RED commit landed with message `test(quick-260503-mor): ...`.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2 (GREEN): Add early-return guard to the 3 vulnerable reflex methods</name>
  <files>app/reflexes/game_protocol_reflex.rb</files>
  <behavior>
    Apply the SKILL `extend-before-build` pattern: add a small guard at the top of each of the three affected reflex methods. NO new helper, NO refactor. The guard re-renders the existing protocol_final modal so the operator's click is not silently discarded, then returns.

    Insert AFTER `morph :nothing` and `Rails.logger.debug` (so logs still capture the invocation), BEFORE the `suppress_broadcast` / `panel_state =` / `save!` block:

    ```ruby
    if @table_monitor.panel_state == "protocol_final"
      send_modal_update(render_protocol_modal)
      return
    end
    ```

    Apply this guard to:
    1. `open_protocol` (line 11-19)
    2. `switch_to_edit_mode` (line 33-42)
    3. `switch_to_view_mode` (line 44-53)

    DO NOT add the guard to `close_protocol` (line 21-31) — closing the modal from `protocol_final` is legitimate operator intent (e.g. pressing Esc / clicking-away after a tiebreak choice has been recorded). The race condition only affects open / switch reflexes, never close.

    A short inline comment above each guard documents the race (`# Race-guard: stale-DOM click after set_game_over set protocol_final — re-render, do not downgrade`). Keep the wording identical across all three so a future grep finds them in one shot.

    The three RED tests from Task 1 must turn GREEN. The existing T1-T5 must remain GREEN. No edits to `close_protocol` or any other method. No edits to view partials. No edits to `TableMonitor`.
  </behavior>
  <action>
    1. Open `app/reflexes/game_protocol_reflex.rb`.
    2. In `open_protocol`, AFTER the `Rails.logger.debug` call and BEFORE `@table_monitor.suppress_broadcast = true`, insert:
       ```ruby
       # Race-guard: stale-DOM click after set_game_over set protocol_final — re-render, do not downgrade
       if @table_monitor.panel_state == "protocol_final"
         send_modal_update(render_protocol_modal)
         return
       end
       ```
    3. Repeat verbatim in `switch_to_edit_mode`.
    4. Repeat verbatim in `switch_to_view_mode`.
    5. DO NOT touch `close_protocol`, `confirm_result`, or any other method.
    6. Run the regression suite: `bin/rails test test/reflexes/game_protocol_reflex_test.rb`. Expected: 8 PASSES, 0 FAILURES. R1, R2, R3 turn GREEN. T1-T5 stay GREEN.
    7. Run the integration suite that exercises the wider modal contract to confirm no regression: `bin/rails test test/integration/tiebreak_modal_form_wiring_test.rb`. Expected: 4 PASSES (G1-G4 unchanged).
    8. Spot-check the broader reflex / scoreboard suites are not regressed:
       `bin/rails test test/reflexes/ test/system/tiebreak_test.rb 2>&1 | tail -20` (allowing pre-existing skips/failures from STATE.md to remain — bk2_scoreboard_test.rb is known to have 19 pre-existing failures unrelated to this fix).
    9. Commit GREEN: conventional message `fix(quick-260503-mor): guard protocol_final from downgrade in GameProtocolReflex open/switch reflexes`.
  </action>
  <verify>
    <automated>bin/rails test test/reflexes/game_protocol_reflex_test.rb test/integration/tiebreak_modal_form_wiring_test.rb 2>&amp;1 | tail -15</automated>
  </verify>
  <done>
    - `app/reflexes/game_protocol_reflex.rb` has 3 identical 4-line guards (one per affected method) AFTER `Rails.logger.debug` and BEFORE `suppress_broadcast = true`.
    - `close_protocol` is UNCHANGED.
    - `bin/rails test test/reflexes/game_protocol_reflex_test.rb` reports 8 runs, 0 failures, 0 errors.
    - `bin/rails test test/integration/tiebreak_modal_form_wiring_test.rb` reports 4 runs, 0 failures, 0 errors.
    - GREEN commit landed with message `fix(quick-260503-mor): ...`.
  </done>
</task>

</tasks>

<verification>
After both tasks:

1. Targeted regression: `bin/rails test test/reflexes/game_protocol_reflex_test.rb test/integration/tiebreak_modal_form_wiring_test.rb` — all green (8 + 4 = 12 runs, 0 failures, 0 errors).
2. `git log --oneline -3` shows the RED then GREEN commits for `quick-260503-mor`.
3. `grep -c 'panel_state == "protocol_final"' app/reflexes/game_protocol_reflex.rb` returns `3` — one guard per affected method.
4. `grep -c 'def close_protocol' app/reflexes/game_protocol_reflex.rb` returns `1` and `close_protocol` body is byte-identical to the pre-fix version (no guard there).
5. Manual reasoning on the bug report flow:
   - Operator clicks Spielprotokoll on stale DOM after `set_game_over` → `open_protocol` reflex fires.
   - Guard hits, modal re-renders in `protocol_final` state with the tiebreak fieldset visible (per `_game_protocol_modal.html.erb` line 5: `is_final_mode = panel_state == "protocol_final"`).
   - Operator can now enter the tiebreak winner — bug closed.
</verification>

<success_criteria>
- [ ] Both commits land on master with `(quick-260503-mor)` prefix.
- [ ] 3 RED tests added, then turned GREEN by the guard — RED→GREEN sequence visible in git log.
- [ ] `panel_state == "protocol_final"` is preserved across stale clicks on `open_protocol`, `switch_to_edit_mode`, `switch_to_view_mode`.
- [ ] `current_element` is preserved (both "confirm_result" and "tiebreak_winner_choice" markers).
- [ ] `close_protocol` is UNTOUCHED — operator can still close from protocol_final.
- [ ] No view partial edits, no `TableMonitor` edits — pure reflex-layer fix.
- [ ] SKILL `extend-before-build` honored: 3 small guards, no new helper, no refactor.
- [ ] All four `tiebreak_modal_form_wiring_test.rb` integration tests still pass.
- [ ] User-perspective truth: stale-DOM click on Spielprotokoll-Button after a draw set-end re-renders the protocol_final modal with the tiebreak choice fieldset, instead of downgrading to view-mode without tiebreak input.
</success_criteria>

<output>
After completion, create `.planning/quick/260503-mor-gameprotocolreflex-panel-state-race-guar/260503-mor-SUMMARY.md` documenting:
- The race condition (cite user report 2026-05-02 BCW Grand Prix and the 7-step root-cause sequence from the bug context).
- The 3-guard fix (cite SKILL extend-before-build).
- Why `close_protocol` was NOT guarded.
- RED→GREEN test counts (3 new R-tests, 5 existing T-tests, 4 G-tests in tiebreak_modal_form_wiring all GREEN at end).
- Lock-in: future regressions will fail R1/R2/R3 immediately.
</output>
