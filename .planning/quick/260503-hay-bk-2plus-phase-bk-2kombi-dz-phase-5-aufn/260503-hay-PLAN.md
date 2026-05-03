---
phase: quick-260503-hay
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - test/models/table_monitor_test.rb
  - app/models/table_monitor.rb
autonomous: true
requirements:
  - QUICK-260503-HAY-01
must_haves:
  truths:
    - "BK-2plus standalone game does NOT close when both players reach 5 innings without reaching balls_goal (no Aufnahmenbegrenzung)"
    - "BK-2kombi DZ-Phase does NOT close when both players reach 5 innings without reaching balls_goal (DZ uses shot-limit per turn, not inning-limit per set)"
    - "Pure karambol still closes via the legacy innings_goal branch when innings_goal is positive (regression guard)"
    - "BK-2 (always SP-like) and BK-2kombi SP-Phase remain governed by their existing branches — quick-260501-uxo SP-inning-limit close still fires"
  artifacts:
    - path: "test/models/table_monitor_test.rb"
      provides: "Regression tests for legacy innings_goal-close branch — 4 new tests covering BK-2plus, BK-2kombi DZ, karambol baseline, and a parity guard"
      contains: "260503-hay"
    - path: "app/models/table_monitor.rb"
      provides: "Phase-aware guard on legacy innings_goal-close branch (~lines 1583-1587) — exclude BK-2plus and BK-2kombi DZ-Phase"
      contains: "260503-hay"
  key_links:
    - from: "app/models/table_monitor.rb (legacy innings_goal branch ~line 1583)"
      to: "TableMonitor#bk2_kombi_current_phase (line 1165)"
      via: "guard expression — `data['free_game_form']` whitelist + bk2_kombi_current_phase check"
      pattern: "bk_2plus.*bk2_kombi.*direkter_zweikampf"
    - from: "test/models/table_monitor_test.rb"
      to: "TableMonitor#end_of_set?"
      via: "build_bk_data helper + assert/refute @tm.end_of_set?"
      pattern: "build_bk_data.*free_game_form.*bk_2plus|bk2_kombi"
---

<objective>
Fix BCW Grand Prix regression: BK-2plus standalone games and BK-2kombi DZ-Phase
abort after 5 innings even though no Aufnahmenbegrenzung exists for those modes.
The legacy karambol `innings_goal`-close branch in `TableMonitor#end_of_set?`
(table_monitor.rb:1583-1587) is phase-blind. After commit 1491385f set
`innings_goal = 5` for the entire BK-* family as an SP-phase safety net, the
value flows through that legacy branch and closes DZ-phase / BK-2plus sets
prematurely.

Purpose: Restore correct behavior for BK-2plus standalone (no inning limit at
all) and BK-2kombi DZ-Phase (shot-limit per turn, NOT inning-limit per set)
while preserving the SP-phase safety net for BK-2 and BK-2kombi SP-Phase.

Output:
- 4 new RED-then-GREEN tests in `test/models/table_monitor_test.rb`
- Small phase-aware guard added to the legacy `innings_goal` branch in
  `TableMonitor#end_of_set?` (NO new predicate, NO refactor — SKILL
  extend-before-build).
</objective>

<execution_context>
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/workflows/execute-plan.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.planning/STATE.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/CLAUDE.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.agents/skills/extend-before-build/SKILL.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/app/models/table_monitor.rb
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/app/controllers/table_monitors_controller.rb
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/test/models/table_monitor_test.rb

<interfaces>
<!-- Key contracts the executor needs. Extracted from codebase. -->

From app/models/table_monitor.rb (line 1165 — bk2_kombi_current_phase):
```ruby
# Returns "direkter_zweikampf" or "serienspiel" for BK-2kombi games,
# nil for non-BK-2kombi.
def bk2_kombi_current_phase
  return nil unless data.is_a?(Hash) && data["free_game_form"] == "bk2_kombi"
  first_mode = data.dig("bk2_options", "first_set_mode").presence || "direkter_zweikampf"
  set_number = Array(data["sets"]).length + 1
  set_number.odd? ? first_mode : (first_mode == "direkter_zweikampf" ? "serienspiel" : "direkter_zweikampf")
end
```

From app/models/table_monitor.rb (lines 1583-1587 — legacy innings_goal branch to GUARD):
```ruby
elsif data["innings_goal"].to_i.positive? && data["playera"]["innings"].to_i >= data["innings_goal"].to_i &&
      (data["playera"]["innings"] == data["playerb"]["innings"] || !data["allow_follow_up"])
  Rails.logger.info "[TableMonitor#end_of_set?] Game[#{game_id}] on TM[#{id}] ended: innings_goal reached ..."
  return true
end
```

From app/controllers/table_monitors_controller.rb (lines 301-307 — innings_goal source):
```ruby
p[:innings_goal] = case p[:discipline_a]
                   when "BK50", "BK100"
                     1
                   else
                     (p[:innings_choice].presence || p[:innings_2_choice].presence || 5).to_i
                   end
```

From app/controllers/table_monitors_controller.rb (lines 326-331 — allow_follow_up source):
```ruby
case p[:free_game_form]
when "bk_2", "bk2_kombi"
  p[:allow_follow_up] = true
when "bk_2plus", "bk50", "bk100"
  p[:allow_follow_up] = false
end
```

From test/models/table_monitor_test.rb (lines 107-119 — build_bk_data test helper, REUSE):
```ruby
def build_bk_data(free_game_form:, balls_goal:, playera_result:, playera_innings:,
                  playerb_result:, playerb_innings:, allow_follow_up: true,
                  bk2_options: nil)
  d = {
    "free_game_form" => free_game_form,
    "allow_follow_up" => allow_follow_up,
    "playera" => {"result" => playera_result, "innings" => playera_innings, "balls_goal" => balls_goal},
    "playerb" => {"result" => playerb_result, "innings" => playerb_innings, "balls_goal" => balls_goal},
    "current_inning" => {"active_player" => "playerb", "balls" => 0}
  }
  d["bk2_options"] = bk2_options if bk2_options
  d
end
```

Pre-existing branches in `end_of_set?` (DO NOT MODIFY):
- Lines 1486-1491: BK-immediate-close (no_followup_phase + balls_goal reached)
- Lines 1508-1576: bk_with_nachstoss block (Plan 38.7-02 D-02 + Phase 38.9 + Quick-260501-uxo)
- Lines 1578-1582: balls_goal close branch
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RED — add 4 regression tests for legacy innings_goal branch (BK-2plus + BK-2kombi DZ exclusion)</name>
  <files>test/models/table_monitor_test.rb</files>
  <behavior>
    Append a new section after the existing 260501-uxo block (after line ~318)
    titled `Quick-260503-hay — BK-2plus / BK-2kombi DZ-Phase MUST NOT close on innings_goal=5`.

    All four tests reuse the existing `build_bk_data` helper (line 107).

    - **Test 1 (RED today, GREEN after Task 2):**
      `end_of_set? does NOT close BK-2plus standalone when both reach 5 innings without balls_goal (260503-hay)`
      - free_game_form: "bk_2plus", balls_goal: 50, both at result=30 / innings=5
      - allow_follow_up: false (matches controller line 329)
      - data["innings_goal"] = 5 (matches controller line 305 fallback)
      - refute @tm.end_of_set?, "BK-2plus has NO Aufnahmenbegrenzung — set must stay open"
      - **Today fails** because legacy branch fires when `!allow_follow_up` AND playera.innings >= innings_goal.

    - **Test 2 (RED today, GREEN after Task 2):**
      `end_of_set? does NOT close BK-2kombi DZ-Phase when both reach 5 innings without balls_goal (260503-hay)`
      - free_game_form: "bk2_kombi", balls_goal: 70, both at result=40 / innings=5
      - allow_follow_up: true (matches controller line 327)
      - data["innings_goal"] = 5
      - bk2_options: {"first_set_mode" => "direkter_zweikampf", "serienspiel_max_innings_per_set" => 5}
      - data["sets"] left empty → set #1 → DZ-Phase
      - assert_equal "direkter_zweikampf", @tm.bk2_kombi_current_phase, "Sanity"
      - refute @tm.end_of_set?, "DZ-Phase has shot-limit per turn, NOT inning-limit per set"
      - **Today fails** because legacy branch fires on `playera.innings == playerb.innings` AND `playera.innings >= innings_goal`.

    - **Test 3 (regression guard — must remain GREEN before AND after Task 2):**
      `end_of_set? STILL closes karambol when innings_goal reached at equal innings (legacy branch regression guard, 260503-hay)`
      - free_game_form: "karambol", balls_goal: 0 → use 250 instead so the helper passes a positive integer; we'll set the result to 0 so balls_goal branch never fires (`data['playera']['result'].to_i >= data['playera']['balls_goal'].to_i` is false because 0 < 250)
      - Actually simpler: set balls_goal: 250, both at result=200 / innings=30
      - allow_follow_up: true
      - data["innings_goal"] = 30
      - assert @tm.end_of_set?, "karambol legacy branch must keep firing — guard scopes to BK-* only"

    - **Test 4 (regression guard — already GREEN, locks BK-2 SP path):**
      `end_of_set? STILL closes BK-2kombi SP-Phase via the existing 260501-uxo SP-inning-limit branch (260503-hay sanity)`
      - free_game_form: "bk2_kombi", balls_goal: 70, both result=50 / innings=5
      - bk2_options: {"first_set_mode" => "direkter_zweikampf", "serienspiel_max_innings_per_set" => 5}
      - data["sets"] = one entry → set #2 → SP-Phase (mirror existing test on line 252-266)
      - assert_equal "serienspiel", @tm.bk2_kombi_current_phase
      - assert @tm.end_of_set?, "260501-uxo SP-Phase inning-limit branch fires before legacy branch"

    Tests use the existing `build_bk_data` helper. Each test sets
    `@tm.data` directly (not `update!`) — same pattern as lines 254-258, 269-273.
    Then assigns `@tm.data["innings_goal"] = 5` (or 30 for karambol) and
    optionally `@tm.data["sets"] = [...]` for the BK-2kombi SP fixture.
  </behavior>
  <action>
    1. Open `test/models/table_monitor_test.rb`.

    2. After the existing 260501-uxo block (which ends at line 318), insert a
       new comment header section:

       ```ruby
       # ---------------------------------------------------------------------------
       # Quick-260503-hay — BK-2plus / BK-2kombi DZ-Phase MUST NOT close on
       # innings_goal=5 (legacy karambol close branch is phase-blind).
       #
       # Background: commit 1491385f (2026-04-26) set innings_goal=5 for the
       # entire BK-* family as an SP-phase safety net. The legacy karambol close
       # branch at table_monitor.rb:1583-1587 has no phase awareness — it fires
       # whenever both players reach innings_goal (allow_follow_up=true) or any
       # one player does (allow_follow_up=false). For BK-2plus (no Nachstoss, no
       # inning limit) and BK-2kombi DZ-Phase (shot-limit per turn, not inning
       # limit per set) this is wrong — those phases must keep playing until
       # balls_goal is reached.
       #
       # SKILL extend-before-build: regression tests for a one-line guard added
       # to the existing legacy branch. NO new predicate, NO refactor.
       # ---------------------------------------------------------------------------
       ```

    3. Add 4 tests as specified in the `<behavior>` block. Use `build_bk_data`
       helper. Set `@tm.data["innings_goal"]` after `build_bk_data` returns.
       For Test 4 mirror the SP-Phase fixture on lines 254-258 verbatim.

    4. Run: `bin/rails test test/models/table_monitor_test.rb 2>&1 | tail -40`

    5. Confirm RED/GREEN baseline:
       - Test 1 (BK-2plus): FAILS today
       - Test 2 (BK-2kombi DZ): FAILS today
       - Test 3 (karambol regression guard): PASSES today
       - Test 4 (BK-2kombi SP regression guard): PASSES today

    6. Commit RED:
       ```
       git add test/models/table_monitor_test.rb
       git commit -m "test(quick-260503-hay): RED tests for BK-2plus / BK-2kombi DZ phase-blind legacy innings_goal close

       Tests 1-2 fail today (legacy branch is phase-blind); tests 3-4 pass today
       (karambol legacy + BK-2kombi SP-inning-limit branches stay intact). The
       guard added in Task 2 will turn 1-2 GREEN without regressing 3-4.

       SKILL extend-before-build: tests sized for a one-line guard, no parallel
       test surface."
       ```

    Avoid: do NOT add or modify the `build_bk_data` helper. Do NOT touch other
    tests. Do NOT use `update!` (LocalProtector + persistence noise — direct
    @tm.data assignment matches existing test style on lines 254-258).
  </action>
  <verify>
    <automated>bin/rails test test/models/table_monitor_test.rb 2>&1 | tail -20</automated>
  </verify>
  <done>
    - 4 new tests appear in `test/models/table_monitor_test.rb` after line 318
    - Test 1 (BK-2plus standalone) FAILS with assertion message about
      "BK-2plus has NO Aufnahmenbegrenzung"
    - Test 2 (BK-2kombi DZ) FAILS with assertion message about "DZ-Phase has
      shot-limit per turn"
    - Test 3 (karambol regression) PASSES
    - Test 4 (BK-2kombi SP regression) PASSES
    - Pre-existing 21 tests in this file all still pass (no collateral breakage)
    - RED commit landed with `quick-260503-hay` prefix
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: GREEN — guard the legacy innings_goal-close branch to exclude BK-2plus and BK-2kombi DZ</name>
  <files>app/models/table_monitor.rb</files>
  <behavior>
    Modify the legacy `elsif` branch at lines 1583-1587 of `app/models/table_monitor.rb`
    (inside `end_of_set?`) so it skips BK-2plus and BK-2kombi DZ-Phase. After
    the change:

    - Test 1 (BK-2plus): GREEN — branch is skipped because `free_game_form` is "bk_2plus"
    - Test 2 (BK-2kombi DZ): GREEN — branch is skipped because DZ-Phase
    - Test 3 (karambol): STILL GREEN — branch fires (free_game_form != "bk_2plus" and != "bk2_kombi")
    - Test 4 (BK-2kombi SP): STILL GREEN — closes earlier via the 260501-uxo SP-inning-limit branch (lines 1568-1575) BEFORE reaching the legacy branch. Mark with code comment that the legacy branch is also exempt for SP-Phase, BUT note SP-Phase doesn't reach this code anyway because the SP-inning-limit branch returns first.

    The guard is a single `&&` clause prepended (or two combined `&&` clauses) to the
    existing `elsif` condition. Use existing helper `bk2_kombi_current_phase`.
  </behavior>
  <action>
    1. Open `app/models/table_monitor.rb` and locate the legacy `elsif` branch
       at lines 1583-1587 (inside `end_of_set?`).

    2. Replace the branch with a phase-aware version. SKILL extend-before-build:
       MINIMAL DELTA — add `&&` guards to the existing condition, do NOT extract
       a new predicate, do NOT refactor `end_of_set?`.

       Insert this guard logic. The cleanest expression uses a local variable
       defined just before the elsif (or use a lambda/case directly inline). To
       keep the diff small and the elsif readable, define a one-line local
       BEFORE the `if data["playera"]["balls_goal"]…` branch (line ~1578),
       inside the same method scope:

       ```ruby
       # Quick-260503-hay: BK-2plus standalone and BK-2kombi DZ-Phase have NO
       # Aufnahmenbegrenzung (inning limit per set). BK-2plus uses balls_goal
       # only; BK-2kombi DZ uses shot-limit per turn (not per set). The legacy
       # karambol innings_goal-close branch below is phase-blind — exclude
       # those two cases. BK-2 / BK-2kombi-SP are governed by the bk_with_nachstoss
       # block above (which fires first when triggered) and SHOULD also skip
       # this legacy branch as a defense-in-depth measure.
       #
       # SKILL extend-before-build: one-line guard on existing predicate, NO
       # parallel state machine.
       no_innings_limit_phase = case data["free_game_form"]
                                when "bk_2plus" then true
                                when "bk2_kombi" then bk2_kombi_current_phase == "direkter_zweikampf"
                                else false
                                end
       ```

       Then change the existing `elsif` (currently line 1583-1587) to:

       ```ruby
       elsif !no_innings_limit_phase && data["innings_goal"].to_i.positive? &&
             data["playera"]["innings"].to_i >= data["innings_goal"].to_i &&
             (data["playera"]["innings"] == data["playerb"]["innings"] || !data["allow_follow_up"])
         Rails.logger.info "[TableMonitor#end_of_set?] Game[#{game_id}] on TM[#{id}] ended: innings_goal reached (A:#{data["playera"]["innings"]}, B:#{data["playerb"]["innings"]}, goal:#{data["innings_goal"]})"
         return true
       end
       ```

       Place the `no_innings_limit_phase` local just BEFORE the
       `if data["playera"]["balls_goal"].to_i.positive? && (data["playera"]["result"]…`
       block (currently at line 1578) so it's in scope for the elsif. Keep the
       `if`/`elsif`/`end` chain intact.

    3. Run: `bin/rails test test/models/table_monitor_test.rb 2>&1 | tail -30`
       Confirm:
       - All 4 quick-260503-hay tests GREEN
       - All 21 pre-existing tests in this file still GREEN
       - 0 failures, 0 errors

    4. Run the broader BK-2 / BK-2kombi regression suite to catch collateral:
       ```
       bin/rails test test/models/table_monitor_test.rb test/services/bk2/ test/system/tiebreak_test.rb test/system/final_match_score_operator_gate_test.rb 2>&1 | tail -30
       ```
       Pre-existing failures (e.g., the 19 stale bk2_scoreboard_test failures
       from Phase 38.9 STATE notes) are acceptable — they predate this work.
       NEW failures are blockers.

    5. Commit GREEN:
       ```
       git add app/models/table_monitor.rb
       git commit -m "fix(quick-260503-hay): exclude BK-2plus / BK-2kombi DZ from legacy innings_goal close

       BCW Grand Prix 2026-05-03: BK-2plus standalone and BK-2kombi DZ-Phase
       aborted after 5 innings even without reaching balls_goal. Root cause:
       commit 1491385f set innings_goal=5 as a BK-* SP-phase safety net, and
       the legacy karambol close branch in TableMonitor#end_of_set? was
       phase-blind — fired whenever playera.innings >= innings_goal regardless
       of discipline.

       Fix: small no_innings_limit_phase local + one extra && guard on the
       existing elsif. BK-2plus and BK-2kombi DZ-Phase skip the legacy branch;
       all other paths (karambol, BK-2 SP, BK-2kombi SP) keep their existing
       behavior. The bk_with_nachstoss block above (Phase 38.7 + 38.9 +
       260501-uxo) already handles SP-phase safety net independently.

       Plan-01 RED tests turn GREEN; pre-existing 21 tests stay GREEN.

       SKILL extend-before-build: ~10 LOC additive guard on existing predicate,
       no new predicate, no refactor of end_of_set?."
       ```

    Avoid:
    - Do NOT touch the bk_with_nachstoss block (lines 1508-1576)
    - Do NOT touch the no_followup_phase / BK-immediate-close branch (lines 1481-1491)
    - Do NOT touch the controller — innings_goal=5 is still needed by the
      bk_with_nachstoss SP-phase safety net (260501-uxo branch at lines 1568-1575
      reads bk2_options.serienspiel_max_innings_per_set, NOT innings_goal — but
      changing the controller could break other consumers; out of scope)
    - Do NOT extract a new method; inline local var only (extend-before-build)
  </action>
  <verify>
    <automated>bin/rails test test/models/table_monitor_test.rb 2>&1 | tail -20</automated>
  </verify>
  <done>
    - `no_innings_limit_phase` local introduced just before the legacy
      `if/elsif/end` close-branch chain in `end_of_set?`
    - Legacy `elsif` extended with `!no_innings_limit_phase &&` as the FIRST clause
    - `bin/rails test test/models/table_monitor_test.rb` reports 25/25 tests pass
      (21 pre-existing + 4 new quick-260503-hay tests)
    - No NEW failures introduced in `test/services/bk2/` or
      `test/system/tiebreak_test.rb` (pre-existing failures in
      `test/services/bk2/scoreboard/` from Phase 38.9 are acceptable per STATE notes)
    - GREEN commit landed with `quick-260503-hay` prefix
    - SKILL extend-before-build: no new predicate added, no refactor of
      `end_of_set?` — diff is < 15 LOC of code (excluding comments)
  </done>
</task>

</tasks>

<verification>
After both tasks complete:

```bash
# Targeted: must be GREEN
bin/rails test test/models/table_monitor_test.rb

# Broader regression: must show NO NEW failures vs current baseline
bin/rails test test/system/tiebreak_test.rb test/system/final_match_score_operator_gate_test.rb

# Linting (warnings only, not blocking)
bundle exec standardrb app/models/table_monitor.rb test/models/table_monitor_test.rb
```

Manual verification (deferred — not blocking, do post-tournament if time):
- Quick-game start a BK-2plus standalone match, play past 5 innings, confirm set
  stays open until a player reaches balls_goal
- Quick-game start a BK-2kombi match (first_set_mode=DZ), play DZ-Phase past
  5 innings without balls_goal, confirm set stays open
- Quick-game start a BK-2kombi match into SP-Phase, play 5 innings each,
  confirm set DOES close (260501-uxo branch unchanged)
</verification>

<success_criteria>
- 4 new tests exist in `test/models/table_monitor_test.rb` under the
  `Quick-260503-hay` section
- All 25 tests in that file pass (21 pre-existing + 4 new)
- `app/models/table_monitor.rb` has a `no_innings_limit_phase` local + the
  guarded legacy `elsif` branch in `end_of_set?`
- Git history shows two commits with `quick-260503-hay` prefix:
  1. `test(quick-260503-hay): RED tests …`
  2. `fix(quick-260503-hay): exclude BK-2plus / BK-2kombi DZ from legacy innings_goal close`
- SKILL extend-before-build honored: no new predicate method, no refactor of
  `end_of_set?`, no parallel state machine, total LOC delta < 50 (including
  comments + tests)
- BCW Grand Prix BK-2kombi DZ-Phase + BK-2plus standalone matches no longer
  abort after 5 innings
</success_criteria>

<output>
After completion, create `.planning/quick/260503-hay-bk-2plus-phase-bk-2kombi-dz-phase-5-aufn/260503-hay-SUMMARY.md`
with:
- What changed (file-level diff summary)
- Test results (RED → GREEN delta)
- SKILL extend-before-build attestation
- Verification status (automated GREEN; manual deferred to post-tournament)
- Reference to the bug context (BCW Grand Prix 2026-05-03)
</output>
