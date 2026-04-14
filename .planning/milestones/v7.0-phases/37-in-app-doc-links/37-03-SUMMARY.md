---
phase: 37-in-app-doc-links
plan: 03
subsystem: views,tournament-wizard
tags: [views, wizard, docs, mkdocs, link, anchor, erb, partial]
requires:
  - 37-01 (mkdocs_link helper + tournaments.docs.walkthrough_link i18n key)
  - 37-02 (stable {#seeding-list}, {#participants}, {#mode-selection}, {#start-parameters} anchors in tournament-management.{de,en}.md)
provides:
  - _wizard_step.html.erb partial API with optional docs_path: and docs_anchor: locals (LINK-02 backbone)
  - 6 rendered doc links across all happy-path wizard steps (LINK-02)
  - 5 deep-linked wizard steps (LINK-04 comfortably exceeds ≥3 floor)
affects:
  - Plan 37-04 (form help links) — sibling plan, independent
  - Plan 37-05 (system test) — will exercise these link call sites
tech-stack:
  added: []
  patterns:
    - local_assigns.fetch pattern for optional partial locals (extended existing convention)
    - inline mkdocs_link inside Phase 36b <details open={active}> help blocks
    - i18n-driven link label via t('tournaments.docs.walkthrough_link')
key-files:
  created: []
  modified:
    - app/views/tournaments/_wizard_step.html.erb
    - app/views/tournaments/_wizard_steps_v2.html.erb
decisions:
  - D-10 implemented: _wizard_step.html.erb gets docs_path/docs_anchor via local_assigns.fetch — backward-compatible
  - D-11 implemented: link renders inside <details> block, below help <p>, with mt-2 spacing and text-sm styling
  - D-12 implemented: inline steps 1, 2, 6 get direct mkdocs_link calls inside their existing <details> help blocks
  - D-13 anchor mapping implemented verbatim: Step 1 → page top (no anchor), Step 2 → #seeding-list, Steps 3/4 → #participants, Step 5 → #mode-selection, Step 6 → #start-parameters
  - D-14 implemented: link text driven by t('tournaments.docs.walkthrough_link') — no hardcoded strings
metrics:
  duration_seconds: 132
  completed: 2026-04-14
  tasks: 3
  commits: 3
---

# Phase 37 Plan 03: Wizard Step Doc Links Summary

Wired all 6 happy-path tournament wizard steps to `mkdocs_link` — steps 3/4/5 via new optional partial locals on `_wizard_step.html.erb`, and steps 1/2/6 via direct inline calls inside their existing Phase 36b `<details>` help blocks. Five of six steps deep-link to stable anchors (LINK-02 + LINK-04).

## What was built

### Task 1 — _wizard_step.html.erb partial API (commit bf2f86cd)

**File:** `app/views/tournaments/_wizard_step.html.erb`

Three edits to the wizard step partial:

1. **Header comment** — documented the two new optional locals (`docs_path`, `docs_anchor`) alongside the existing partial parameter list.
2. **local_assigns block (lines 22-24)** — added `docs_path = local_assigns.fetch(:docs_path, nil)` and `docs_anchor = local_assigns.fetch(:docs_anchor, nil)` following the existing Phase 36b pattern for optional locals. Backward-compatible: callers that don't pass these locals behave identically.
3. **Help block (lines 50-62)** — inside the existing `<details open={status==:active}>` block, directly after the `<p><%= help.html_safe %></p>` line, added:

```erb
<% if docs_path.present? %>
  <p class="step-docs-link mt-2">
    <%= mkdocs_link(docs_path, anchor: docs_anchor, text: t('tournaments.docs.walkthrough_link'), options: { class: 'text-blue-600 dark:text-blue-400 underline text-sm' }) %>
  </p>
<% end %>
```

The `docs_anchor` kwarg may be `nil` — the 37-01 helper handles that (no fragment appended per D-04). The `.step-docs-link` class is a semantic hook with no CSS dependency. Link placement matches D-11: inside the help `<details>` block, never in the action row.

### Task 2 — Wire steps 3/4/5 via partial locals (commit 04c112bd)

**File:** `app/views/tournaments/_wizard_steps_v2.html.erb`

Three edits, one per `render 'wizard_step'` call:

- **Step 3 (Teilnehmerliste bearbeiten)** — added `docs_path: 'managers/tournament-management'` and `docs_anchor: 'participants'` after the existing `help:` string, before the closing `%>`.
- **Step 4 (Teilnehmerliste finalisieren)** — same `docs_path`, same `docs_anchor: 'participants'` (both steps share the participants section per D-13).
- **Step 5 (Turniermodus wählen)** — same `docs_path`, `docs_anchor: 'mode-selection'`.

All three `render 'wizard_step'` calls remain structurally intact — only two new kwargs appended per call. Existing kwargs unchanged.

### Task 3 — Inline retrofit for steps 1/2/6 (commit 33c6757a)

**File:** `app/views/tournaments/_wizard_steps_v2.html.erb`

Three inline `mkdocs_link` calls added inside each inline step's existing `<details>` help block, placed directly after the existing `</p>` and before `</details>`:

- **Step 1 (ClubCloud load, lines 75-79)** — `mkdocs_link('managers/tournament-management', text: …)` — no `anchor:` kwarg. Links to page top per D-13 (the Step 2 doc section describes this, but D-13 keeps the anchor set minimal).
- **Step 2 (invitation upload, lines 197-201)** — `mkdocs_link('managers/tournament-management', anchor: 'seeding-list', text: …)`.
- **Step 6 (start + manage, lines 351-355)** — `mkdocs_link('managers/tournament-management', anchor: 'start-parameters', text: …)`.

All three use identical formatting: a `<p class="step-docs-link mt-2">` wrapper with the same `text-blue-600 dark:text-blue-400 underline text-sm` option hash as Task 1. Link text always resolves through `t('tournaments.docs.walkthrough_link')`.

## Verification checks run

### Task 1 (partial API)

```
$ grep -c "local_assigns.fetch(:docs_path" app/views/tournaments/_wizard_step.html.erb
1
$ grep -c "local_assigns.fetch(:docs_anchor" app/views/tournaments/_wizard_step.html.erb
1
$ grep -c "mkdocs_link" app/views/tournaments/_wizard_step.html.erb
1
$ grep -c "tournaments.docs.walkthrough_link" app/views/tournaments/_wizard_step.html.erb
1
$ grep -c "step-docs-link" app/views/tournaments/_wizard_step.html.erb
1
$ grep -c "wizard-step-actions" app/views/tournaments/_wizard_step.html.erb
1   # unchanged — the action row stays
```

### Task 2 (render-call kwargs)

```
$ grep -c "docs_path: 'managers/tournament-management'" app/views/tournaments/_wizard_steps_v2.html.erb
3
$ grep -c "docs_anchor: 'participants'" app/views/tournaments/_wizard_steps_v2.html.erb
2
$ grep -c "docs_anchor: 'mode-selection'" app/views/tournaments/_wizard_steps_v2.html.erb
1
$ grep -c "render 'wizard_step'" app/views/tournaments/_wizard_steps_v2.html.erb
3   # unchanged — still 3 render calls
```

### Task 3 (inline mkdocs_link calls)

```
$ grep -c "mkdocs_link('managers/tournament-management'" app/views/tournaments/_wizard_steps_v2.html.erb
3
$ grep -c "anchor: 'seeding-list'" app/views/tournaments/_wizard_steps_v2.html.erb
1
$ grep -c "anchor: 'start-parameters'" app/views/tournaments/_wizard_steps_v2.html.erb
1
$ grep -c "tournaments.docs.walkthrough_link" app/views/tournaments/_wizard_steps_v2.html.erb
3
$ grep -c "step-docs-link" app/views/tournaments/_wizard_steps_v2.html.erb
3
```

Step 1 correctly has no `anchor:` kwarg — verified by inspection of its mkdocs_link line (line 77).

### Completion contract (all 4 anchor IDs in _wizard_steps_v2)

```
$ grep -c "seeding-list" app/views/tournaments/_wizard_steps_v2.html.erb
1     # Step 2
$ grep -c "'participants'" app/views/tournaments/_wizard_steps_v2.html.erb
2     # Steps 3 and 4
$ grep -c "mode-selection" app/views/tournaments/_wizard_steps_v2.html.erb
1     # Step 5
$ grep -c "start-parameters" app/views/tournaments/_wizard_steps_v2.html.erb
1     # Step 6
```

All 4 stable anchors from Plan 37-02 are referenced. Total link count: 3 (partial renders for 3/4/5) + 3 (inline for 1/2/6) = **6 wizard steps → LINK-02 ✓**. Deep-linked count: 5 (seeding-list, participants ×2, mode-selection, start-parameters) → **≥3 → LINK-04 ✓**.

### erblint

```
$ bundle exec erblint app/views/tournaments/_wizard_step.html.erb app/views/tournaments/_wizard_steps_v2.html.erb
1 error(s) were found in ERB files
Linting 2 files with 14 linters...
Remove multiple trailing newline at the end of the file.
In file: app/views/tournaments/_wizard_steps_v2.html.erb:403
```

One error — **pre-existing trailing-newline violation** confirmed via `git stash`/re-lint to exist at line 388 before my edits (the line number shifted because my edits added more content, but the root cause is identical — pre-existing double newline at EOF). Out of scope per the scope-boundary rule. No new erblint violations introduced by this plan.

## Deviations from Plan

None. All 3 tasks executed exactly as written. D-10..D-14 implemented verbatim with the exact ERB snippets from the plan. No deviations, no auto-fixes, no architectural changes.

## Out-of-scope / Deferred

- **Pre-existing trailing-newline at EOF in `_wizard_steps_v2.html.erb`** — existed before this plan, out of scope per scope-boundary rule. If a future cleanup pass wants to fix it, remove the trailing empty line after `<% end %>` at the very bottom of the file.
- No other deferred items — this plan is a pure view-wiring retrofit.

## Threat Flags

None — no new security-relevant surface introduced. All `docs_path` and `docs_anchor` values are ERB string literals in the templates; no user input flows in (T-37-06 disposition: accept). `rel="noopener"` on `target="_blank"` already enforced inside `mkdocs_link` (Plan 37-01 D-05 / T-37-07 disposition: mitigate). The partial's `<details>` block is the existing Phase 36b help pattern (T-37-08 disposition: accept).

## Commits

| # | Task | Hash | Files |
|---|------|------|-------|
| 1 | Extend _wizard_step.html.erb partial with docs_path/docs_anchor locals | bf2f86cd | app/views/tournaments/_wizard_step.html.erb |
| 2 | Wire steps 3/4/5 via partial locals | 04c112bd | app/views/tournaments/_wizard_steps_v2.html.erb |
| 3 | Wire inline steps 1/2/6 with direct mkdocs_link calls | 33c6757a | app/views/tournaments/_wizard_steps_v2.html.erb |

## Requirements completed

- **LINK-02** — All 6 happy-path wizard steps render a working `mkdocs_link` inside their collapsible `<details>` help block. 3 via partial locals (steps 3/4/5), 3 via inline calls (steps 1/2/6). Verified by grep-count (3 + 3 = 6).
- **LINK-04** — 5 of 6 wizard steps deep-link to stable anchors (steps 2/3/4/5/6 hit `#seeding-list`, `#participants` ×2, `#mode-selection`, `#start-parameters`); step 1 links to page top per D-13. Comfortably exceeds the ≥3 floor.

## Self-Check: PASSED

- [x] `app/views/tournaments/_wizard_step.html.erb` modified and committed (bf2f86cd)
- [x] `app/views/tournaments/_wizard_steps_v2.html.erb` modified and committed (04c112bd, 33c6757a)
- [x] All 3 commits present in git log: `git log --oneline | grep -E "bf2f86cd|04c112bd|33c6757a"` — found
- [x] Partial accepts docs_path/docs_anchor via local_assigns.fetch — verified
- [x] 3 render calls pass docs_path — verified
- [x] 3 inline mkdocs_link calls inside existing details blocks — verified
- [x] All 4 stable anchor IDs referenced (seeding-list, participants, mode-selection, start-parameters) — verified
- [x] erblint clean (only pre-existing trailing-newline error remains) — verified
- [x] No Phase 36b tooltips modified — confirmed (no `data-controller="tooltip"` edits in this partial)
- [x] LINK-02 (6/6 steps) + LINK-04 (5/6 deep-linked) both satisfied
