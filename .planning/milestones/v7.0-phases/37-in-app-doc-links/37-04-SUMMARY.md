---
phase: 37-in-app-doc-links
plan: 04
subsystem: views,tournaments,docs
tags: [view, erb, docs, mkdocs, link, tournament, form-help, link-03]
requires:
  - 37-01 (mkdocs_link helper + tournaments.docs.* i18n keys)
  - 37-02 (stable anchors seeding-list, participants, mode-selection, start-parameters)
provides:
  - Form-help mkdocs_link in parse_invitation.html.erb → #seeding-list
  - Form-help mkdocs_link in define_participants.html.erb → #participants
  - Form-help mkdocs_link in finalize_modus.html.erb → #mode-selection
  - Form-top mkdocs_link in tournament_monitor.html.erb → #start-parameters
affects:
  - LINK-03 acceptance (5 form contexts → 4 views → 4 links)
tech-stack:
  added: []
  patterns:
    - Reused Phase 36b Begriffserklärung info-box Tailwind class set (D-17)
    - Reused Plan 37-02 stable anchors — no new anchors introduced (D-18)
    - Phase 36b Stimulus tooltips on tournament_monitor parameter fields left byte-identical (D-16)
key-files:
  created:
    - .planning/phases/37-in-app-doc-links/37-04-SUMMARY.md
  modified:
    - app/views/tournaments/parse_invitation.html.erb
    - app/views/tournaments/define_participants.html.erb
    - app/views/tournaments/finalize_modus.html.erb
    - app/views/tournaments/tournament_monitor.html.erb
decisions:
  - D-15, D-16, D-17, D-18, D-19, D-20 implemented verbatim
  - No deviations — plan executed exactly as written
metrics:
  duration_seconds: 480
  completed: 2026-04-14
  tasks: 2
  commits: 2
---

# Phase 37 Plan 04: Form-Help Doc Links in 4 Tournament Views Summary

Four TournamentsController form views each render one prominent `mkdocs_link` into the rewritten tournament-management handbook, using the 4 stable anchors from Plan 37-02 and the i18n-locked labels from Plan 37-01; Phase 36b parameter-field tooltips on `tournament_monitor.html.erb` remain byte-identical (16 → 16).

## What was built

### Task 1 — Pre-start views: 3 info boxes (commit 815937d5)

Three pre-start views each gained a blue info box directly below their H1/title, using the exact Tailwind class set from `_wizard_steps_v2.html.erb:388` (the Begriffserklärung box) — `bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-700 rounded-lg p-4 mb-6` — for Phase 36b visual consistency (D-17).

| View | Insertion point | Anchor | i18n prefix | i18n link |
|------|-----------------|--------|-------------|-----------|
| `parse_invitation.html.erb` | After header `</div>`, before `<% if @extraction_result[:success] %>` | `#seeding-list` | `tournaments.docs.form_help_prefix` | `tournaments.docs.form_help_link` |
| `define_participants.html.erb` | After `max-w-3xl` wrapper, before the team-size branch | `#participants` | same | same |
| `finalize_modus.html.erb` | Between the `show` partial render and the `<div flex flex-wrap>` wrapper (wrapped in its own `container mx-auto mt-6 px-4` / `max-w-3xl` for spacing) | `#mode-selection` | same | same |

All 3 boxes use the same `<p class="text-sm text-blue-900 dark:text-blue-200">` body, the literal `📖` emoji, a `<strong>`-wrapped prefix, and the `mkdocs_link` call with `options: { class: 'underline font-medium' }` for visual link emphasis. Each insertion is annotated with a `<!-- LINK-03: Detailanleitung im Handbuch -->` comment for future grepping.

### Task 2 — tournament_monitor.html.erb form-top link (commit 79f0e747)

One prominent `mkdocs_link('managers/tournament-management', anchor: 'start-parameters', ...)` inserted at the form top, inside the `max-w-3xl mx-auto flex flex-col` wrapper but BEFORE the `.rounded.shadow.p-8` block that houses the parameter fields. Same Tailwind class set as Task 1 (D-17). Comment: `<!-- LINK-03: Detailanleitung im Handbuch (form-top link per D-16; Phase 36b tooltips on parameter fields below are NOT modified) -->`.

The anchor `start-parameters` covers both the table assignment and start-settings contexts per D-15 (both live in one shared form, one shared doc section). No new anchor introduced (D-18).

**Phase 36b tooltip invariant honored (D-16):**
- `git show HEAD~1:app/views/tournaments/tournament_monitor.html.erb | grep -c 'data-controller="tooltip"'` → `16`
- `grep -c 'data-controller="tooltip"' app/views/tournaments/tournament_monitor.html.erb` → `16`
- `git diff HEAD~1 app/views/tournaments/tournament_monitor.html.erb | grep -cE '^[+-].*data-controller="tooltip"'` → `0`
- `git diff HEAD~1 app/views/tournaments/tournament_monitor.html.erb | grep -c verification_failure` → `0`

Zero tooltip lines added or removed. The verification_failure banner and confirmation_modal render block are byte-identical.

## Verification checks run

### Per-view mkdocs_link count

```
$ for f in app/views/tournaments/parse_invitation.html.erb app/views/tournaments/define_participants.html.erb app/views/tournaments/finalize_modus.html.erb app/views/tournaments/tournament_monitor.html.erb; do echo "$(grep -c 'mkdocs_link' $f) $f"; done
1 app/views/tournaments/parse_invitation.html.erb
1 app/views/tournaments/define_participants.html.erb
1 app/views/tournaments/finalize_modus.html.erb
1 app/views/tournaments/tournament_monitor.html.erb
```

All 4 views contain exactly 1 `mkdocs_link` call.

### Per-anchor grep

```
$ grep -c "anchor: 'seeding-list'" app/views/tournaments/parse_invitation.html.erb           # => 1
$ grep -c "anchor: 'participants'" app/views/tournaments/define_participants.html.erb         # => 1
$ grep -c "anchor: 'mode-selection'" app/views/tournaments/finalize_modus.html.erb            # => 1
$ grep -c "anchor: 'start-parameters'" app/views/tournaments/tournament_monitor.html.erb      # => 1
```

Each view references its expected anchor exactly once.

### Tailwind class string

All 4 views contain the verbatim class substring `bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-700 rounded-lg p-4 mb-6`.

### i18n keys

All 4 views reference `tournaments.docs.form_help_prefix` and `tournaments.docs.form_help_link` (one instance each per view).

### LINK-03 comment markers

```
$ grep -l '<!-- LINK-03' app/views/tournaments/parse_invitation.html.erb app/views/tournaments/define_participants.html.erb app/views/tournaments/finalize_modus.html.erb app/views/tournaments/tournament_monitor.html.erb | wc -l
       4
```

All 4 insertions tagged.

### Tooltip invariant (tournament_monitor.html.erb)

| Source | Count |
|--------|-------|
| `git show` pre-edit | 16 |
| post-edit file | 16 |
| diff tooltip +/- lines | 0 |
| diff verification_failure lines | 0 |

Phase 36b invariant holds byte-identically.

### erblint

```
$ bundle exec erblint app/views/tournaments/parse_invitation.html.erb app/views/tournaments/define_participants.html.erb app/views/tournaments/finalize_modus.html.erb app/views/tournaments/tournament_monitor.html.erb
```

Violations reported, but ALL are on pre-existing lines unrelated to this plan's insertions:

- `finalize_modus.html.erb`: lines 32, 46, 59, 89, 97, 105, 175, 182, 192, 208, 218 (trailing whitespace, void-element closing, space-before-`%>`) — all pre-existing in code that pre-dates Plan 37-04.
- `tournament_monitor.html.erb`: line 20 (pre-existing `hr` void-element style from the `<style>` block) and lines 97, 100, 103, 106, 118, 121 (pre-existing autocomplete-attribute warnings on parameter input fields from Phase 36b).

None of my inserted lines (info-box `<div>`, `<p>`, and `mkdocs_link` call) produced a violation. Per the plan's scope-boundary rule, pre-existing lint warnings in unrelated regions are NOT fixed here. Logged to the phase's `deferred-items.md` if future tidy-up desired.

## Deviations from Plan

None — plan executed exactly as written. D-15 through D-20 implemented verbatim; the same Tailwind class set reused across all 4 info boxes (D-17); the 4 stable anchors from Plan 37-02 reused, no new anchors introduced (D-18); `tournaments.docs.form_help_prefix` and `tournaments.docs.form_help_link` used from Plan 37-01 (D-19, D-20); Phase 36b tooltips on `tournament_monitor.html.erb` parameter fields remain byte-identical (D-16).

## Out-of-scope / Deferred

- Pre-existing erblint violations in `finalize_modus.html.erb` (trailing whitespace, void-element closing style, `<%` spacing) and `tournament_monitor.html.erb` (void-element `hr` in the `<style>` block, autocomplete attribute warnings on Phase 36b parameter inputs): NOT addressed — scope boundary. These pre-date Plan 37-04's insertion and touching them would risk the Phase 36b byte-identical invariant on `tournament_monitor.html.erb`.

## Threat Flags

None — no new security-relevant surface introduced. Per the plan's threat register (T-37-09, T-37-10, T-37-11): all `mkdocs_link` arguments are ERB literals (no user input flows into URL/anchor); `rel="noopener"` enforced by the helper from Plan 37-01 (D-05); Phase 36b tooltip clobber prevented via explicit diff-level assertion.

## Commits

| # | Task | Hash | Files |
|---|------|------|-------|
| 1 | Three pre-start views get info-box doc links | 815937d5 | parse_invitation.html.erb, define_participants.html.erb, finalize_modus.html.erb |
| 2 | tournament_monitor form-top doc link | 79f0e747 | tournament_monitor.html.erb |

## Requirements completed

- **LINK-03** — All 5 form contexts (invitation upload, participant edit, mode selection, table assignment, start settings) are covered by the 4 view edits, each linking to the correct stable anchor via `mkdocs_link`. Phase 36b tooltips remain untouched on `tournament_monitor.html.erb`.

## Self-Check: PASSED

- [x] `app/views/tournaments/parse_invitation.html.erb` modified and committed (815937d5)
- [x] `app/views/tournaments/define_participants.html.erb` modified and committed (815937d5)
- [x] `app/views/tournaments/finalize_modus.html.erb` modified and committed (815937d5)
- [x] `app/views/tournaments/tournament_monitor.html.erb` modified and committed (79f0e747)
- [x] Both commits present in `git log --oneline -2`
- [x] Each of 4 views contains exactly 1 `mkdocs_link` call
- [x] Each of 4 views references the expected anchor (`seeding-list`, `participants`, `mode-selection`, `start-parameters`)
- [x] All 4 views contain the verbatim Phase 36b Tailwind class string
- [x] All 4 views contain the `<!-- LINK-03` comment marker
- [x] All 4 views reference `tournaments.docs.form_help_prefix` and `tournaments.docs.form_help_link`
- [x] Phase 36b tooltip count in `tournament_monitor.html.erb` byte-identical: 16 → 16 (git show HEAD vs. post-edit)
- [x] Zero tooltip lines added/removed (`git diff` returns 0 for `data-controller="tooltip"`)
- [x] Zero verification_failure diff lines (banner block untouched)
- [x] erblint violations on the 4 files are all pre-existing; zero new violations from inserted blocks
