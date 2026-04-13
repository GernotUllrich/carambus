---
phase: 33
plan: 03
type: execute
wave: 3
depends_on:
  - 33-01
  - 33-02
files_modified:
  - .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md
autonomous: true
requirements:
  - UX-01
  - UX-02
  - UX-03
  - UX-04
must_haves:
  truths:
    - "Every finding in 33-UX-FINDINGS.md has a stable ID F-NN numbered sequentially across the whole file per D-05"
    - "Every finding has a Tier column value of 1, 2, or 3 per D-11"
    - "Every Tier 3 finding has Gate = blocked-needs-test-plan per D-12"
    - "Every non-Tier-3 finding has Gate = open per D-08"
    - "A retirement finding (Tier 1, open gate) for non-canonical partials _wizard_steps.html.erb and _wizard_step.html.erb exists per D-09"
    - "The Non-happy-path actions (not reviewed) section lists action names only per D-07"
    - "The file's top-level status is updated to 'Complete — Phase 33 final'"
  artifacts:
    - path: ".planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md"
      provides: "Final tier-classified findings with stable IDs, gates, retirement decision, and non-happy-path list"
      contains: "F-01"
  key_links:
    - from: "Every Tier 3 finding row"
      to: "Phase 36 gating contract"
      via: "Gate column value 'blocked-needs-test-plan'"
      pattern: "blocked-needs-test-plan"
    - from: "Retirement finding row"
      to: "Phase 36 deletion task"
      via: "Tier 1 finding explicitly naming _wizard_steps.html.erb and _wizard_step.html.erb"
      pattern: "_wizard_steps.html.erb"
---

<objective>
Finalize `33-UX-FINDINGS.md`: assign stable F-NN IDs sequentially across the whole file per D-05, tier-classify every finding per D-11 using the mechanical "highest layer touched" rule, apply gates per D-08/D-12 (Tier 3 → `blocked-needs-test-plan`, everything else → `open`), add the retirement finding for non-canonical partials per D-09, fill the Non-happy-path actions section per D-07, and mark the file complete. This plan turns raw observations into the authoritative spec that Phase 34 and Phase 36 reference by ID.

Purpose: UX-03 and UX-04 are satisfied by classification + completeness, not by observation. This plan closes the audit cleanly so downstream phases have a contract they can diff against.

Output: `33-UX-FINDINGS.md` in its final form — every finding has ID + Type + Tier + Gate; retirement decision captured; non-happy-path action names listed; status updated.
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/33-ux-review-wizard-audit/33-CONTEXT.md
@.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md
@.planning/REQUIREMENTS.md

<interfaces>
<!-- Tier classification rules (D-11) — mechanical, no judgment.
     Ambiguous cases resolve HIGHER, not lower. -->

## Tier 1 (lowest impact — view / copy only)
- Changes to an ERB view file under `app/views/`
- Changes to `config/locales/*.yml` (i18n key values or new keys)
- Changes to help text strings
- Creating a new partial under `app/views/`
- CSS / Tailwind utility class changes
- Adding a new i18n key

## Tier 2 (controller / route / service)
- Any change to a file under `app/controllers/`
- Any change to `config/routes.rb`
- Any change to a file under `app/services/`
- Any change to a file under `app/helpers/`
- Any change to `app/reflexes/`
- Adding a new strong param

## Tier 3 (AASM state machine)
- Any change inside the `aasm do ... end` block in `app/models/tournament.rb` (or any model with AASM)
- Adding, removing, or renaming a state
- Adding, removing, or renaming an event/transition
- Changing guards or callbacks attached to an AASM transition
- Any change that alters the allowed state sequence

## Gating rule (D-08, D-12)
- Tier 1 → Gate: `open`
- Tier 2 → Gate: `open`
- Tier 3 → Gate: `blocked-needs-test-plan`

## Type rule (D-06, D-13)
- `ux` — friction / unclear labels / missing help / confusing order
- `bug` — something is wrong (documented-but-missing, broken link, wrong behavior)
- `missing-feature` — documented somewhere but not implemented
- Type does NOT affect Tier; tier is purely about "highest layer touched to fix"

## Non-happy-path actions to list (D-07, from tournaments_controller.rb)
Examples the executor should grep/confirm from the controller:
- cancel / destroy
- reset / reset_seeding
- admin/advanced flows
- any action not in [new, create, edit, finish_seeding, start]
Listed by action name only — no review, no findings.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Assign stable IDs, tier-classify, gate, and add retirement finding</name>
  <files>
    .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md
  </files>
  <read_first>
    - .planning/phases/33-ux-review-wizard-audit/33-CONTEXT.md (D-05 through D-13 — all LOCKED)
    - .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md (the file in its Plan 02 state — raw findings with F-TMP-NN or ? IDs)
    - app/controllers/tournaments_controller.rb (to list non-happy-path action names for D-07; grep `def ` inside the class)
    - app/views/tournaments/show.html.erb (to confirm the `render 'wizard_steps_v2'` call still reads as the single wizard render — re-verify the retirement-finding premise)
    - app/views/tournaments/_wizard_steps.html.erb (confirm it exists as a retirement candidate)
    - app/views/tournaments/_wizard_step.html.erb (confirm it exists as a retirement candidate)
  </read_first>
  <action>
    Walk through `33-UX-FINDINGS.md` from top to bottom and perform the following edits. Do NOT rewrite the file from scratch — edit in place so Plan 02's observation prose is preserved exactly.

    **Step 1 — Renumber findings (D-05).** Starting from the first happy-path H2 (`## new`), walk every finding table row in document order and replace the temporary ID (`F-TMP-NN` or `?`) with a stable sequential ID `F-01`, `F-02`, `F-03`, ... There is ONE counter across the whole file; do not reset at each H2. The last ID used becomes the watermark for any new findings added in this plan.

    **Step 2 — Tier-classify every row (D-11).** For each finding, apply the mechanical rule from `<interfaces>` above — ask "what is the highest layer any fix would touch?" and write that tier number into the Tier column. Ambiguous → higher tier. Examples:
    - "No confirmation dialog before finish_seeding" → adding a JS confirm in the view → Tier 1
    - "finish_seeding controller redirects to wrong page" → controller change → Tier 2
    - "tournament_started_waiting_for_monitors state is user-invisible but should show a spinner" → view-only (spinner in partial) → Tier 1
    - "transient state is skipped by the AASM transition when monitor_count is 0" → AASM guard change → Tier 3
    - Do not apply judgment beyond the rule. The rule is the spec.

    **Step 3 — Apply gates (D-08, D-12).** For every row:
    - Tier 1 or Tier 2 → Gate column = `open`
    - Tier 3 → Gate column = `blocked-needs-test-plan`
    This must be deterministic: after this step, every Tier 3 row has the gated value and no other rows do.

    **Step 4 — Add the retirement finding (D-09, UX-01).** In the `## new` section (or wherever most appropriate for the canonical-partial topic — your choice, but a single H2 must own it), add one new finding row using the next available F-NN ID. Content:
    - Type: `ux` (classification; D-09 calls it a Tier 1 finding that Phase 36 will execute)
    - Finding: `Retire non-canonical wizard partials app/views/tournaments/_wizard_steps.html.erb and app/views/tournaments/_wizard_step.html.erb — canonical is _wizard_steps_v2.html.erb per grep evidence above. Deletion executed in Phase 36.`
    - Tier: `1`
    - Gate: `open`

    Reference the grep evidence section by prose (e.g., "see §Canonical wizard partial — grep evidence") so the traceability chain is explicit.

    **Step 5 — Fill the Non-happy-path actions section (D-07).** Replace the `_to be filled by Plan 03 per D-07_` placeholder with a bulleted list of non-happy-path action names from `app/controllers/tournaments_controller.rb`. Do NOT review or classify these — action names only. Run `grep -n "^  def " app/controllers/tournaments_controller.rb` to get the complete action list, then exclude the five happy-path actions (`new`, `create`, `edit`, `finish_seeding`, `start`) and any private helpers. Add one sentence above the list stating: "These actions were deliberately not reviewed in Phase 33. Any UX review of these is out of scope for v7.0 per ROADMAP.md."

    **Step 6 — Update status line.** At the top of the file, change the status line from "In progress — Plan 01 scaffold" (or whatever Plan 02 left it as) to "Complete — Phase 33 final (2026-04-13)".

    **Step 7 — Sanity scan.** Before finishing:
    - Grep the file for any remaining `F-TMP`, `?` in ID/Tier/Gate columns, or `_to be filled` — any match is a bug; fix it.
    - Grep for `Tier 3` and confirm every match on a table row is followed by `blocked-needs-test-plan` in the Gate column (multiline regex acceptable).
    - Confirm the file still contains the Plan 01 grep evidence literally (both D-10 commands + their raw output blocks).
    - Confirm all six happy-path H2s still exist and each still has Intent/Observed/Screenshot lines from Plan 02.

    Do NOT touch any file outside `.planning/phases/33-ux-review-wizard-audit/`. Do NOT delete `_wizard_steps.html.erb` or `_wizard_step.html.erb` — deletion is deferred to Phase 36 per D-09. The plan records the decision; it does not execute it.
  </action>
  <verify>
    <automated>grep -q "F-01" .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md && ! grep -q "F-TMP" .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md && ! grep -q "_to be filled" .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md && grep -q "Non-happy-path actions (not reviewed)" .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md && grep -q "_wizard_steps.html.erb" .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md && grep -q "Complete" .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md</automated>
  </verify>
  <acceptance_criteria>
    - File contains literal string `F-01` (first stable ID assigned)
    - File does NOT contain the string `F-TMP` (no leftover placeholder IDs)
    - File does NOT contain the string `_to be filled` (all placeholders resolved)
    - File contains literal string `## Non-happy-path actions (not reviewed)` followed by at least two action-name bullet points
    - File contains literal strings `_wizard_steps.html.erb` and `_wizard_step.html.erb` in the body of a finding row (retirement finding present)
    - For every Tier 3 finding row, the Gate column value is `blocked-needs-test-plan` — verify with: `awk -F'|' '/Tier 3/ { if ($0 !~ /blocked-needs-test-plan/) exit 1 }' .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md` returning exit 0
    - File top matter contains the word `Complete` (status updated)
    - `git status` shows no modifications outside `.planning/phases/33-ux-review-wizard-audit/`
    - The Plan 01 grep evidence commands (`grep -rn "wizard_steps` and `grep -n "render.*wizard"`) still appear verbatim in the file
    - All six H2s (`## new`, `## create`, `## edit`, `## finish_seeding`, `## start`, `## tournament_started_waiting_for_monitors`) still exist
  </acceptance_criteria>
  <done>
    `33-UX-FINDINGS.md` is final: every finding has stable ID F-NN, Type, Tier, Gate; Tier 3 findings are explicitly gated; retirement finding for non-canonical partials is recorded; non-happy-path actions are listed; status reads Complete. No production files touched. The file is ready to be consumed by Phase 34 (task-first doc rewrite — uses happy-path narrative) and Phase 36 (small UX fixes — references findings by F-NN and filters on tier + gate).
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| N/A | Finalization plan edits only the findings file; no code, no routes, no data flows |

## STRIDE Threat Register

Audit phase: no production code modified, no new attack surface introduced. N/A.
</threat_model>

<verification>
- Every finding has stable F-NN ID, a Tier (1/2/3), and a Gate (`open` or `blocked-needs-test-plan`)
- Every Tier 3 row has `blocked-needs-test-plan`
- Retirement finding present per D-09
- Non-happy-path section populated with action names only per D-07
- Status updated to Complete
- No changes outside `.planning/phases/33-ux-review-wizard-audit/`
</verification>

<success_criteria>
Phase 33 complete when `33-UX-FINDINGS.md` can be opened by Phase 36 planning and every finding is addressable by (F-NN, Tier, Gate) — no observation, judgment, or source re-reading required. The retirement decision for non-canonical partials is captured as a Tier 1 finding with an open gate.
</success_criteria>

<output>
After completion, create `.planning/phases/33-ux-review-wizard-audit/33-03-SUMMARY.md`
</output>
