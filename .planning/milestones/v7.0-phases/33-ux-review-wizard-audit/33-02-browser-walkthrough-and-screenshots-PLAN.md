---
phase: 33
plan: 02
type: execute
wave: 2
depends_on:
  - 33-01
files_modified:
  - .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md
  - .planning/phases/33-ux-review-wizard-audit/screenshots/
autonomous: false
requirements:
  - UX-02
  - UX-04
must_haves:
  truths:
    - "A volunteer can see, from the findings file, exactly what each of the 5 happy-path actions (new, create, edit, finish_seeding, start) shows on screen and what the volunteer is trying to accomplish"
    - "The transient tournament_started_waiting_for_monitors state has been observed in a running browser and the observation is documented: either 'surfaces visible UI X' or 'passes invisibly, state lasts N seconds, user sees Y'"
    - "Each happy-path H2 section has an Intent line, an Observed line, and a Screenshot reference pointing to a file that actually exists in screenshots/"
    - "Between 6 and 10 PNG files exist in screenshots/ per D-03"
  artifacts:
    - path: ".planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md"
      provides: "Observation data (Intent/Observed/Screenshot) filled into each H2 + raw finding rows (without final IDs)"
    - path: ".planning/phases/33-ux-review-wizard-audit/screenshots/"
      provides: "6–10 PNG screenshots named NN-<action>-<substate>.png"
      contains: "01-new-"
  key_links:
    - from: "33-UX-FINDINGS.md each H2 Screenshot line"
      to: "screenshots/NN-<action>-<substate>.png"
      via: "relative path reference"
      pattern: "screenshots/\\d\\d-"
    - from: "## tournament_started_waiting_for_monitors H2"
      to: "app/models/tournament.rb:276 and tournaments_controller.rb:415"
      via: "Observed line explicitly states visible-or-invisible + duration"
      pattern: "Observed:"
---

<objective>
Drive the full happy-path walkthrough (`new` → `create` → `edit` → `finish_seeding` → `start`) in a real browser against the dev server, capture 6–10 screenshots per D-03, cross-read each action's controller source, and fill Intent/Observed prose plus raw finding rows into the H2 sections scaffolded by Plan 01. Specifically observe whether `tournament_started_waiting_for_monitors` surfaces any visible UI (UX-02).

Purpose: UX-02 and UX-04 can only be answered by actually clicking through the wizard and writing down what a volunteer sees. The browser walkthrough is the load-bearing empirical step of the entire phase.

Output: `33-UX-FINDINGS.md` with Intent/Observed prose and raw finding rows under every H2; `screenshots/` populated with 6–10 named PNGs.
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
<!-- Key source locations to cross-read while observing. Executor should open these
     and the browser side-by-side per D-01. -->

## TournamentsController happy-path action line numbers (from CONTEXT.md canonical_refs)
- `app/controllers/tournaments_controller.rb:428` — `new`
- `app/controllers/tournaments_controller.rb:436` — `create`
- `app/controllers/tournaments_controller.rb:433` — `edit`
- `app/controllers/tournaments_controller.rb:107` — `finish_seeding`
- `app/controllers/tournaments_controller.rb:288` — `start`
- `app/controllers/tournaments_controller.rb:415` — transient-state check for `tournament_started_waiting_for_monitors`

## AASM transient state
- `app/models/tournament.rb:276..295` — definition of `tournament_started_waiting_for_monitors` and its transitions. UX-02 requires observing whether this state surfaces visible UI or passes invisibly.

## Canonical wizard partial (proven in Plan 01)
- `app/views/tournaments/_wizard_steps_v2.html.erb` — rendered by `show.html.erb` line ~35
- `app/views/tournaments/show.html.erb` — tournament detail page the walkthrough spends most of its time on

## Screenshot naming convention (D-03)
`NN-<action>-<substate>.png`, examples:
- `01-new-empty-form.png`
- `02-create-after-submit.png`
- `03-edit-wizard-step-N.png`
- `04-finish_seeding-before.png`
- `05-finish_seeding-after.png`
- `06-start-form.png`
- `07-start-transient-state.png`  ← UX-02 critical
- `08-start-after-monitors-ready.png`
</interfaces>
</context>

<tasks>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 1: Browser walkthrough of the happy path (5 actions + transient state)</name>
  <files>
    .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md
    .planning/phases/33-ux-review-wizard-audit/screenshots/
  </files>
  <read_first>
    - .planning/phases/33-ux-review-wizard-audit/33-CONTEXT.md (D-01, D-02, D-03 observation method)
    - .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md (reproduction recipe written by Plan 01)
    - app/views/tournaments/show.html.erb
    - app/views/tournaments/_wizard_steps_v2.html.erb
    - app/controllers/tournaments_controller.rb (focus on lines 107, 288, 415, 428, 433, 436)
    - app/models/tournament.rb (focus on lines 276..295 — transient state definition)
  </read_first>
  <what-built>
    Plan 01 produced a findings file with a reproduction recipe placeholder and empty H2 sections. Nothing is built yet — this is the pure observation step.
  </what-built>
  <action>
    This is a human-driven checkpoint task. The executor (Claude) coordinates and the user drives the browser. If the executor has no local browser access, pause and ask the user to drive steps 2–6 while the executor fills in the findings file from the user's notes.

    **Step 1 — Open the findings file.** Read `.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md` and locate the Reproduction recipe H2 written by Plan 01.

    **Step 2 — Start the dev server.** `foreman start -f Procfile.dev` (or `bin/rails server` if foreman unavailable).

    **Step 3 — Pick a reproduction tournament.** Run:
    ```
    bin/rails runner 'puts Tournament.order(created_at: :desc).where(aasm_state: %w[prepared seeding_open new_tournament]).limit(5).pluck(:id, :title, :aasm_state)'
    ```
    Pick the most workable tournament from the output. If none exists, pick the latest tournament in any pre-start state and note its actual aasm_state. Edit the Reproduction recipe in `33-UX-FINDINGS.md` to replace the TOURNAMENT_ID, title, and AASM state placeholders with concrete values. Commit the values so Phase 34/36 can re-observe.

    **Step 4 — Drive the happy path in a real browser.** Chrome or Safari, no headless. For each action: cross-read the controller source (line numbers listed in `<interfaces>` above) BEFORE clicking so Intent is grounded in controller purpose and Observed is grounded in what the UI actually did.
    - **new** — visit `/tournaments/new`. Screenshot: `screenshots/01-new-empty-form.png`. Note which fields are required vs optional, any help text visible, any surprising defaults.
    - **create** — fill minimum required fields, submit. Screenshot the resulting show page: `screenshots/02-create-after-submit.png`. Note which wizard step is highlighted, what error or success feedback appears.
    - **edit** — from the show page, trigger edit (either the edit link or the wizard step's edit affordance). Screenshot the edit form: `screenshots/03-edit-wizard-step.png`. Note how edit differs from create visually.
    - **finish_seeding** — navigate the chosen tournament to a state where "Setzliste abschließen" (finish_seeding) is clickable. May require first adding participants; if the reproduction tournament is already past seeding, use a different tournament or use `rails console` to add a test participant interactively. Screenshot BEFORE clicking: `screenshots/04-finish_seeding-before.png`. Click the action. Screenshot AFTER: `screenshots/05-finish_seeding-after.png`. Note: is there a confirmation dialog? Does the UI tell the volunteer what just happened? Is the wizard step now visually "done"?
    - **start** — navigate to the start form. Screenshot: `screenshots/06-start-form.png`. Click start. Immediately try to screenshot the transient state: `screenshots/07-start-transient-state.png` — **CRITICAL for UX-02**: does any visible UI surface during `tournament_started_waiting_for_monitors`? A loading spinner? A specific message? Or does the page just refresh and show the monitor-ready state? Measure duration (rough seconds) of the transient state. Then screenshot the final state: `screenshots/08-start-after-monitors-ready.png`.

    **Step 5 — Handle the transient state honestly.** If `tournament_started_waiting_for_monitors` passes too fast to screenshot, document that explicitly — that IS the UX-02 answer (e.g., "passes invisibly in < 1s, no user-visible UI"). Silence is not an acceptable answer.

    **Step 6 — Manage screenshot count.** Target 6–10 PNGs total. Prune duplicates or add substates as needed to stay in range.

    **Step 7 — Fill the findings file.** For each action, write the following into the corresponding H2 section of `33-UX-FINDINGS.md` (replace the `_to be filled by Plan 02_` placeholders):
    - **Intent:** one sentence from the volunteer's perspective — what they are trying to accomplish by using this action (derive from controller action purpose + wizard step label, not from code comments).
    - **Observed:** one to three sentences of what the UI actually showed. Include surprises, missing feedback, confusing labels, untranslated strings, anything friction-like.
    - **Screenshot:** the literal filename under `screenshots/` (e.g., `screenshots/04-finish_seeding-before.png`).

    **Step 8 — Record raw findings.** For each friction point or discrepancy observed, add a row to that section's finding table. Use temporary IDs `F-TMP-NN` for the ID column — Plan 03 will renumber to stable F-NN. Columns: `ID | Type | Finding | Tier | Gate`. Type is one of `ux | bug | missing-feature` per D-06. Leave Tier as `?` and Gate as `?` — Plan 03 classifies per D-11/D-12. Findings should read like diff entries per the CONTEXT specifics (e.g., "no confirmation dialog before Setzliste abschließen" not "UX issue on seeding step").

    **Step 9 — Transient state section specifically.** Even if no visible UI surfaces — write Intent ("the system is waiting for table monitor connections before the tournament is fully live"), Observed (concrete: "page refreshes once, no intermediate message shown" OR "spinner with text 'Warte auf Monitore' visible for ~2s" — whatever actually happens), Screenshot reference, and at minimum one finding row capturing whether the volunteer has any way to know the tournament is in a transitional state.

    **Step 10 — Stop the dev server when done.**

    **Do NOT** modify any file under `app/`, `config/`, `test/`, or anywhere outside `.planning/phases/33-ux-review-wizard-audit/`. This is an observation task — the only writes are to the findings file and the screenshots directory. If the reproduction tournament needs data fixes (e.g., adding a participant), use `rails console` interactively — do not write migration or seed code.
  </action>
  <how-to-verify>
    After the walkthrough is complete, verify manually:
    1. Open `33-UX-FINDINGS.md` — confirm every happy-path H2 (new, create, edit, finish_seeding, start) plus `## tournament_started_waiting_for_monitors` has Intent + Observed + Screenshot lines that are not placeholders.
    2. `ls .planning/phases/33-ux-review-wizard-audit/screenshots/*.png | wc -l` reports between 6 and 10.
    3. Each Observed line for the transient state H2 explicitly states visible UI OR explicit invisibility (no blank answer).
    4. Reproduction recipe at top of file has concrete TOURNAMENT_ID, title, and AASM state — no `<fill_in>` remaining.
    5. `git status` shows no modifications outside `.planning/phases/33-ux-review-wizard-audit/`.
  </how-to-verify>
  <verify>
    <automated>test $(ls .planning/phases/33-ux-review-wizard-audit/screenshots/*.png 2>/dev/null | wc -l) -ge 6 && test $(ls .planning/phases/33-ux-review-wizard-audit/screenshots/*.png 2>/dev/null | wc -l) -le 10 && ! grep -q "_to be filled by Plan 02_" .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md && grep -q "tournament_started_waiting_for_monitors" .planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md</automated>
  </verify>
  <resume-signal>
    Type "approved" once all happy-path sections and the transient-state section in `33-UX-FINDINGS.md` are filled with Intent/Observed/Screenshot + at least one finding row each, and 6–10 PNGs are committed under `screenshots/`. If the transient state truly surfaced no UI, confirm that observation is documented explicitly (the absence is the finding, not a blank section).
  </resume-signal>
  <acceptance_criteria>
    - `ls .planning/phases/33-ux-review-wizard-audit/screenshots/*.png 2>/dev/null | wc -l` returns a number between 6 and 10 inclusive
    - Every screenshot filename matches the pattern `^\d\d-.*\.png$`
    - `33-UX-FINDINGS.md` no longer contains the literal string `_to be filled by Plan 02_` under any happy-path or transient-state H2
    - Each H2 section (`## new`, `## create`, `## edit`, `## finish_seeding`, `## start`, `## tournament_started_waiting_for_monitors`) contains an `**Intent:**` line, an `**Observed:**` line, and a `**Screenshot:**` line pointing to a file that exists in `screenshots/`
    - Each H2 section's finding table contains at least one row that is NOT the `_TBD_` placeholder row from Plan 01
    - The Reproduction recipe in `33-UX-FINDINGS.md` has the TOURNAMENT_ID, title, and AASM state filled in (no unfilled `<fill_in>` placeholders remain)
    - `git status` shows no modifications outside `.planning/phases/33-ux-review-wizard-audit/`
    - The `## tournament_started_waiting_for_monitors` section's Observed line explicitly states either what the volunteer sees OR that nothing is visible (must not be silent — UX-02 requires a concrete answer)
  </acceptance_criteria>
  <done>
    Every happy-path H2 plus the transient-state H2 in `33-UX-FINDINGS.md` has concrete Intent/Observed/Screenshot and at least one raw finding row. 6–10 PNGs exist under `screenshots/`. UX-02's central question is answered in prose. Reproduction recipe is no longer a template — it names an actual tournament record.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| N/A | Observation-only plan; no code modified, no new data flows, no new routes |

## STRIDE Threat Register

Audit phase: no production code modified, no new attack surface introduced. N/A.
</threat_model>

<verification>
- Between 6 and 10 PNGs in `screenshots/`
- Every happy-path H2 + transient-state H2 has Intent/Observed/Screenshot filled
- Reproduction recipe has concrete tournament id
- Transient-state observation is concrete (visible UI described OR invisibility explicitly stated)
- No changes outside `.planning/phases/33-ux-review-wizard-audit/`
</verification>

<success_criteria>
Plan 02 complete when Plan 03 can open `33-UX-FINDINGS.md`, read the Intent/Observed text under each H2, and produce a tier-classified finding list without having to re-run the browser walkthrough or re-check the source.
</success_criteria>

<output>
After completion, create `.planning/phases/33-ux-review-wizard-audit/33-02-SUMMARY.md`
</output>
