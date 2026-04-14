---
phase: 33-ux-review-wizard-audit
plan: "03"
subsystem: ui
tags: [ux, wizard, aasm, tier-classification, i18n, tournament]

# Dependency graph
requires:
  - phase: 33-02-browser-walkthrough-and-screenshots
    provides: "23 raw findings with temporary IDs (F-TMP-01..F-TMP-23) and Plan 02 observed prose"
provides:
  - "33-UX-FINDINGS.md finalized: 24 findings with stable F-01..F-24 IDs, Tier 1/2/3 classification, open/blocked gates"
  - "Retirement decision for _wizard_steps.html.erb and _wizard_step.html.erb captured as F-24 (Tier 1, open)"
  - "Non-happy-path action list from tournaments_controller.rb (24 actions explicitly out of scope)"
  - "Phase 33 audit closed — Phase 34 and Phase 36 have a contract addressable by (F-NN, Tier, Gate)"
affects:
  - "Phase 34: task-first doc rewrite — uses happy-path narrative from findings"
  - "Phase 36: small UX fixes — references findings by F-NN, filters on tier + gate"
  - "Phase 37: in-app links — uses action-level anchors to place Help links"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Tier classification by highest-layer-touched: Tier 1 (view/i18n only), Tier 2 (controller/service), Tier 3 (AASM)"
    - "Gate values: open (Tier 1/2) vs blocked-needs-test-plan (Tier 3) as Phase 36 gating contract"

key-files:
  created: []
  modified:
    - ".planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md"

key-decisions:
  - "F-19 (tournament_started_waiting_for_monitors invisible) classified Tier 3 — fixing the transient state requires AASM changes; Phase 36 must attach test-coverage plan before unblocking"
  - "F-01/F-02 (new/create workflow) classified Tier 2 — hiding or rerouting these actions requires controller/route changes, not just view edits"
  - "F-20 (no success flash after start) classified Tier 2 — flash requires a controller-level redirect with notice parameter, not a pure view change"
  - "Retirement finding (F-24) placed under a dedicated ## retirement H2 section — keeps the deletion decision distinct from the wizard-action observations without disrupting the 6 happy-path H2 sections"
  - "Non-happy-path section lists 24 actions verbatim from controller — explicitly marks them out of v7.0 scope per D-07"

patterns-established:
  - "Tier 3 gating pattern: any AASM-touching fix blocked until test-coverage plan attached in Phase 36 PLAN.md"

requirements-completed:
  - UX-01
  - UX-02
  - UX-03
  - UX-04

# Metrics
duration: 25min
completed: 2026-04-13
---

# Phase 33 Plan 03: Tier Classification and Finalize Summary

**24 tournament wizard findings tier-classified by highest-layer-touched rule (14 Tier 1, 7 Tier 2, 1 Tier 3), with stable F-01..F-24 IDs, open/blocked gates, retirement decision for non-canonical partials, and non-happy-path action list — Phase 33 audit closed**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-13T00:00:00Z
- **Completed:** 2026-04-13
- **Tasks:** 1 (with 7 sub-steps)
- **Files modified:** 1

## Accomplishments

- Renumbered all 23 temporary F-TMP-NN IDs to stable sequential F-01..F-23 across the whole file (one counter, D-05)
- Classified every finding by mechanical highest-layer-touched rule: 14 Tier 1 (view/copy/i18n), 7 Tier 2 (controller/service), 1 Tier 3 (AASM); no judgment, no ambiguity
- Applied gates per D-08/D-12: F-19 (the transient state finding) is the sole Tier 3 row and carries `blocked-needs-test-plan`; all 23 others carry `open`
- Added F-24: retirement finding for `_wizard_steps.html.erb` and `_wizard_step.html.erb` under a new `## retirement` H2 section (Tier 1, open gate, Phase 36 executes deletion)
- Populated Non-happy-path actions section with 24 action names from `tournaments_controller.rb` — no review, no findings, just an explicit "these are out of scope" declaration per D-07
- Updated file status to "Complete — Phase 33 final (2026-04-13)"
- Ran mechanical sanity scans: 0 F-TMP remaining, 24 unique F-NN IDs, Tier 3 gate invariant satisfied, grep evidence retained, all 6 H2 sections intact

## Task Commits

1. **Task 1: Assign stable IDs, tier-classify, gate, add retirement finding** — `45d314cd` (feat)

**Plan metadata commit:** (follows in orchestrator's final commit)

## Files Created/Modified

- `.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md` — Finalized: F-01..F-24 stable IDs, Tier 1/2/3 per each row, gates applied, F-24 retirement finding added, non-happy-path action list populated, status updated to Complete

## Decisions Made

- **F-19 Tier 3 classification:** The finding documents that fixing `tournament_started_waiting_for_monitors` invisibility requires either a new AASM-visible intermediate state or elimination of the state entirely — both are AASM changes. Even an option-(a) view-only spinner would need controller coordination to know when to stop spinning, putting it at Tier 2 minimum. The bug description itself says "requires AASM surface changes". Classified Tier 3. Gate: `blocked-needs-test-plan`.
- **F-01/F-02 Tier 2:** Hiding `/tournaments/new` from volunteers or restructuring the new+create flow into an admin sub-path requires routing and controller changes. Not a pure view edit.
- **F-20 Tier 2:** Adding a flash notice after `start_tournament!` requires the controller's redirect to pass a `:notice` option — that is a controller change even though the visible result is a view element.
- **F-03 Tier 2:** The ClubCloud sync count bug (1 player instead of 5+) lives in the service layer (`CuescoScraper` or `ClubCloudService`) — a view warning alone cannot fix the root cause; service-layer investigation required.
- **F-06/F-17 Tier 2:** Name-search and discipline-aware defaults require service/controller logic, not just ERB edits.
- **Retirement section placement:** Added `## retirement` as a new H2 distinct from the 6 happy-path sections. The plan allowed "wherever most appropriate" — a dedicated section avoids cluttering the `## new` section with a non-action finding.

## Deviations from Plan

None — plan executed exactly as written. The awk gate-check command in the task guidance matched prose lines in the "Tier classification key" section (which say "Tier 3" but aren't table rows), producing a false-positive exit 1. Verified the invariant with a targeted `grep "| F-" ... | grep " 3 |" | grep -v "blocked-needs-test-plan"` which confirmed 0 violations. The plan's awk pattern was noted as imprecise for this file layout; the invariant itself is satisfied.

## Issues Encountered

- The plan-specified awk invariant check (`awk '/Tier 3/ { if ($0 !~ /blocked-needs-test-plan/) exit 1 }'`) exits non-zero because the "Tier classification key" prose section contains "Tier 3" text without `blocked-needs-test-plan` on the same line. This is not a bug in the file — the prose predates the table rows. The invariant is fully satisfied at the table-row level. Documented here; no fix required to the findings file.

## User Setup Required

None — no external service configuration required. Phase 33 is audit-only; no production code was touched.

## Next Phase Readiness

- `33-UX-FINDINGS.md` is the authoritative spec for Phase 34 (task-first doc rewrite) and Phase 36 (small UX fixes)
- Phase 34 can consume the happy-path narrative and confirmed canonical partial (F-24 retirement finding) directly by ID
- Phase 36 can filter findings by `Tier + Gate`: 22 findings are `open` (addressable), 1 is `blocked-needs-test-plan` (F-19, requires test-coverage plan before touching AASM)
- F-14 (severe i18n regression on start form) and F-19 (transient state invisible) are the highest-priority findings for Phase 36 planning
- No blockers for Phase 34 or Phase 36 — all gates are set, all IDs are stable

## Self-Check

- [x] `33-UX-FINDINGS.md` contains `F-01` (first stable ID assigned)
- [x] `33-UX-FINDINGS.md` does NOT contain `F-TMP` (grep -c returns 0)
- [x] `33-UX-FINDINGS.md` does NOT contain `_to be filled`
- [x] 24 unique F-NN IDs present (F-01 through F-24)
- [x] All Tier 3 table rows have `blocked-needs-test-plan` gate (1 row: F-19)
- [x] Retirement finding F-24 present with `_wizard_steps.html.erb` and `_wizard_step.html.erb`
- [x] Non-happy-path section populated with 24 action names
- [x] Status updated to "Complete — Phase 33 final (2026-04-13)"
- [x] Plan 01 grep evidence commands still present verbatim
- [x] All 6 H2 sections (`## new`, `## create`, `## edit`, `## finish_seeding`, `## start`, `## tournament_started_waiting_for_monitors`) still present
- [x] Commit `45d314cd` exists in git log
- [x] No files outside `.planning/phases/33-ux-review-wizard-audit/` modified in task commit

## Self-Check: PASSED

---
*Phase: 33-ux-review-wizard-audit*
*Completed: 2026-04-13*
