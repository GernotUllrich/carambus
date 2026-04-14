---
phase: 36B
plan: 04
type: execute
wave: 1
depends_on: []
files_modified:
  - app/views/tournament_monitors/_current_games.html.erb
  - app/views/tournaments/_wizard_steps.html.erb
autonomous: true
requirements: [UI-04, UI-05]
tags: [cleanup, dead-code, erb, git-rm]

must_haves:
  truths:
    - "The Spielbeginn / manual-input cells (set_balls input, -1/+1/+10/-10 buttons, undo, next) are removed from the Aktuelle Spiele table"
    - "The read-only columns (table name, player, balls/innings totals, HS, GD, sets) are preserved"
    - "The file app/views/tournaments/_wizard_steps.html.erb no longer exists in git"
    - "The file app/views/tournaments/_wizard_step.html.erb still exists (it is used by _wizard_steps_v2.html.erb for steps 3-5)"
  artifacts:
    - path: "app/views/tournament_monitors/_current_games.html.erb"
      provides: "Read-only current games table (no manual input UI)"
    - path: "app/views/tournaments/_wizard_step.html.erb"
      provides: "Shared wizard step partial (still used by steps 3-5)"
      note: "NOT deleted - only _wizard_steps.html.erb (plural) is deleted"
  key_links:
    - from: "git tree"
      to: "absence of _wizard_steps.html.erb"
      via: "git rm"
      pattern: "_wizard_steps\\.html\\.erb"
---

<objective>
**UI-04 (dead-code manual input removal):** In `app/views/tournament_monitors/_current_games.html.erb`, remove the manual input UI cells from the "Aktuelle Spiele Runde X" table. Per F-36-28, this UI was meant as a fallback for when scoreboards fail, but the fallback is pointless because operators can enter results directly in ClubCloud in that case. The read-only columns (player name, balls, innings, HS, GD, sets) stay.

**UI-05 (unused partial deletion):** Delete `app/views/tournaments/_wizard_steps.html.erb` via `git rm`. Per Phase 33 scouting and CONTEXT.md D-14, only `_wizard_steps_v2.html.erb` is rendered from `show.html.erb:35`. Do NOT delete `_wizard_step.html.erb` (singular) — that file IS still used by `_wizard_steps_v2.html.erb` lines 247, 268, 286 for rendering steps 3, 4, and 5.

**Critical re-verification gate (D-14):** Before any `git rm`, re-run the grep for render references. If any reference to `_wizard_steps` (plural) exists outside the file itself, ABORT and flag a deviation. The file under consideration for deletion must not be the target of any `render` call.

**CONTEXT.md path correction:** CONTEXT.md refers to `tournament_monitor.html.erb` "Aktuelle Spiele" table, but the actual file is `app/views/tournament_monitors/_current_games.html.erb` (under the `tournament_monitors/` directory — note the trailing `s`). This plan targets the correct file.

**Wave-1 rationale:** this plan touches two files that no other wave-1 plan touches. Plan 01 touches `_wizard_steps_v2.html.erb` and `tournament_wizard_helper.rb`; plan 05 touches `show.html.erb`, `finalize_modus.html.erb`, and new shared files. No file conflicts → safe parallel execution.
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md
@.planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md
@app/views/tournament_monitors/_current_games.html.erb
@app/views/tournaments/_wizard_steps.html.erb
@app/views/tournaments/show.html.erb
</context>

<tasks>

<task type="checkpoint:gate">
  <name>Task 1: Re-verify _wizard_steps.html.erb has no remaining references (D-14 gate)</name>
  <read_first>
    - app/views/tournaments/show.html.erb line 35 (the canonical render call)
    - app/views/tournaments/_wizard_steps.html.erb (the file under consideration for deletion)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-14
  </read_first>
  <action>
This is an **evidence-gathering gate task** (type `checkpoint:gate`). It does not modify any files; it only runs greps to decide whether Task 3's `git rm` is safe to proceed. Execute this grep and capture the output:

    grep -rn "render.*wizard_steps" app/

Expected output: exactly ONE line matching `app/views/tournaments/show.html.erb:35:    <%= render 'wizard_steps_v2', tournament: @tournament %>`. Any additional line means there is a caller of `_wizard_steps.html.erb` (plural, v1) somewhere we must not delete.

Then run a SECOND grep to catch any reference to the file name itself (not partial name) in Ruby/ERB:

    grep -rn "wizard_steps\.html\.erb" app/

Expected output: zero lines OR only lines that appear inside comments. The file `_wizard_steps.html.erb` must not be referenced by any working code.

Decision matrix:
- If BOTH greps give the expected clean output → proceed to Task 2 and Task 3.
- If either grep finds an unexpected reference → ABORT Task 3 (the `git rm`) and leave the file in place. Write a deviation note in the plan summary and flag it to the orchestrator.

Also confirm `_wizard_step.html.erb` (singular) IS still referenced by running:

    grep -rn "render.*wizard_step[^s]" app/

Expected: at least THREE lines in `app/views/tournaments/_wizard_steps_v2.html.erb` (render calls for steps 3, 4, 5 at approximately lines 247, 268, 286). If this grep returns ZERO lines, something is wrong — STOP and investigate; do not touch either file.

This task modifies no files. It exists solely to gate Task 3 with explicit evidence.
  </action>
  <verify>
    <automated>ruby -e "out1 = \`grep -rn 'render.*wizard_steps' app/\`; lines1 = out1.split(10.chr); v2 = lines1.count { |l| l.include?('wizard_steps_v2') }; others = lines1.reject { |l| l.include?('wizard_steps_v2') || l.strip.empty? }.size; out2 = \`grep -rn 'render.*wizard_step[^s_]' app/\`; singular_refs = out2.split(10.chr).reject(&:empty?).size; if v2 >= 1 && others == 0 && singular_refs >= 3; puts 'GATE PASSED'; exit 0; else; puts %Q(GATE FAILED v2=\#{v2} others=\#{others} singular=\#{singular_refs}); exit 1; end"</automated>
  </verify>
  <acceptance_criteria>
    - grep for `render.*wizard_steps` in `app/` returns exactly one line, matching `_wizard_steps_v2`
    - grep for `render.*wizard_step[^s]` in `app/` returns 3 or more lines in `_wizard_steps_v2.html.erb`
    - No other Ruby/ERB file references `_wizard_steps` (plural) as a partial name
    - No files have been modified in this task (evidence-gathering gate only)
  </acceptance_criteria>
  <done>
    Evidence is captured confirming the deletion target has no remaining callers, and confirming the sibling partial `_wizard_step.html.erb` (singular) is still referenced. Task 3 is cleared to proceed.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Remove manual input UI from _current_games.html.erb</name>
  <files>app/views/tournament_monitors/_current_games.html.erb</files>
  <read_first>
    - app/views/tournament_monitors/_current_games.html.erb (full file, 148 lines)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-13
    - .planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md §F-36-28
  </read_first>
  <action>
Remove the manual-input cells from the per-game row inside the `<tbody>` loop. The target cells live between lines ~95 and ~128 of the current file, inside the `<% if tm.playing? %>` ... `<% if active_player %>` nested conditional.

Specifically, delete these cell blocks:

1. **`set_balls` number input cell** (currently lines ~100-104): the entire `<td>` containing `number_field_tag(:set_balls, ...)` and its Reflex data hooks.

2. **`-1` / `-10` / `+10` / `+1` button cell** (currently lines ~105-118): the entire `<td>` containing the four Reflex click handlers `click->TableMonitorReflex#minus_one`, `#minus_ten`, `#add_ten`, `#add_one`.

3. **`undo` button cell** (currently lines ~119-122): the entire `<td>` containing `click->TableMonitorReflex#undo`.

4. **`next` button cell** (currently lines ~123-127): the entire `<td>` containing `click->TableMonitorReflex#next_step`.

Also adjust the `<thead>`: the `<th colspan=5>` at line ~42 (`Current Inning`) and the `<th colspan=4>` at line ~47 (`inputs`) must shrink because the 4+ input columns are gone. Replace them with a single `<th>Current inning</th>` that displays only the current inning balls (read-only). This means removing the second header row entirely.

Concrete header replacement:

Replace the existing two-row header:

    <tr>
      <th rowspan="2">Table</th>
      <th rowspan="2">Player</th>
      <th rowspan="2">Balls</th>
      <th rowspan="2">of</th>
      <th rowspan="2">Inning</th>
      <th rowspan="2">of</th>
      <th rowspan="2">HS</th>
      <th rowspan="2">GD</th>
      (optional Sets th rowspan=2)
      <th class="noborder"/>
      <th colspan=5>Current Inning</th>
    </tr>
    <tr>
      <th/>
      <th>Balls</th>
      <th colspan=4>inputs</th>
    </tr>

with a single-row header (no `rowspan`, the trailing `<th/>` is gone, and `<th colspan=5>` becomes a single `<th>`):

    <tr>
      <th><%= I18n.t("tournament_monitors.current_games.table", :default => "Table") %></th>
      <th><%= I18n.t("tournament_monitors.current_games.player", :default => "Player") %></th>
      <th><%= I18n.t("tournament_monitors.current_games.balls", :default => "Balls") %></th>
      <th><%= I18n.t("tournament_monitors.current_games.of", :default => "of") %></th>
      <th><%= I18n.t("tournament_monitors.current_games.inning", :default => "Inning") %></th>
      <th><%= I18n.t("tournament_monitors.current_games.of", :default => "of") %></th>
      <th><%= I18n.t("tournament_monitors.current_games.hs", :default => "HS") %></th>
      <th><%= I18n.t("tournament_monitors.current_games.gd", :default => "GD") %></th>
      <%- if tournament_monitor.andand.sets_to_play > 1 %>
        <th><%= I18n.t("tournament_monitors.current_games.sets", :default => "Sets") %></th>
      <%- end %>
      <th><%= I18n.t("tournament_monitors.current_games.current_inning", :default => "Current inning") %></th>
    </tr>

Keep the current-inning balls display cell (currently lines ~97-99, inside the `active_player` branch): `<td ...><strong><%= active_player ? Array(tm.data[gp.role].andand["innings_redo_list"])[-1].to_i : "" %></strong></td>`. It is the single read-only "Current inning" column that the new header advertises.

**Preserve:**
- The `<% else %>` branch of `<% if tm.playing? %>` at approximately line 129 (the `set_over` / state-display branch at lines 131-137) — that renders the "OK?" / "wait_check" link and is NOT manual input. It is a read-only status display.
- The outer `<%- if tm.allow_change_tables %>` up/down arrow controls at lines ~61-71. Those are table-exchange UI, NOT inning input. Keep them.
- All `<td>` cells for player name, result, balls_goal, innings, innings_goal, hs, gd, sets (lines ~73-93). These are read-only display data.

**Do not touch:**
- The `<style>` block at the top.
- The `TableMonitor.includes...` query at approximately line 51.
- The `<% else %>` branch at approximately line 140 that handles games without a current game assigned.

Ruby/ERB semantics: removing 4 `<td>`s from a `<tr>` that uses `<th colspan=5>` in the header AND simplifying the header as described keeps the column count consistent between `<thead>` and `<tbody>`.
  </action>
  <verify>
    <automated>bundle exec erblint app/views/tournament_monitors/_current_games.html.erb</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "set_balls" app/views/tournament_monitors/_current_games.html.erb` returns `0`
    - `grep -c "TableMonitorReflex#minus_one" app/views/tournament_monitors/_current_games.html.erb` returns `0`
    - `grep -c "TableMonitorReflex#minus_ten" app/views/tournament_monitors/_current_games.html.erb` returns `0`
    - `grep -c "TableMonitorReflex#add_ten" app/views/tournament_monitors/_current_games.html.erb` returns `0`
    - `grep -c "TableMonitorReflex#add_one" app/views/tournament_monitors/_current_games.html.erb` returns `0`
    - `grep -c "TableMonitorReflex#undo" app/views/tournament_monitors/_current_games.html.erb` returns `0`
    - `grep -c "TableMonitorReflex#next_step" app/views/tournament_monitors/_current_games.html.erb` returns `0`
    - `grep -c "evaluate_result_table_monitor_path" app/views/tournament_monitors/_current_games.html.erb` returns a value `>= 1` (state-display link preserved)
    - `grep -c "TableMonitorReflex#up" app/views/tournament_monitors/_current_games.html.erb` returns `1` (table-exchange arrows preserved)
    - `grep -c "TableMonitorReflex#down" app/views/tournament_monitors/_current_games.html.erb` returns `1` (table-exchange arrows preserved)
    - `grep -c "gp.player.andand.fullname" app/views/tournament_monitors/_current_games.html.erb` returns a value `>= 1` (read-only player name preserved)
    - `bundle exec erblint app/views/tournament_monitors/_current_games.html.erb` exits 0
  </acceptance_criteria>
  <done>
    Manual input cells are gone, state-display link and table-exchange arrows are preserved, and the table header no longer claims columns that don't exist. erblint is clean.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 3: git rm _wizard_steps.html.erb (gated by Task 1)</name>
  <files>app/views/tournaments/_wizard_steps.html.erb</files>
  <read_first>
    - Task 1 output (re-verification gate must have passed)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-14
  </read_first>
  <action>
Only proceed if Task 1 passed (GATE PASSED). Then run:

    git rm app/views/tournaments/_wizard_steps.html.erb

Do NOT run `git rm app/views/tournaments/_wizard_step.html.erb` — that file is still used by `_wizard_steps_v2.html.erb` for steps 3, 4, 5.

If the `git rm` fails because the file is not tracked, investigate before proceeding — it should be tracked.

After the deletion, re-run the verification grep once more to confirm clean state:

    grep -rn "render.*wizard_steps" app/
    grep -rn "wizard_steps\.html\.erb" app/

Both must either be clean or match only `_wizard_steps_v2.html.erb` (the canonical partial that stays).
  </action>
  <verify>
    <automated>ruby -e "fail 'file still exists' if File.exist?('app/views/tournaments/_wizard_steps.html.erb'); fail 'canonical partial missing' unless File.exist?('app/views/tournaments/_wizard_steps_v2.html.erb'); fail '_wizard_step.html.erb (singular) must still exist' unless File.exist?('app/views/tournaments/_wizard_step.html.erb'); tracked = \`git ls-files app/views/tournaments/_wizard_steps.html.erb\`.strip; fail 'still tracked in git' unless tracked.empty?; puts 'OK'"</automated>
  </verify>
  <acceptance_criteria>
    - `test ! -f app/views/tournaments/_wizard_steps.html.erb` exits 0 (file is gone)
    - `test -f app/views/tournaments/_wizard_steps_v2.html.erb` exits 0 (canonical partial stays)
    - `test -f app/views/tournaments/_wizard_step.html.erb` exits 0 (singular partial stays — still used for steps 3-5)
    - `git ls-files app/views/tournaments/_wizard_steps.html.erb` returns empty output (no longer tracked)
    - `git status --porcelain app/views/tournaments/_wizard_steps.html.erb` shows `D  ` (staged deletion)
  </acceptance_criteria>
  <done>
    `_wizard_steps.html.erb` is staged for deletion in git; `_wizard_steps_v2.html.erb` and `_wizard_step.html.erb` both remain in the working tree.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| operator browser → TableMonitorReflex | Manual-input cells were the only path for operator-driven result entry in this table; plan removes the path entirely |
| partial render chain | `show.html.erb` → `_wizard_steps_v2.html.erb` is the canonical chain; deleting the unused sibling removes a confusing deadend |

## STRIDE Threat Register (ASVS L1)

| Threat ID | Category | Component | Disposition | Mitigation |
|-----------|----------|-----------|-------------|------------|
| T-36b04-01 | Denial of service (D) | Column count mismatch between `<thead>` and `<tbody>` breaks table rendering | mitigate | Task 2 explicitly rewrites the header to a single row with the same column count as the surviving `<tbody>` row. erblint pass + manual browser UAT confirms render integrity. |
| T-36b04-02 | Tampering (T) | Deleting `_wizard_steps.html.erb` breaks a caller we didn't know about | mitigate | Task 1 is a mandatory re-verification gate BEFORE the `git rm` runs. Two independent greps (partial name + filename) must both come back clean. If either finds a caller, Task 3 aborts and leaves the file in place. |
| T-36b04-03 | Tampering (T) | Deleting the wrong file (`_wizard_step.html.erb` singular, which is still used) | mitigate | Task 3 explicitly targets the plural filename only. Task 1 asserts `_wizard_step` singular has `>= 3` render references. The acceptance criteria includes `test -f _wizard_step.html.erb` (positive existence check). |
| T-36b04-04 | Repudiation (R) | An operator later wonders "how do I enter a result manually if the scoreboard fails?" | accept | Per F-36-28 SME analysis: if scoreboards fail, the operator enters results directly into ClubCloud, not into Carambus. The dead fallback UI was misleading users into thinking there was a second path when there isn't. Removing it is a clarity win. |
</threat_model>

<verification>
1. `bundle exec erblint app/views/tournament_monitors/_current_games.html.erb` exits 0.
2. All grep-based acceptance criteria pass.
3. `test ! -f app/views/tournaments/_wizard_steps.html.erb && test -f app/views/tournaments/_wizard_steps_v2.html.erb && test -f app/views/tournaments/_wizard_step.html.erb` exits 0.
4. `git status` shows a staged deletion for `_wizard_steps.html.erb` and a modified `_current_games.html.erb`.
5. Manual UAT (user runs in carambus_bcw, D-21): open a running tournament's monitor page → "Aktuelle Spiele" table shows player data without input fields or plus/minus buttons; the state-display link ("OK?" / "wait_check") still works.
</verification>

<success_criteria>
- UI-04: ✅ Dead-code manual input UI removed from `_current_games.html.erb`; read-only columns preserved; table header simplified to a single row
- UI-05: ✅ `_wizard_steps.html.erb` deleted via `git rm`; `_wizard_step.html.erb` (singular) preserved; re-verification gate confirms no callers
</success_criteria>

<output>
After completion, create `.planning/phases/36B-ui-cleanup-kleine-features/36B-04-SUMMARY.md` listing: the re-verification gate result, the header rewrite, the 4 deleted cell blocks, the `git rm` outcome, and explicit confirmation that `_wizard_step.html.erb` (singular) was NOT deleted.
</output>
</content>
</invoke>