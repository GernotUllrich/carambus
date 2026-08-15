---
phase: 37-in-app-doc-links
verified: 2026-04-14T00:00:00Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: none
  previous_score: n/a
---

# Phase 37: In-App Doc Links Verification Report

**Phase Goal:** Every wizard step has a working link to the corresponding section of the rewritten documentation, and the mkdocs_link helper generates correct locale-aware URLs for both DE and EN users.

**Verified:** 2026-04-14
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth (from ROADMAP.md Success Criteria) | Status | Evidence |
|---|------------------------------------------|--------|----------|
| 1 | mkdocs_link generates `/docs/en/#{path}/` for EN and `/docs/#{path}/` for DE matching `docs_page.html.erb:18-22` | VERIFIED | `application_helper.rb:149-168`; `bin/rails runner` smoke confirms 4 URL shapes exact: `/docs/managers/tournament-management/`, `/docs/en/managers/tournament-management/#seeding-list`, `/docs/index`, `/docs/en/managers/index` |
| 2 | All 6 happy-path wizard steps render a working doc link in a new tab | VERIFIED | `_wizard_steps_v2.html.erb` lines 78, 199, 275, 295, 314, 353 (steps 1, 2, 3, 4, 5, 6); all wrapped via `mkdocs_link` or `render 'wizard_step'` with `docs_path:`; partial `_wizard_step.html.erb:55-59` emits `mkdocs_link` inside `<details>` block; helper enforces `target="_blank"`, `rel="noopener"` (helper lines 149-154) |
| 3 | 5 form contexts in TournamentsController have doc links to relevant doc sections | VERIFIED | `parse_invitation.html.erb:13-18` (`#seeding-list`), `define_participants.html.erb:4-10` (`#participants`), `finalize_modus.html.erb:18-26` (`#mode-selection`), `tournament_monitor.html.erb:32-37` (`#start-parameters`). Table assignment + start settings share one form (per D-15), so 4 views cover 5 contexts. |
| 4 | At least 3 wizard-step links use anchor fragments (deep links) | VERIFIED | 5 of 6 wizard steps use anchors: step 2 `#seeding-list`, step 3 `#participants`, step 4 `#participants`, step 5 `#mode-selection`, step 6 `#start-parameters`. Exceeds ≥3 floor with margin. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `app/helpers/application_helper.rb` | mkdocs_link helper with locale-aware URLs + anchor support + text-required guard | VERIFIED | `def mkdocs_link(path, locale: nil, text: nil, anchor: nil, options: {})` at line 149; `def mkdocs_url(path, locale: nil, anchor: nil)` at line 158; `raise ArgumentError` at line 150; `is_index_file` branch at line 160 |
| `config/locales/de.yml` | 3 tournaments.docs.* keys | VERIFIED | Lines 1091-1094: `docs: walkthrough_link/form_help_link/form_help_prefix` inside `tournaments:` namespace |
| `config/locales/en.yml` | 3 tournaments.docs.* keys | VERIFIED | Lines 1069-1072: matching EN strings |
| `app/views/tournaments/_wizard_step.html.erb` | New `docs_path:` / `docs_anchor:` locals + mkdocs_link inside `<details>` | VERIFIED | Lines 23-24 fetch locals; lines 55-59 render mkdocs_link inside details block |
| `app/views/tournaments/_wizard_steps_v2.html.erb` | 6 wizard steps wired with doc links | VERIFIED | 3 inline direct calls (steps 1/2/6) + 3 via render `wizard_step` partial (steps 3/4/5) |
| `app/views/tournaments/parse_invitation.html.erb` | Form-help info box with mkdocs_link → seeding-list | VERIFIED | Lines 12-18 |
| `app/views/tournaments/define_participants.html.erb` | Form-help info box → participants | VERIFIED | Lines 4-10 |
| `app/views/tournaments/finalize_modus.html.erb` | Form-help info box → mode-selection | VERIFIED | Lines 18-26 |
| `app/views/tournaments/tournament_monitor.html.erb` | Form-top info box → start-parameters; 16 tooltips untouched | VERIFIED | Lines 32-37 emit link; `grep -c 'data-controller="tooltip"'` returns 16 (unchanged) |
| `docs/managers/tournament-management.de.md` | 4 stable anchors | VERIFIED | Lines 52, 63, 104, 118: `{#seeding-list}`, `{#participants}`, `{#mode-selection}`, `{#start-parameters}` |
| `docs/managers/tournament-management.en.md` | 4 stable anchors matching DE | VERIFIED | Lines 59, 70, 111, 125: identical kebab-case IDs |
| `test/helpers/application_helper_test.rb` | Contract tests for mkdocs_link / mkdocs_url | VERIFIED | 13 tests covering locale shapes, anchor handling, index-file handling, ArgumentError guard |
| `test/controllers/tournament_doc_links_test.rb` | Integration tests for DE + EN wizard rendering | VERIFIED | 2 tests (DE, EN) asserting URL shape, target/rel, deep-linked anchor present |

### Key Link Verification

| From | To | Via | Status |
|------|-----|-----|--------|
| `mkdocs_link` helper | `docs_page.html.erb:18-22` URL pattern | identical if/else on locale + index-file trailing slash | VERIFIED (helper replicates pattern exactly) |
| Wizard partial `_wizard_step` | `mkdocs_link` helper | `docs_path:` / `docs_anchor:` locals flow through line 57 | VERIFIED |
| 3 inline wizard steps | `mkdocs_link` helper | direct call sites | VERIFIED (lines 78, 199, 353) |
| 4 form views | `mkdocs_link` helper | direct call sites | VERIFIED |
| Anchor IDs in doc markdown | `mkdocs_link anchor:` callers | identical kebab-case IDs | VERIFIED (4 anchors × 2 files; same IDs used in callers) |

### Invariants Verified

| Invariant | Expected | Actual | Status |
|-----------|----------|--------|--------|
| Phase 36b tooltip count in tournament_monitor.html.erb | 16 | 16 | PASS |
| mkdocs.yml untouched in Phase 37 | no commits | last commit on mkdocs.yml is `2db7c09e` (phase 35) | PASS |
| docs_page.html.erb untouched | no commits | not in Phase 37 git log | PASS |
| Exactly 4 anchors in each doc file | 4 / 4 | 4 / 4 | PASS |
| No humanize fallback in mkdocs_link itself | absent | line 137 match is inside `docs_page_link` (out-of-scope duplicate); mkdocs_link has `raise ArgumentError` instead | PASS |
| Tests pass | 15/41/0 | 15 runs, 41 assertions, 0 failures, 0 errors | PASS |
| REQUIREMENTS.md LINK-01..04 closed | [x] × 4 | all marked Complete | PASS |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| DE URL shape | `mkdocs_url("managers/tournament-management", locale: "de")` | `/docs/managers/tournament-management/` | PASS |
| EN URL with anchor | `mkdocs_url("managers/tournament-management", locale: "en", anchor: "seeding-list")` | `/docs/en/managers/tournament-management/#seeding-list` | PASS |
| DE index (no trailing slash) | `mkdocs_url("index", locale: "de")` | `/docs/index` | PASS |
| EN managers/index | `mkdocs_url("managers/index", locale: "en")` | `/docs/en/managers/index` | PASS |
| DE walkthrough_link i18n | `I18n.t("tournaments.docs.walkthrough_link", locale: :de)` | `📖 Detailanleitung im Handbuch →` | PASS |
| EN walkthrough_link i18n | `I18n.t("tournaments.docs.walkthrough_link", locale: :en)` | `📖 Full walkthrough in handbook →` | PASS |
| DE form_help_prefix | `I18n.t("tournaments.docs.form_help_prefix", locale: :de)` | `Hilfe zu diesem Schritt:` | PASS |
| EN form_help_prefix | `I18n.t("tournaments.docs.form_help_prefix", locale: :en)` | `Help for this step:` | PASS |
| Phase 37 test suite | `bin/rails test test/helpers/application_helper_test.rb test/controllers/tournament_doc_links_test.rb` | 15 runs, 41 assertions, 0 failures, 0 errors, 0 skips | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| LINK-01 | 37-01 | mkdocs_link locale bug fix, EN prefix, DE root | SATISFIED | Helper lines 149-168; 11 helper tests passing |
| LINK-02 | 37-02, 37-03 | 6 wizard steps render working links via `docs_path:` local or direct call | SATISFIED | 3 direct + 3 partial call sites in `_wizard_steps_v2.html.erb` |
| LINK-03 | 37-04 | Form help text in 5 form contexts (4 views) has doc links | SATISFIED | 4 views with info-box/top-link blocks |
| LINK-04 | 37-02, 37-03 | ≥3 wizard links use anchor fragments | SATISFIED | 5 deep links (`#seeding-list`, `#participants` ×2, `#mode-selection`, `#start-parameters`) — exceeds floor |

### Anti-Patterns Found

None blocking. Observations:

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `app/helpers/application_helper.rb` | 96-101, 134-140 | Duplicate `docs_page_link` definitions (one with humanize fallback at line 137) | Info | Pre-existing, explicitly out of scope per Phase 37 invariant. Flagged as deferred cleanup in 37-01-SUMMARY. Does NOT affect `mkdocs_link`. |

### Human Verification Required

None. All success criteria verified programmatically via grep, test runs, and `bin/rails runner` smoke checks. No visual/UX behavior beyond what is already asserted (URL shape, target/rel, anchor fragment) requires human inspection for phase goal achievement.

(Optional follow-up, non-blocking: a human may want to visually confirm the blue info-box styling matches Phase 36b's Begriffserklärung box in all 4 form views. Not a gap — D-17 specifies the Tailwind classes and they match.)

### Gaps Summary

None. Phase 37 delivers all 4 ROADMAP Success Criteria, all declared must-haves, all declared invariants, and closes LINK-01..LINK-04 in REQUIREMENTS.md.

---

_Verified: 2026-04-14_
_Verifier: Claude (gsd-verifier)_
