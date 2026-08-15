---
phase: quick-260702-tvf
plan: 01
subsystem: docs
tags: [github-presence, readme, contributing, good-first-issues, gh-cli]
requires: []
provides:
  - "Root README.md (English GitHub landing page)"
  - "Root CONTRIBUTING.md (contributor onboarding)"
  - "5 good-first-issue drafts (unposted, awaiting approval)"
  - "Updated GitHub repo description + homepage"
affects: [github-repo-metadata]
tech-stack:
  added: []
  patterns: []
key-files:
  created:
    - README.md
    - CONTRIBUTING.md
    - .planning/quick/260702-tvf-github-auftritt-verbessern-readme-contri/issue-drafts/01-i18n-notification-en-gap.md
    - .planning/quick/260702-tvf-github-auftritt-verbessern-readme-contri/issue-drafts/02-add-database-yml-example.md
    - .planning/quick/260702-tvf-github-auftritt-verbessern-readme-contri/issue-drafts/03-add-env-example.md
    - .planning/quick/260702-tvf-github-auftritt-verbessern-readme-contri/issue-drafts/04-table-monitor-todo-i18n.md
    - .planning/quick/260702-tvf-github-auftritt-verbessern-readme-contri/issue-drafts/05-docs-readme-en-github-links.md
  modified: []
decisions:
  - "Issue drafts stay local files only — .planning/quick/ is gitignored (.gitignore:76), matching the do-not-post constraint"
  - "README links LICENSE file directly (verified present at repo root, GitHub reports MIT)"
  - "5 drafts written (max allowed) — all 5 pre-verified candidates re-confirmed as real gaps"
metrics:
  duration: "~4 minutes"
  completed: "2026-07-02"
---

# Quick Task 260702-tvf: GitHub-Auftritt verbessern (README, CONTRIBUTING, Issue-Drafts, Repo-Metadaten) Summary

**English root README (hero + 3 screenshots + features + architecture) and CONTRIBUTING (setup/tests/lint/MIN_ID-LocalProtector) created and committed; 5 real good-first-issue drafts staged locally (NOT posted); GitHub description de-typo'd and homepage set via gh CLI.**

## Tasks Completed

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Root README.md + CONTRIBUTING.md | `bc29edb2` | README.md (47 lines), CONTRIBUTING.md (80 lines) |
| 2 | 5 good-first-issue drafts | (no commit — `.planning/quick/` gitignored) | issue-drafts/01–05 |
| 3 | GitHub repo metadata via gh | (no local files) | description + homepage updated |
| 4 | Human-verify checkpoint | — | prepared; see "Awaiting Human Review" below |

## What was done

### Task 1 — README.md + CONTRIBUTING.md (commit `bc29edb2`)

- **README.md**: title + tagline, prominent DE link to `docs/README.de.md`, hero paragraph (in production at Billardclub Wedel 61 e.V. since 2022), 3 screenshots via relative repo paths (all verified present on disk: `docs/screenshots/pool_14_1_scoreboard_playing.png`, `docs/screenshots/pool_tables_overview.png`, `docs/managers/images/tournament-wizard-overview.png`), 5-bullet feature list, architecture one-liner with DB scale (17 seasons / 66,860 players / 313,509 games / 18,384 tournaments), tech-stack line, quickstart + contributing pointers, MIT license link. Only honest badges (MIT + docs link, no fake CI badges). No `.md` links copied from `docs/README.en.md`.
- **CONTRIBUTING.md**: welcome (AI-assisted development explicitly welcome), prerequisites (Ruby 3.2.1 / PostgreSQL / Redis / Node 18+), clone→bundle→yarn→db setup, `foreman start -f Procfile.dev`, full Minitest command set incl. `test:critical` and single-file/line forms, all 3 lint commands, the local-vs-global section (MIN_ID 50_000_000, LocalProtector, LocalProtectorTestOverride), conventions (conventional commits, frozen_string_literal, DE business / EN technical comments), contact (GitHub issues + gernot.ullrich@gmx.de).
- Automated verify (all greps from plan) passed: `OK`.

### Task 2 — Issue drafts (5 files, NOT posted to GitHub)

Every candidate was re-verified against the live codebase before drafting:

| Draft | Re-verification result |
| ----- | ---------------------- |
| 01 i18n `notification` EN gap | de.yml 118 vs en.yml 114 top-level keys; `notification` (10 keys), `locales`, `views` absent in en — confirmed via YAML diff |
| 02 `config/database.yml.example` | neither database.yml nor an example file committed — confirmed absent |
| 03 `.env.example` | absent — confirmed |
| 04 `# TODO: I18n` in TableMonitor | confirmed at `app/models/table_monitor.rb:337`, directly above the AASM block |
| 05 raw-GitHub-broken links in `docs/README.en.md` | plain `.md` links (lines 9–25, 91–106) vs actual `.en.md`/`.de.md` files — confirmed |

The "billards" typo was NOT drafted (handled by Task 3, per plan decision). Automated verify passed: `OK (5 drafts)`.

### Task 3 — GitHub repo metadata (executed, approved)

- Before: `A billards management suite` / homepage empty.
- After (read back via `gh repo view`): description `Open-source tournament & club management for billiards (carom, pool, snooker) — live scoreboards, league play, ClubCloud sync, AI assistant`, homepage `https://gernotullrich.github.io/carambus`.
- Automated verify passed: `OK`. No auth gate encountered.

## Deviations from Plan

**1. [Constraint override] Commit made BEFORE the human-verify checkpoint, not after**
- **Found during:** Task 1 / Task 4 ordering
- **Issue:** The plan's `<output>` section schedules the commit after checkpoint approval; the orchestrator constraints explicitly override this ("DO commit the new files — an uncommitted worktree cannot be merged back").
- **Fix:** README.md + CONTRIBUTING.md committed as `bc29edb2`; review happens via the commit.
- **Files modified:** README.md, CONTRIBUTING.md

**2. [Rule 3 - Scope clarification] Issue drafts + task directory not committed**
- **Found during:** Task 2
- **Issue:** Plan `<output>` says `git add … .planning/quick/260702-tvf…/`, but `.planning/quick/` is gitignored (`.gitignore:76`) and orchestrator constraints forbid committing PLAN/SUMMARY artifacts.
- **Fix:** Drafts remain local files in `issue-drafts/` — exactly the "files only, unposted" state the constraints require.

Otherwise: plan executed as written.

## Awaiting Human Review (Task 4 checkpoint — prepared, not waited on)

1. **README.md** (commit `bc29edb2`): open in a Markdown preview — check hero tone, that the 3 screenshots render, DE link (`docs/README.de.md`) and docs-site link (`https://GernotUllrich.github.io/carambus`) work.
2. **CONTRIBUTING.md** (same commit): confirm setup commands match your machine and the local-vs-global explanation is accurate.
3. **Issue drafts**: review the 5 files in `.planning/quick/260702-tvf-github-auftritt-verbessern-readme-contri/issue-drafts/` and decide which to post (posting = separate manual step, e.g. `gh issue create --title … --body-file … --label "good first issue" --label "help wanted"`).
4. **Repo metadata**: `gh repo view GernotUllrich/carambus --web` — confirm new description + homepage on the repo page.
5. **Push** (user does this himself, per project memory): `git push origin master` — after the worktree branch is merged back to master by the orchestrator.

## Known Stubs

None — no code stubs; issue drafts are intentionally unposted per plan.

## Threat Flags

None — documentation files and repo metadata only; no code, endpoints, auth paths, or schema changes.

## Self-Check: PASSED

- README.md exists: FOUND
- CONTRIBUTING.md exists: FOUND
- 5 issue-draft files exist: FOUND
- Commit `bc29edb2` exists: FOUND
- All 3 README screenshot paths exist on disk: FOUND
- Pre-existing dirty file `.claude/settings.local.json` not staged/committed: CONFIRMED (`git show --stat bc29edb2` lists only README.md + CONTRIBUTING.md)
- gh metadata read-back matches locked decision: CONFIRMED
