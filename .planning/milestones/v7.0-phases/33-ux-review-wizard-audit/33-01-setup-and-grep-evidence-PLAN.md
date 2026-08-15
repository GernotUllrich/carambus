---
phase: 33
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md
autonomous: true
requirements:
  - UX-01
  - UX-02
  - UX-04
must_haves:
  truths:
    - "A reproduction recipe exists at the top of 33-UX-FINDINGS.md that another auditor can copy-paste to re-run the walkthrough"
    - "Grep evidence proves _wizard_steps_v2.html.erb is the only wizard partial rendered by show.html.erb"
    - "Every reference (if any) to _wizard_steps.html.erb and _wizard_step.html.erb across app/, config/, test/ is captured literally in the findings file"
    - "The findings file has the skeleton of H2 sections for new, create, edit, finish_seeding, start, and tournament_started_waiting_for_monitors"
  artifacts:
    - path: ".planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md"
      provides: "Scaffold with reproduction recipe, grep evidence block, and empty H2 section skeleton"
      contains: "Reproduction recipe"
    - path: ".planning/phases/33-ux-review-wizard-audit/screenshots/"
      provides: "Empty directory ready for Plan 02 screenshots"
  key_links:
    - from: "33-UX-FINDINGS.md"
      to: "app/views/tournaments/show.html.erb"
      via: "grep command literal in findings file"
      pattern: "grep -n \"render.*wizard\" app/views/tournaments/show.html.erb"
    - from: "33-UX-FINDINGS.md"
      to: "app/, config/, test/"
      via: "grep command literal in findings file"
      pattern: "grep -rn \"wizard_steps.wizard_step\" app/ config/ test/"
---

<objective>
Establish the audit foundation: create the reproduction recipe, collect the grep evidence that proves canonicality of `_wizard_steps_v2.html.erb` per D-10 (UX-01), and scaffold `33-UX-FINDINGS.md` with the H2 skeleton per D-04 so Plan 02's browser observations and Plan 03's tier classification can fill it in.

Purpose: Phase 34 and Phase 36 need a single authoritative file they can reference by stable finding IDs. Plan 01 creates that file's structure and preserves the machine-checkable evidence for UX-01 up front, so later plans never have to re-derive it.

Output: `33-UX-FINDINGS.md` with reproduction recipe, grep evidence block, and empty H2 sections ready for observation data; `screenshots/` directory created empty.
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/33-ux-review-wizard-audit/33-CONTEXT.md
@.planning/REQUIREMENTS.md
@.planning/ROADMAP.md

<interfaces>
<!-- Key shape the findings file must conform to. Copy these skeletons verbatim into the file. -->

## H2 section template (D-04 — use this exact shape for every happy-path action)
```
## <action>

**Intent:** what the volunteer is trying to do
**Observed:** what the UI actually shows/does
**Screenshot:** screenshots/NN-<action>.png

| ID   | Type | Finding           | Tier | Gate |
|------|------|-------------------|------|------|
| F-NN | ux   | ...               | 1    | open |
```

## Happy-path H2 sections to scaffold (in this order)
1. `## new`
2. `## create`
3. `## edit`
4. `## finish_seeding`
5. `## start`
6. `## tournament_started_waiting_for_monitors` (transient state — its own H2 per UX-02)

## Grep commands (D-10 — must appear literally in the file)
```
grep -rn "wizard_steps\|wizard_step" app/ config/ test/
grep -n "render.*wizard" app/views/tournaments/show.html.erb app/views/tournaments/_show.html.erb
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create reproduction recipe, screenshots directory, and findings file scaffold</name>
  <files>
    .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md
    .planning/phases/33-ux-review-wizard-audit/screenshots/.gitkeep
  </files>
  <read_first>
    - .planning/phases/33-ux-review-wizard-audit/33-CONTEXT.md (full — D-01 through D-13 all LOCKED)
    - .planning/REQUIREMENTS.md (UX-01..UX-04)
    - .planning/ROADMAP.md (Phase 33 success criteria)
    - app/views/tournaments/show.html.erb (confirm line ~35 render call)
    - app/controllers/tournaments_controller.rb (note action line numbers: new=428, create=436, edit=433, finish_seeding=107, start=288, transient check=415)
    - app/models/tournament.rb (note lines 276–295 for transient state context)
  </read_first>
  <action>
    Create `.planning/phases/33-ux-review-wizard-audit/screenshots/` directory with an empty `.gitkeep` file so the directory is committable.

    Create `.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md` with the following exact structure:

    1. H1 title: `# Phase 33 — UX Findings: Tournament Wizard Audit`

    2. Top matter: phase, date (2026-04-13), status "In progress — Plan 01 scaffold".

    3. H2 `## Reproduction recipe` — copy-pasteable shell and `rails console` snippet. Use an EXISTING dev-DB tournament (per D-02 Claude's discretion) by picking the most recent tournament with state `prepared` or earlier, or give the auditor the console snippet to query one:
       ```
       # Start dev server
       bin/rails server

       # In another shell, pick a reproduction tournament
       bin/rails runner 'puts Tournament.order(created_at: :desc).where(aasm_state: %w[prepared seeding_open new_tournament]).limit(5).pluck(:id, :title, :aasm_state)'

       # Record the chosen tournament here:
       # TOURNAMENT_ID=<fill_in_from_output>
       # AASM_STATE=<fill_in>
       # URL: http://localhost:3000/tournaments/<TOURNAMENT_ID>
       ```
       Note in prose that the auditor (Plan 02) must fill in the chosen TOURNAMENT_ID and AASM_STATE before driving the browser walkthrough, and must commit those values so Phase 34/36 can re-observe.

    4. H2 `## Canonical wizard partial — grep evidence (UX-01)` — literally embed the two grep commands from D-10 as fenced code blocks, run each via Bash, and paste the exact output below each command in a fenced block labeled "Output:". Do NOT summarize — preserve raw output for downstream re-verification. If `_wizard_steps.html.erb` or `_wizard_step.html.erb` appears in results, highlight each occurrence in a short prose note beneath the output (e.g., "Found in `app/views/tournaments/_wizard_steps.html.erb` — partial file itself; not a render call"). The goal: prove that `_wizard_steps_v2.html.erb` is the only partial rendered by `show.html.erb`.

    5. H2 `## Happy-path action audit` (parent section) followed by six empty H2 subsections in this order, each populated ONLY with the D-04 skeleton (Intent/Observed/Screenshot placeholders and an empty finding table with just the header row). Use literal placeholder text `_to be filled by Plan 02_` for Intent/Observed/Screenshot lines so Plan 02 knows exactly where to write:
       - `## new`
       - `## create`
       - `## edit`
       - `## finish_seeding`
       - `## start`
       - `## tournament_started_waiting_for_monitors`

       Each table has ONE empty header row and a single body row reading `| _TBD_ | _TBD_ | _to be filled by Plan 02_ | _TBD_ | _TBD_ |`. Do NOT assign finding IDs yet — Plan 03 assigns F-01..F-NN sequentially once all findings are gathered.

    6. H2 `## Non-happy-path actions (not reviewed)` — placeholder reading `_to be filled by Plan 03 per D-07_`. Do not list actions yet.

    7. H2 `## Tier classification key` — copy the D-11 rules verbatim (Tier 1 = view/copy/i18n/help text; Tier 2 = controller/route/service; Tier 3 = AASM state machine; ambiguous → higher tier) and the D-12 gating rule (Tier 3 = `blocked-needs-test-plan`).

    Use the Write tool, not heredoc. Do NOT populate any findings, intent prose, observed behavior, or screenshot paths — Plan 02 owns that.

    For the grep evidence step, use the Bash tool to run each grep exactly as written in D-10 and paste raw output. If grep returns no matches, record the command and note "No matches" explicitly.
  </action>
  <verify>
    <automated>test -f .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md && test -d .planning/phases/33-ux-review-wizard-audit/screenshots && grep -q "Reproduction recipe" .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md && grep -q 'grep -rn "wizard_steps' .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md && grep -q "## new" .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md && grep -q "## tournament_started_waiting_for_monitors" .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md</automated>
  </verify>
  <acceptance_criteria>
    - File `.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md` exists
    - File contains literal string `Reproduction recipe`
    - File contains literal string `grep -rn "wizard_steps` (the D-10 command embedded verbatim)
    - File contains literal string `grep -n "render.*wizard"` (the second D-10 command)
    - File contains all six happy-path H2 headers: `## new`, `## create`, `## edit`, `## finish_seeding`, `## start`, `## tournament_started_waiting_for_monitors`
    - File contains H2 `## Non-happy-path actions (not reviewed)`
    - File contains H2 `## Tier classification key`
    - File contains raw output of both D-10 grep commands (pasted output blocks below the command blocks)
    - Directory `.planning/phases/33-ux-review-wizard-audit/screenshots/` exists
    - No file under `app/`, `config/`, or `test/` was modified (git status clean outside `.planning/phases/33-ux-review-wizard-audit/`)
  </acceptance_criteria>
  <done>
    `33-UX-FINDINGS.md` exists as a scaffold with the reproduction recipe, verbatim grep evidence for UX-01, and empty H2 sections matching D-04's shape. `screenshots/` directory exists and is committable. No findings IDs assigned yet; no Intent/Observed prose written yet; no production files touched.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| N/A | Audit phase produces only planning artifacts; no production code, no new routes, no new data flows |

## STRIDE Threat Register

Audit phase: no production code modified, no new attack surface introduced. N/A.
</threat_model>

<verification>
- `33-UX-FINDINGS.md` exists with all required H2 scaffolding
- Grep evidence embedded literally per D-10 (both commands + raw output)
- `screenshots/` directory present
- No changes outside `.planning/phases/33-ux-review-wizard-audit/`
</verification>

<success_criteria>
Plan 01 complete when Plan 02 can open `33-UX-FINDINGS.md`, fill in the TOURNAMENT_ID in the reproduction recipe, and start writing Intent/Observed text under each pre-existing H2 section without having to create structure or hunt for canonical-partial proof.
</success_criteria>

<output>
After completion, create `.planning/phases/33-ux-review-wizard-audit/33-01-SUMMARY.md`
</output>
