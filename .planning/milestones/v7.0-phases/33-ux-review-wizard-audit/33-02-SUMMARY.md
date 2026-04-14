---
plan: 33-02-browser-walkthrough-and-screenshots
phase: 33-ux-review-wizard-audit
status: complete
completed: 2026-04-13
mode: checkpoint-plus-continuation
---

# Plan 33-02 Summary — Browser Walkthrough and Screenshots

## What was done

Executed the full human-driven browser walkthrough against `carambus_bcw` (LOCAL-context scenario, `context: LOCAL`, `local_server?` is true) running on `http://localhost:3007` via RubyMine. Target tournament: `17403 "NDM Freie Partie Klasse 1-3"` — a synced carom tournament (`id < 50_000_000`, discipline `Freie Partie klein`, date 2026-04-19, state `new_tournament`). This satisfies the three compounding constraints for a realistic audit target (global/synced, carom, upcoming-and-not-yet-played).

The walkthrough exercised the wizard from the Turnier-Setup overview through the final Tournament Monitor landing, covering: ClubCloud-Meldeliste, Setzliste-Übernehmen step, Teilnehmerliste bearbeiten (with manual player addition because ClubCloud only delivered 1 registration), Teilnehmerliste abschließen, Turniermodus-Auswahl, Start-Parameter-Formular, and the post-start Tournament Monitor. 11 screenshots were captured, including three substates that the original plan's 8-shot structure did not anticipate (compare seedings, add players, mode selection).

## Scope divergences from original plan

1. **`new` / `create` H2 sections not walked through.** Decision recorded in walkthrough log (Option A): these actions are not part of the realistic volunteer workflow on a synced tournament, and were documented as `missing-feature` findings instead. See F-TMP-01, F-TMP-02.

2. **Scenario re-targeted mid-execution.** The executor initially resolved the reproduction recipe against `carambus_api` (API context) — user flagged this as wrong because `LocalProtector` blocks tournament management writes on API servers. Recipe corrected to point at `carambus_bcw` (LOCAL). Further corrected to use a global/synced tournament rather than a local one (`id >= MIN_ID`) because the realistic volunteer case operates on synced records. Final correction: specific carom discipline with pre-built `TournamentPlan` code path, upcoming date. Each correction committed individually (`37d5f32e`, `b970d10e`, `6e9d9234`, `9a7f4f42`). Memory saved: `~/.claude/projects/.../memory/project_scenario_for_ux_testing.md`.

3. **Intermediate substates discovered.** The wizard exposes 4a (mode selection), 2a/2b/2c (compare-setzliste / add-players / added-players) that the original 6-step happy-path spec (`new`, `create`, `edit`, `finish_seeding`, `start`, `transient`) did not enumerate. These are recorded as screenshots under their parent H2 section but represent a structural gap in UX-04's action list that Phase 34 may need to revisit.

## Key findings (23 total, temporary IDs F-TMP-01..F-TMP-23)

- **F-TMP-03 (bug):** ClubCloud sync delivered only 1 player registration for 17403 despite several registrations presumably existing.
- **F-TMP-04 (ux):** Wizard shows misleading "Weiter zu Schritt 3 mit diesen 1 Spielern" CTA that frames the partial sync as complete.
- **F-TMP-07 (ux):** `tournament_plan_id` auto-suggest panel in the Teilnehmerliste step is excellent — clear recommendation based on participant count. Gold-standard pattern for the rest of the wizard.
- **F-TMP-09 (ux):** No confirmation dialog before the irreversible "Teilnehmerliste abschließen" AASM transition.
- **F-TMP-12 (ux):** "Abschließende Auswahl des Austragungsmodus" presents T04/T05/DefaultS alternatives with dense technical specs but no explanation of trade-offs.
- **F-TMP-14 (bug — severe):** Majority of start-form parameter labels are in English or mangled German-English mix ("Tournament manager checks results before acceptance", "Gd hat prio ein inter-group comparisons", "Der arbeit wechselt zwischen den sätzen", "Bälle einsam nach dritt", etc.). Contradicts the v7.0 volunteer-friendly goal. i18n regression in `de.yml`.
- **F-TMP-19 (bug — UX-02 LOAD-BEARING):** `tournament_started_waiting_for_monitors` passes invisibly for several seconds with no UI feedback. No spinner, no loading message, no intermediate screen. The volunteer sees nothing happen and may double-click or back-navigate, risking a half-started AASM state. **This is the definitive answer to Phase 33 success criterion #2**: the transient state is invisible from the volunteer's perspective.

## Files modified

- `.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md` — all 6 H2 sections filled with Observed prose + Screenshot references + 23 temporary F-TMP finding rows (Tier / Gate pending Plan 33-03 classification)
- `.planning/phases/33-ux-review-wizard-audit/screenshots/` — 11 PNGs (01, 02, 02a, 02b, 02c, 03, 04, 04a, 05, 06, 07)

No production code (`app/`, `config/`, `test/`) was touched. Phase 33 remains an audit-only phase.

## Key commits

- `54ab7911` — autonomous prep: reproduction recipe resolved, Intent prose from controller source
- `37d5f32e` — recipe correction #1: carambus_api → carambus_bcw (LOCAL context)
- `b970d10e` — recipe correction #2: local → global/synced tournament
- `6e9d9234` — recipe correction #3: narrow to upcoming carom tournament 17403
- `9a7f4f42` — recipe correction #4: RubyMine dev server on port 3007
- `2d6bef74` — walkthrough observations + 11 screenshots + Observed prose in all 6 sections

## Handoff to Plan 33-03

Plan 33-03 must:

1. Renumber F-TMP-01..F-TMP-23 sequentially as F-01..F-23 (per D-05)
2. Classify each finding by Tier 1/2/3 per D-11 (mechanical, highest-layer-touched rule)
3. Apply Gate values per D-08/D-12: `open` default, `blocked-needs-test-plan` for all Tier 3 rows
4. Add the retirement finding for non-canonical wizard partials (`_wizard_steps.html.erb`, `_wizard_step.html.erb`) per D-09 — Tier 1, open gate, references Phase 36 for execution
5. Populate the Non-happy-path actions section per D-07 — listing action names only
6. Run the Plan 03 mechanical sanity scans (finding-ID uniqueness, Tier 3 → gate invariant)

## Self-Check

- [x] 11 screenshots committed under `screenshots/` matching the D-03 `NN-<action>-<substate>.png` naming convention
- [x] All 6 H2 sections have concrete `Observed:` prose grounded in both browser observation and controller source
- [x] 23 finding rows with temporary IDs, `Type` values (`ux | bug | missing-feature`), and placeholder `?` for Tier/Gate
- [x] UX-02 (transient state visibility) explicitly answered: invisible
- [x] UX-01 (canonical partial) evidence retained from Plan 33-01's scaffold (`## Canonical wizard partial — grep evidence`)
- [x] No files outside `.planning/phases/33-ux-review-wizard-audit/` modified
- [x] Walkthrough decision log (Option A for new/create, Option B for scenario correction) captured in commit history
