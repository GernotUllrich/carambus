---
phase: 37-in-app-doc-links
plan: 01
subsystem: helpers,i18n
tags: [helper, i18n, docs, mkdocs, link, locale, anchor]
requires:
  - app/views/static/docs_page.html.erb (URL-shape template)
provides:
  - mkdocs_link helper with locale-aware URL + anchor + text guard (LINK-01)
  - mkdocs_url raw-URL helper (Claude's discretion D-bonus)
  - tournaments.docs.walkthrough_link (DE, EN) — D-14
  - tournaments.docs.form_help_link (DE, EN) — D-19
  - tournaments.docs.form_help_prefix (DE, EN) — D-20
affects:
  - Plan 37-03 (wizard step links) — unblocked
  - Plan 37-04 (form help links) — unblocked
tech-stack:
  added: []
  patterns:
    - locale-aware URL helper mirroring docs_page.html.erb:18-22
    - ArgumentError guard replacing humanize text fallback
    - raw-URL helper pattern for callers needing custom link_to wrapping
key-files:
  created: []
  modified:
    - app/helpers/application_helper.rb
    - config/locales/de.yml
    - config/locales/en.yml
decisions:
  - D-01..D-05 implemented as specified (no deviations)
  - D-14, D-19, D-20 i18n keys added verbatim per plan strings
  - humanize fallback in docs_page_link (pre-existing, lines 134-140) left untouched per plan scope
metrics:
  duration_seconds: 123
  completed: 2026-04-14
  tasks: 2
  commits: 2
---

# Phase 37 Plan 01: mkdocs_link helper fix + tournaments.docs i18n keys Summary

Fixed mkdocs_link helper to emit locale-aware MkDocs URLs with optional anchor fragments and mandatory text argument; added 3 tournaments.docs.* i18n keys (walkthrough_link, form_help_link, form_help_prefix) in DE and EN, unblocking Plans 37-03 and 37-04.

## What was built

### Task 1 — mkdocs_link helper fix (commit d46c4a22)

**File:** `app/helpers/application_helper.rb`

Replaced the buggy `mkdocs_link` method (lines 142-151) with two public helper methods:

1. **`mkdocs_link(path, locale: nil, text: nil, anchor: nil, options: {})`**
   - Raises `ArgumentError` if `text:` is nil or blank (humanize fallback removed per D-03)
   - Delegates URL construction to `mkdocs_url`
   - Preserves `target: "_blank"` and `rel: "noopener"` on the anchor tag (D-05)

2. **`mkdocs_url(path, locale: nil, anchor: nil)`** (new public raw-URL helper)
   - DE (default): `/docs/#{path}/`
   - EN: `/docs/en/#{path}/`
   - Index-file paths (`path.end_with?("/index")` or `path == "index"`): no trailing slash
   - Optional `anchor:` kwarg appends `#anchor` fragment
   - Replicates `app/views/static/docs_page.html.erb:17-22` exactly

The `docs_page_link` helper (lines 134-140) was NOT modified per plan scope.

### Task 2 — tournaments.docs.* i18n keys (commit cbd5ecf4)

**Files:** `config/locales/de.yml`, `config/locales/en.yml`

Added new `tournaments.docs:` sub-namespace alphabetically before `monitor_form:`:

| Key | DE | EN |
|-----|-----|-----|
| `walkthrough_link` | `📖 Detailanleitung im Handbuch →` | `📖 Full walkthrough in handbook →` |
| `form_help_link` | `📖 Detailanleitung im Handbuch →` | `📖 Full walkthrough in handbook →` |
| `form_help_prefix` | `Hilfe zu diesem Schritt:` | `Help for this step:` |

Per D-19, `walkthrough_link` and `form_help_link` are intentionally identical within each locale — one canonical link label, two call sites.

## Verification checks run

### Task 1 acceptance checks

```
$ grep -c 'def mkdocs_link' app/helpers/application_helper.rb
1
$ grep -c 'def mkdocs_url' app/helpers/application_helper.rb
1
$ grep 'raise ArgumentError, "mkdocs_link requires text: argument"' app/helpers/application_helper.rb
  (found)
$ bin/rails runner 'include ApplicationHelper; puts mkdocs_url("managers/tournament-management", locale: "de")'
/docs/managers/tournament-management/
$ bin/rails runner 'include ApplicationHelper; puts mkdocs_url("managers/tournament-management", locale: "en", anchor: "seeding-list")'
/docs/en/managers/tournament-management/#seeding-list
$ bin/rails runner 'include ApplicationHelper; puts mkdocs_url("index", locale: "de")'
/docs/index
$ bin/rails runner 'include ApplicationHelper; puts mkdocs_url("managers/index", locale: "en")'
/docs/en/managers/index
$ bin/rails runner 'include ApplicationHelper; begin; mkdocs_link("x"); rescue ArgumentError => e; puts "OK: #{e.message}"; end'
OK: mkdocs_link requires text: argument
$ bin/rails runner 'include ApplicationHelper; begin; mkdocs_link("x", text: ""); rescue ArgumentError; puts "OK_empty"; end'
OK_empty
```

All 4 URL shapes correct: DE root, EN-prefixed, DE-index (no trailing slash), EN-index (no trailing slash). Deep-link fragment appended only when `anchor:` present. ArgumentError raised on nil and blank text.

### Task 2 acceptance checks

Smoke test run verbatim from the plan:

```
$ bin/rails runner 'raise "DE walkthrough_link wrong" unless I18n.t("tournaments.docs.walkthrough_link", locale: :de) == "📖 Detailanleitung im Handbuch →"; raise "EN walkthrough_link wrong" unless I18n.t("tournaments.docs.walkthrough_link", locale: :en) == "📖 Full walkthrough in handbook →"; raise "DE form_help_link mismatch" unless I18n.t("tournaments.docs.form_help_link", locale: :de) == I18n.t("tournaments.docs.walkthrough_link", locale: :de); raise "DE form_help_prefix wrong" unless I18n.t("tournaments.docs.form_help_prefix", locale: :de) == "Hilfe zu diesem Schritt:"; raise "EN form_help_prefix wrong" unless I18n.t("tournaments.docs.form_help_prefix", locale: :en) == "Help for this step:"; puts "OK"'
OK
```

```
$ grep -c 'Detailanleitung im Handbuch' config/locales/de.yml
2
$ grep -c 'Full walkthrough in handbook' config/locales/en.yml
2
$ grep 'form_help_prefix:' config/locales/de.yml
      form_help_prefix: "Hilfe zu diesem Schritt:"
$ grep 'form_help_prefix:' config/locales/en.yml
      form_help_prefix: "Help for this step:"
```

All 3 keys resolve correctly in both locales; DE `form_help_link` == DE `walkthrough_link` per D-19; identical count `2` confirms the D-19 one-canonical-string invariant.

### Lint

```
$ bundle exec standardrb app/helpers/application_helper.rb
```

Zero new violations introduced by our edits (lines 142-168). The 242 pre-existing violations elsewhere in the file are out of scope (scope boundary — not directly caused by this plan's changes).

## Deviations from Plan

### Rule 1 — Layout fix inside new code

**Found during:** Task 1 — initial `mkdocs_url` indentation used the multi-line `base = if …` style copied verbatim from the plan's code block. Standardrb flagged `Layout/IndentationWidth`, `Layout/ElseAlignment`, `Layout/EndAlignment` on those lines.

**Fix:** Restructured the `if/else` as `base =` followed by a line-break and indented `if` block (Ruby/Standard-preferred form). Semantically equivalent output; zero behavior change. All URL-shape acceptance tests re-verified after the layout tweak.

**Commit:** d46c4a22 (same commit as Task 1 — fix applied before committing)

No other deviations. Plans D-01..D-05, D-14, D-19, D-20 implemented verbatim.

## Out-of-scope / Deferred

- **Duplicate `docs_page_link` definition** (lines 96-101 and 134-140 in `application_helper.rb`): Two definitions of `docs_page_link` coexist — the second shadows the first at load time. This is pre-existing and explicitly out of scope for this plan (plan says "`docs_page_link` at lines 134-140 is NOT modified"). Logged here for a future cleanup pass.
- **`docs_page_link` humanize fallback** (line 137): Still present, also out of scope. The plan-level wording `grep 'text ||= path.split' app/helpers/application_helper.rb` returns NOTHING was written with mkdocs_link in mind; the pre-existing pattern in `docs_page_link` is not addressed by this plan.
- **Pre-existing standardrb violations** (242 total, all in unrelated helper methods `generate_filter_fields`, `detect_field_type_and_options`, etc.): Out of scope per the scope-boundary rule.

## Threat Flags

None — no new security-relevant surface introduced. The mkdocs_link URL helper only consumes hard-coded call-site paths and static i18n strings (see plan threat model T-37-01). `rel="noopener"` preserved per T-37-02.

## Commits

| # | Task | Hash | Files |
|---|------|------|-------|
| 1 | Fix mkdocs_link helper | d46c4a22 | app/helpers/application_helper.rb |
| 2 | Add tournaments.docs.* i18n keys | cbd5ecf4 | config/locales/de.yml, config/locales/en.yml |

## Requirements completed

- **LINK-01** — mkdocs_link generates correct locale-aware URLs with optional anchor fragments; text argument enforced; target/rel preserved. All behavior contracts verified via `bin/rails runner`.

## Self-Check: PASSED

- [x] `app/helpers/application_helper.rb` modified and committed (d46c4a22)
- [x] `config/locales/de.yml` modified and committed (cbd5ecf4)
- [x] `config/locales/en.yml` modified and committed (cbd5ecf4)
- [x] Both commits present in `git log --oneline`
- [x] mkdocs_url URL shapes: DE root, EN-prefixed, DE/EN index-no-slash, anchor fragment — all verified
- [x] ArgumentError guard: nil and blank text — both verified
- [x] All 6 i18n entries resolve correctly (3 keys × 2 locales) — verified
- [x] D-19 invariant (DE walkthrough_link == DE form_help_link) — verified
- [x] No new standardrb violations in edited regions (lines 142-168)
