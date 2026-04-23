---
phase: 260423-qvm-admin-show-page-500-fix
verified: 2026-04-22T00:00:00Z
status: human_needed
score: 10/10 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Visual plausibility of ball coordinates on /admin/training_examples/15 (Gabriëls, klein/exact) and /admin/training_examples/16 (Conti Coup 10, match/qualitative)"
    expected: "Ball positions sit inside the table rectangle and visually match a plausible Gretillat / Conti layout"
    why_human: "Pixel-level seed-coordinate QA is Claudia's lane (ontology seeds), not code scope. Gernot reported 'positions off' during UAT — this is EXPECTED and NOT a gap for this task. Flagged here for completeness."
---

# Quick Task 260423-qvm: Admin Show-page 500 fix Verification Report

**Task Goal:** Admin Show-page 500 fix (Administrate 0.19 × Rails 7.1+ deprecator incompat) + P1 controller M2M cleanup + P2 admin smoke tests
**Verified:** 2026-04-22
**Status:** human_needed (seed-coordinate UAT only; code scope fully PASSED)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Must-Haves Contract)

| # | Must-Have | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Commit A shim exists and makes `ActiveSupport::Deprecation.warn` public at class level | VERIFIED | `config/initializers/administrate_rails71_shim.rb` exists, starts with `# frozen_string_literal: true`, contains `class << ActiveSupport::Deprecation / public :warn`, gated by `respond_to?(:warn, true/false)` double-check |
| 2 | `/admin/training_examples/15` and `/admin/training_examples/16` return HTTP 200 | VERIFIED | Live curl against dev server (port 3008): both returned `200`. Dev server shim is loaded (no 500 regression) |
| 3 | `Admin::TrainingExamplesController` has NO `move_up` or `move_down` methods | VERIFIED | `grep -nE "def move_up\|def move_down" app/controllers/admin/training_examples_controller.rb` → no match (exit 1). Full file Read confirms: only `requested_resource`, `valid_action?`, `new`, `update`, `destroy`, `set_training_concept`, `scoped_resource`, `resource_params` |
| 4 | `config/routes.rb` has NO `move_up`/`move_down` on admin training_examples (but DOES on shots) | VERIFIED | `bin/rails routes \| grep -c "move_(up\|down)_admin_training_example"` → 0. `bin/rails routes \| grep -c "move_(up\|down)_admin_shot"` → 2. Lines 478-494 show `resources :training_examples` has NO member block; nested `resources :shots` (lines 479-487) and standalone `resources :shots` (lines 491-496) both retain their `patch :move_up / patch :move_down` |
| 5 | `app/views/admin/training_concepts/show.html.erb` has NO refs to removed helpers | VERIFIED | `grep -rn "move_up_admin_training_example\|move_down_admin_training_example" app/views/ app/helpers/` → empty (exit 1). File Read: Sortierung column dropped entirely (Strategy A), table collapsed 6→5 cols, row iterates M2M via `training_concept_examples` sorted by `sequence_number` |
| 6 | `test/integration/admin_views_smoke_test.rb` exists and passes | VERIFIED | File exists (33 LOC), defines 4 dashboards × {Index, Show} = 8 tests. Ran: `bin/rails test test/integration/admin_views_smoke_test.rb` → `8 runs, 15 assertions, 0 failures, 0 errors, 3 skips` (Show tests skip when test-DB has no seed rows — documented in plan and SUMMARY) |
| 7 | Full suite: 0 failures, 0 errors (baseline 1282 → expected ~1290) | VERIFIED | `RAILS_ENV=test bin/rails test` → `1290 runs, 2898 assertions, 0 failures, 0 errors, 16 skips`. Delta: +8 runs, +15 assertions, +3 skips. Exactly matches SUMMARY's quoted numbers |
| 8 | SUMMARY.md accurately reflects actual commit SHAs | VERIFIED | `git log --format='%H %s' -n 7` matches SUMMARY table 1:1: `adae812f` (A) / `c2cf86f3` (inter-fix 1) / `ce3f0892` (inter-fix 2) / `5e9849f0` (B) / `96d5f1b5` (C). Commit subjects match SUMMARY verbatim |
| 9 | Pre-existing `/admin/shots` Index fix (Rule-2 deviation) is real and justified | VERIFIED | `app/controllers/admin/shots_controller.rb` has `def existing_action?(resource, action_name)` at line 27 plus `requested_resource` override at line 6, mirroring TrainingExamplesController pattern. Fix lives in commit `96d5f1b5` (same as Commit C). Curl `/admin/shots` → 200 OK. Scope justification documented in SUMMARY under "Rule 2" section |
| 10 | SVG ball-configuration partial actually renders on both Show pages | VERIFIED | `curl -s /admin/training_examples/15 \| grep -c "<svg "` → 3. Same for /16 → 3. Header `🎱 Ball-Konfigurationen` present. Labels `Tisch:` / `Position-Typ:` found 4× (start + shot-end captions) |

**Score:** 10/10 must-haves verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `config/initializers/administrate_rails71_shim.rb` | `public :warn` shim gated by respond_to check | VERIFIED | 47 LOC; frozen_string_literal header; `class << ActiveSupport::Deprecation / public :warn` inside `Rails.application.config.after_initialize` block; gate `respond_to?(:warn, true) && !respond_to?(:warn, false)` ensures no-op when upstream fixed |
| `app/controllers/admin/training_examples_controller.rb` | Cleaned controller without move_up/move_down/training_concept_id FK | VERIFIED | 96 LOC; no `def move_up` / `def move_down`; `destroy` redirects to `admin_training_examples_path`; `valid_action?` no longer allow-lists move actions; `scoped_resource` / `set_training_concept` / `resource_params` (incl. `tag_list`) preserved as planned |
| `app/views/admin/training_concepts/show.html.erb` | No button_to refs to removed helpers | VERIFIED | 160 LOC; Sortierung column dropped entirely (Strategy A). Header has 5 columns (`#`, Titel, Sprache, Übersetzt, Aktionen). Row data iterates `tces = page.resource.training_concept_examples.includes(:training_example).sort_by { |t| t.sequence_number || Float::INFINITY }` — M2M-aware |
| `config/routes.rb` | training_examples without move member actions | VERIFIED | Block `resources :training_examples, shallow: true do / resources :shots, ... end / end` (lines 478-488) has NO member block on the outer resource. Standalone `resources :training_examples, only: [:index]` on line 489 collapsed to one line (no trailing `do ... end`) |
| `test/integration/admin_views_smoke_test.rb` | Index+Show smoke for 4 routed dashboards | VERIFIED | 33 LOC; `DASHBOARDS = %i[training_examples training_concepts shots training_sources].freeze`; dynamic test generation creates 8 tests; asserts `:success` + absence of `"We're sorry, but something went wrong"`; Show-variant skips gracefully when no record present |
| `app/dashboards/ball_configuration_dashboard.rb` | Inserted-fix dashboard stub (ce3f0892) | VERIFIED | 91 LOC; defines `ATTRIBUTE_TYPES`, `COLLECTION_ATTRIBUTES`, `SHOW_PAGE_ATTRIBUTES`, `FORM_ATTRIBUTES`, and `display_resource`. Documented as "class resolution only — no admin route wired intentionally." Matches SUMMARY claim under Rule-3 inter-commit deviation |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| Admin show.html.erb `render_field(HasMany)` | Public visibility on `ActiveSupport::Deprecation.warn` | `config/initializers/administrate_rails71_shim.rb` | WIRED | Shim runs in `after_initialize`, opens singleton class, calls `public :warn`. Live curl on HasMany-rendering Show pages (examples 15/16) returns 200, proving the path is unblocked |
| Admin TrainingExamples Index navigation | Admin destroy redirects to Index (not Parent Concept) | `admin/training_examples_controller.rb#destroy` | WIRED | Line 64: `redirect_to admin_training_examples_path, notice: "Trainingsbeispiel wurde erfolgreich gelöscht."` — no lookup of `training_concept_id` |
| Admin TrainingConcepts Show Sortierung column | Removal of `move_up_admin_training_example_path` / `move_down_admin_training_example_path` helpers | `admin/training_concepts/show.html.erb` | WIRED | Strategy A applied: column and both button_to blocks removed. Grep gate empty. Curl `/admin/training_concepts/6` returns 200 (regression probe passes) |
| Admin Shots Index partial | Guard against `new_admin_shot_path` (which does not exist on standalone-mount) | `admin/shots_controller.rb#existing_action?` | WIRED | Line 27 `existing_action?` override mirrors TrainingExamplesController pattern; `helper_method :existing_action?` on line 31 exposes it to view. Curl `/admin/shots` → 200 (previously 500) |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `training_concepts/show.html.erb` (Trainingsbeispiele table) | `tces` | `page.resource.training_concept_examples.includes(:training_example).to_a.sort_by(&:sequence_number)` | Yes — reads from dev DB via AR association | FLOWING |
| `training_examples/show.html.erb` (SVG Ball-Konfigurationen section) | `start_position` + `shots` iteration | `BallConfiguration` records associated via model — rendered by `admin/shared/_ball_configuration_diagram.html.erb` partial | Yes — 3 `<svg>` tags present in actual HTTP response body for both examples | FLOWING |
| `AdminViewsSmokeTest` | `record` | `klass.order(:id).first` (live test-DB lookup per dashboard) | Depends on fixtures — training_examples/concepts/shots have no fixtures so Show skips (intentional, documented) | FLOWING-with-skip (truthful) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Admin TrainingExample Show #15 returns 200 | `curl -s -o /dev/null -w "%{http_code}" http://localhost:3008/admin/training_examples/15` | `200` | PASS |
| Admin TrainingExample Show #16 returns 200 | `curl -s -o /dev/null -w "%{http_code}" http://localhost:3008/admin/training_examples/16` | `200` | PASS |
| SVG partial renders on Show #15 | `curl -s http://localhost:3008/admin/training_examples/15 \| grep -c "<svg "` | `3` | PASS |
| SVG partial renders on Show #16 | `curl -s http://localhost:3008/admin/training_examples/16 \| grep -c "<svg "` | `3` | PASS |
| Labels `Tisch:` / `Position-Typ:` present on Show #15 | `curl -s http://localhost:3008/admin/training_examples/15 \| grep -cE "Tisch:\|Position-Typ:"` | `4` | PASS |
| Admin TrainingConcepts Index returns 200 (regression probe) | `curl -s -o /dev/null -w "%{http_code}" http://localhost:3008/admin/training_concepts` | `200` | PASS |
| Admin TrainingConcept #6 Show returns 200 (post-column-removal regression probe) | `curl -s -o /dev/null -w "%{http_code}" http://localhost:3008/admin/training_concepts/6` | `200` | PASS |
| Admin Shots Index returns 200 (Rule-2 fix verification) | `curl -s -o /dev/null -w "%{http_code}" http://localhost:3008/admin/shots` | `200` | PASS |
| Smoke-test file runs clean | `bin/rails test test/integration/admin_views_smoke_test.rb` | `8 runs, 15 assertions, 0 failures, 0 errors, 3 skips` | PASS |
| Full suite still green | `RAILS_ENV=test bin/rails test` | `1290 runs, 2898 assertions, 0 failures, 0 errors, 16 skips` | PASS |
| Grep gate: removed helpers nowhere referenced | `grep -rn "move_(up\|down)_admin_training_example" app/views/ app/helpers/` | empty (exit 1) | PASS |
| Controller has no move methods | `grep -nE "def move_(up\|down)" app/controllers/admin/training_examples_controller.rb` | empty (exit 1) | PASS |
| Routes: 0 training_example move helpers, 2 shot move helpers | `bin/rails routes \| grep -cE "move_(up\|down)_admin_training_example"` / `..._admin_shot` | `0` / `2` | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| P0-ADMIN-SHOW-500 | 260423-qvm-PLAN.md | Unblock Admin Show pages from HasMany/HasOne/BelongsTo 500 crashes on Rails 7.1 | SATISFIED | Shim (Commit A) + inter-fixes (c2cf86f3, ce3f0892) verified; live curl on #15/#16 + TrainingConcept #6 all 200 |
| P1-CONTROLLER-M2M-CLEANUP | 260423-qvm-PLAN.md | Remove v0.9 Phase D residues (move_up/move_down, training_concept_id FK, stale button_to helpers) | SATISFIED | All items removed — controller (Commit B), routes (Commit B), training_concepts view (Commit B) — grep gates + route-count checks all pass |
| P2-ADMIN-SMOKE-TESTS | 260423-qvm-PLAN.md | Add Index+Show smoke coverage for routed admin dashboards | SATISFIED | `test/integration/admin_views_smoke_test.rb` created (Commit C), 8 tests, 0 failures/errors; Rule-2 `/admin/shots` Index pre-existing bug caught inline and fixed |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None detected in the 6 files under verification | — | Clean. No TODOs, FIXMEs, placeholders, empty handlers, or console-only logic introduced |

### Deviations from Plan (Documented & Justified)

The SUMMARY explicitly calls out three plan deviations — all verified as real and within scope:

1. **c2cf86f3** (Rule-3 deviation) — `StartPositionDashboard` Field::ActiveStorage residue removed inline after Commit A browser UAT surfaced a second crash path. Same class of v0.9-Phase-D residue as the plan's target.
2. **ce3f0892** (Rule-3 deviation) — `BallConfigurationDashboard` stub created + `shot_image` residue dropped from `TrainingExampleDashboard` + training_examples show.html.erb. Verified: `app/dashboards/ball_configuration_dashboard.rb` exists (91 LOC); TrainingExample Show #15/#16 render 200.
3. **96d5f1b5** (Rule-2 deviation bundled into Commit C) — Admin::ShotsController `existing_action?` override + `requested_resource` override. Verified in `app/controllers/admin/shots_controller.rb`. Scope-match: direct v0.9-Phase-D residue detector pattern match, same class as the plan's TrainingExamples cleanup. Per Rule 2 policy, fixed inline rather than escalated.

### Human Verification Required

Gernot's UAT (Task 2 checkpoint) reported **"positions off"** — ball coordinates on the SVG don't match intended layout for at least one of examples 15/16. Per task-verifier instructions, this is **EXPECTED** and belongs in Claudia's seed-data lane, NOT a gap for Paul's scope.

1. **SVG visual plausibility UAT** — Open http://localhost:3008/admin/training_examples/15 and /16, inspect whether B1/B2/B3 coordinates match Gretillat-derived (for #15, klein/exact) and qualitative match-table positions (for #16). If off, forward as Claudia handoff for TrainingExample seed-coordinate refinement.
   - **Expected:** Ball positions inside the table rectangle, plausible for the declared `table_variant` and `position_type`.
   - **Why human:** Pixel-level QA of seed data; out of code scope. The SVG partial, the dashboard plumbing, and the Rails 7.1 × Administrate compatibility are ALL verified working. The only open item is data — not code.

### Gaps Summary

**None.** All 10 must-haves verified. The only outstanding item is a seed-data UAT handoff to Claudia — explicitly called out in the task brief as NOT-a-gap.

Note on verdict choice: per Step 9 decision tree, status `human_needed` is used because a non-empty human-verification section exists (Gernot's seed-coordinate concern). Even though this is explicitly flagged as "not Paul's scope", the Step 9 rule requires `human_needed` when any item requires human evaluation. Code-side verification is fully `passed`.

---

_Verified: 2026-04-22_
_Verifier: Claude (gsd-verifier)_
