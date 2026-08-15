---
status: diagnosed
trigger: "Phase 38.7 TR-Ctl UAT — BK-2 untied final inning: Player A reaches balls_goal in inning 2; transitions to Player B WITHOUT showing the red 'Nachstoß' banner; after Player B's Nachstoss-Aufnahme, game ends. User expectation: game should END after Player A reaches goal in 2nd inning (no Nachstoss-Aufnahme), but instead Player B gets an extra inning silently."
created: 2026-04-30T18:00:00Z
updated: 2026-04-30T18:00:00Z
---

## Current Focus

hypothesis: H3 confirmed (with refinement) — pre-existing semantic mismatch between `follow_up?` (suppresses banner via Erste-Aufnahme-Gate) and `terminate_inning_data` (always switches `active_player`); becomes user-visible whenever Anstoss-Spieler reaches `balls_goal` in inning 2+ in a BK-2 / BK-2kombi-SP game.
test: cross-read `TableMonitor#follow_up?` (lines 1185-1190), `TableMonitor#end_of_set?` (lines 1488-1518), `ScoreEngine#terminate_inning_data` (line 1306), and the banner conditional in `_player_score_panel.html.erb` (lines 125-127, 185-187).
expecting: confirmed — three predicates work on independent gating rules; the inning-switch path has NO Erste-Aufnahme-Gate, so Player B always gets a switch even when the banner conditional rejects it.
next_action: defer fix to next gap-closure plan; document recommended fix below.

## Symptoms

expected: BK-2 quick-game; Anstoss-Spieler (Player A) reaches `balls_goal` in his 2nd inning. Per BK-2 rule (Erste-Aufnahme-Gate), Nachstoss-Aufnahme is only granted if Anstoss reached the goal in his 1st inning. Reaching it in inning 2+ means Anstoss already had table-time; opponent gets NO equalizer chance. Therefore: the game/set should END immediately when Player A reaches goal in inning 2.
actual: Game does NOT end. `active_player` switches to Player B (no red "Nachstoß" banner appears, because banner conditional correctly evaluates to false per the Erste-Aufnahme-Gate). Player B plays a stoss/inning. After his inning terminates (innings counter increments to 1), the game ends.
errors: none — pure logical/semantic mismatch, no exception.
reproduction:
  1. Start BK-2 quick game (TR-Ctl preset; balls_goal>0; allow_follow_up forced true by controller).
  2. Player A: inning 1 → some score below goal; inning ends (manual switch or via control button).
  3. Player A: inning 2 → reaches balls_goal exactly.
  4. Observe: active_player switches to Player B with NO Nachstoß banner shown.
  5. Player B plays his inning; on terminate_inning, game ends.
started: never worked correctly under the BK-2-with-Nachstoss path. Pre-existing latent semantics — surfaced by the user during phase 38.7 TR-Ctl validation. NOT a regression from plan-02 D-02 fix or plan-13 modal fix.

## Eliminated

- hypothesis: H1 — Plan 02's BK-2 game-end fix changed transitions so `nachstoss_aufnahme?` now returns false during the Nachstoss phase
  evidence: There is no `nachstoss_aufnahme?` predicate. Banner conditional is `table_monitor.follow_up? && player_active && options[:allow_follow_up]` (`_player_score_panel.html.erb:125, 185`). Plan 02 added an `end_of_set?` branch (`table_monitor.rb:1488-1508`) but did NOT touch `follow_up?`. Pre-Plan-02 git blame confirms the Erste-Aufnahme-Gate (`table_monitor.rb:1188-1190`) was introduced in commit 79328663 (Apr 28, before phase 38.7 began on Apr 30).
  timestamp: 2026-04-30T18:00:00Z

- hypothesis: H2 — banner gated on a "scores not yet equal" predicate that became coupled to tiebreak state via Plan 04/05
  evidence: Banner conditional reads only `follow_up?`, `player_active`, `options[:allow_follow_up]` — NONE of these inspect `tiebreak_required` / `tiebreak_winner`. `OptionsPresenter#allow_follow_up` (line 86) is a passthrough of `data["allow_follow_up"]`; for BK-2 the controller (`table_monitors_controller.rb:328`) forces it to `true` unconditionally. No tiebreak coupling exists in the banner path.
  timestamp: 2026-04-30T18:00:00Z

## Evidence

- timestamp: 2026-04-30T18:00:00Z
  checked: banner render conditional in `app/views/table_monitors/_player_score_panel.html.erb`
  found: lines 125-127 (left position) and 185-187 (right position) both render `<div>Nachstoß</div>` only when `table_monitor.follow_up? && player_active && options[:allow_follow_up]` is true. Single point of UI signaling.
  implication: Banner depends entirely on `follow_up?` returning true; when it returns false, banner is silent — even if a follow-up inning is otherwise underway.

- timestamp: 2026-04-30T18:00:00Z
  checked: `TableMonitor#follow_up?` (`app/models/table_monitor.rb:1169-1199`)
  found: After computing legacy `ret` (Nachstoss-Spieler is active AND Anstoss-Spieler reached balls_goal/innings_goal), an Erste-Aufnahme-Gate at lines 1188-1190 forces `ret = false` for BK-2 / BK-2kombi unless `data[left_player_id]["innings"] == 1`. After Anstoss completes inning 2 reaching balls_goal, his `innings` is 2 (incremented by `terminate_inning_data:1268-1270`), so gate fails → `follow_up?` returns false → banner suppressed.
  implication: Predicate is correct per the documented BK-2 rule ("Nachstoß nur wenn Anstoßspieler das Ziel in seiner 1. Aufnahme erreicht hat"). The bug is NOT here.

- timestamp: 2026-04-30T18:00:00Z
  checked: `TableMonitor#end_of_set?` (`app/models/table_monitor.rb:1456-1521`)
  found: Three branches relevant for BK-2:
    1. `no_followup_phase` immediate-close (lines 1461-1471): only fires for BK-2plus/BK50/BK100/BK-2kombi-DZ — NOT BK-2.
    2. Plan 02 D-02 `bk_with_nachstoss` close (lines 1488-1508): fires when `anstoss_at_goal && nachstoss_innings == anstoss_innings + 1`. After Anstoss inning 2 ends with goal: `anstoss_innings=2`, `nachstoss_innings=0`. Mismatch (`0 != 3`) → does NOT fire.
    3. Legacy karambol close (lines 1510-1514): requires `playera.innings == playerb.innings` (parity) OR `!data["allow_follow_up"]`. For BK-2 controller forces `allow_follow_up=true`; parity is `2 == 0` false → does NOT fire.
  implication: When Anstoss reaches goal in inning 2+, NO branch in `end_of_set?` fires. The set stays open. After `terminate_current_inning` the active_player switches (per `score_engine.rb:1306` unconditional swap), Player B plays, and only after Nachstoss innings catches up to parity does the legacy gate at line 1512 finally close it. THIS is the silent extra-inning the user observed.

- timestamp: 2026-04-30T18:00:00Z
  checked: `ScoreEngine#terminate_inning_data` (`app/models/table_monitor/score_engine.rb:1306`)
  found: `data["current_inning"]["active_player"] = other_player` is unconditional. There is NO Erste-Aufnahme-Gate or follow-up check here.
  implication: Active player switch happens regardless of whether the Nachstoss-Aufnahme is rule-permitted. The asymmetry between `follow_up?` (gated) and `terminate_inning_data` (ungated) is the root of the discrepancy.

- timestamp: 2026-04-30T18:00:00Z
  checked: existing test `test/models/table_monitor_test.rb:156-166` ("end_of_set? does NOT fire when Nachstoss has not reached balls_goal — regression guard")
  found: This test pins the case `playera_innings: 5, playerb_innings: 6, playera_result: 50, playera_balls_goal: 50` and asserts `end_of_set?` returns true via the Plan 02 D-02 branch. NO test covers the user's scenario (Anstoss at goal in inning 2 with playerb innings=0).
  implication: The bug is invisible to current test coverage. The fix needs a new RED test asserting either (a) `end_of_set?` returns true immediately when Anstoss-Spieler reached goal in inning >= 2 (BK-2/BK-2kombi-SP only), OR (b) `follow_up?` and the inning-switch logic agree.

## Resolution

root_cause: |
  Three-way semantic mismatch in BK-2 / BK-2kombi-SP scoring path. The `follow_up?` predicate
  (`table_monitor.rb:1188-1190`) correctly enforces the BK-2 Erste-Aufnahme-Gate (Nachstoß only
  when Anstoss-Spieler reached goal in inning 1), suppressing the banner when Anstoss reached
  goal in inning 2+. However:

  1. `ScoreEngine#terminate_inning_data` (`score_engine.rb:1306`) ALWAYS switches `active_player`
     after an inning ends, regardless of the Erste-Aufnahme-Gate — there is no follow-up gate at
     the inning-switch level.
  2. `TableMonitor#end_of_set?` (`table_monitor.rb:1456-1521`) has THREE BK-2 branches but NONE
     of them detect the rule-violation case "Anstoss reached goal in inning >= 2": the
     `no_followup_phase` block excludes BK-2; the Plan 02 D-02 branch requires Nachstoss to
     have a 1-inning lag (`nachstoss_innings == anstoss_innings + 1`); the legacy karambol
     branch requires either innings parity or `allow_follow_up=false` (BK-2 forces it true).

  Result: when Anstoss-Spieler reaches `balls_goal` in inning 2 of a BK-2 game,
  `end_of_set?` returns false → set stays open → `active_player` switches to Player B silently
  (banner conditional rejects the switch but doesn't suppress it) → Player B plays an
  unauthorized inning → only after innings-parity is reached does the legacy gate finally close.

  This is a pre-existing latent defect introduced together with the Erste-Aufnahme-Gate in
  commit 79328663 (Apr 28, before phase 38.7). It became user-visible during TR-Ctl UAT because
  the BK-2 quick-game with Anstoss-reaches-goal-in-inning-2 scenario was not part of any prior
  test fixture or UAT scenario.

fix: NOT applied (diagnose-only mode).

  Recommended fix sketch — add a fourth BK-2 branch in `end_of_set?` that mirrors the
  Erste-Aufnahme-Gate logic of `follow_up?`. Proposed insertion BETWEEN current Plan 02 D-02
  branch (line 1508) and the legacy karambol balls_goal branch (line 1510):

  ```ruby
  # Phase 38.7 Gap-XX — BK-2 / BK-2kombi-SP no-Nachstoss-permitted close.
  # Mirror of follow_up? Erste-Aufnahme-Gate: when Anstoss-Spieler reached
  # balls_goal in inning >= 2, Nachstoss-Aufnahme is rule-disallowed, so the
  # set MUST close immediately — symmetric with the no_followup_phase block
  # for BK-2plus/BK50/BK100/BK-2kombi-DZ at the top of this method.
  if bk_with_nachstoss && data["playera"]["balls_goal"].to_i.positive?
    anstoss_role = data["current_kickoff_player"].presence || "playera"
    anstoss_at_goal = data[anstoss_role]["result"].to_i >= data[anstoss_role]["balls_goal"].to_i
    anstoss_past_first_inning = data[anstoss_role]["innings"].to_i >= 2
    if anstoss_at_goal && anstoss_past_first_inning
      Rails.logger.info "[end_of_set?] Gap-XX BK-2 no-Nachstoss close: anstoss=#{anstoss_role} reached goal in inning #{data[anstoss_role]["innings"]} (>= 2) — Erste-Aufnahme-Gate fails"
      return true
    end
  end
  ```

  Same predicate shape as the Plan 02 D-02 branch (lines 1488-1508). Reuses the
  `bk_with_nachstoss` local and the `current_kickoff_player`-with-`playera`-fallback Anstoss
  role identification. Single integer comparison difference (`>= 2` instead of innings
  asymmetry).

verification: NOT performed (diagnose-only mode).

  Test scope for the next gap-closure plan (RED-then-GREEN, mirrors plan-02/plan-13 protocol):
    - test/models/table_monitor_test.rb: append 2 RED tests:
      a. BK-2: `playera_result==balls_goal, playera_innings=2, playerb_innings=0` →
         `end_of_set?` must return true (currently returns false, demonstrating bug).
      b. BK-2kombi-SP (with `data["sets"]=[<one prior set>]` to put us in SP-phase):
         same scenario → `end_of_set?` must return true.
    - test/models/table_monitor_test.rb: append 1 regression-guard:
      c. BK-2: `playera_result==balls_goal, playera_innings=1, playerb_innings=0` →
         `end_of_set?` must return false (Erste-Aufnahme satisfied, Nachstoß permitted, set
         stays open until Plan 02 D-02 closes after Nachstoss-Aufnahme). Pins that the new
         branch does NOT collide with the existing BK-2 Nachstoss path.
    - Optionally: a system test that reproduces the user's flow end-to-end (BK-2 quick-game,
      `add_n_balls(balls_goal)` after one prior inning of zero, observe game lands in
      `set_over` state without an intermediate active_player switch). Following plan-13 pattern,
      this can be a render-based test asserting the score panel does NOT receive the
      `<div>Nachstoß</div>` HTML in the post-second-inning render.

files_changed: []  # diagnose-only, no fix applied
