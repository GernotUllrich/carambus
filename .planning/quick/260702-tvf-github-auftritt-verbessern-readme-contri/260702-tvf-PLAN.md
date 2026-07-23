---
phase: quick-260702-tvf
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - README.md
  - CONTRIBUTING.md
  - .planning/quick/260702-tvf-github-auftritt-verbessern-readme-contri/issue-drafts/*.md
autonomous: false
requirements: [GITHUB-PRESENCE-01]
must_haves:
  truths:
    - "Repo root has an English README.md that a GitHub visitor sees on the landing page"
    - "README hero explains what Carambus is and why, with a link to the German version"
    - "README shows 2-3 screenshots via relative repo paths that render on GitHub"
    - "Repo root has an English CONTRIBUTING.md with runnable dev setup, test, and lint commands"
    - "CONTRIBUTING explains the local-vs-global record concept (LocalProtector, MIN_ID)"
    - "3-5 good-first-issue draft markdown files exist in issue-drafts/ (NOT posted to GitHub)"
    - "GitHub repo description and homepage are updated via gh CLI"
  artifacts:
    - path: "README.md"
      provides: "GitHub landing README (English, hero + screenshots + features + architecture + quickstart + license)"
      min_lines: 50
    - path: "CONTRIBUTING.md"
      provides: "Contributor onboarding (setup, tests, lint, local-vs-global, contact)"
      min_lines: 40
    - path: ".planning/quick/260702-tvf-github-auftritt-verbessern-readme-contri/issue-drafts/"
      provides: "3-5 drafted good-first-issue markdown files"
  key_links:
    - from: "README.md"
      to: "docs/README.de.md"
      via: "markdown link near top"
      pattern: "docs/README\\.de\\.md"
    - from: "README.md"
      to: "docs/screenshots/*.png"
      via: "relative image reference"
      pattern: "docs/screenshots/"
    - from: "README.md"
      to: "https://GernotUllrich.github.io/carambus"
      via: "docs-site link"
      pattern: "github\\.io/carambus"
---

<objective>
Improve the GitHub presence of the Carambus repo (GernotUllrich/carambus): create a
root README.md (English, GitHub convention) and CONTRIBUTING.md (English), draft 3-5
real good-first-issue markdown files for user approval, and update the repo description
and homepage via gh CLI.

Purpose: The repo currently has NO root README and NO CONTRIBUTING file, a typo'd
one-line description ("A billards management suite"), null homepage, and 0 stars/forks.
A first-time visitor lands on a bare file tree. This makes the project look abandoned
and unapproachable despite being production-grade and live since 2022. A strong README +
CONTRIBUTING + curated first-issue drafts turn the landing page into an on-ramp.

Output: README.md, CONTRIBUTING.md (both new files at repo root), issue-drafts/*.md in
the task directory, and updated GitHub repo metadata.
</objective>

<execution_context>
Work mode for this task: **master mode** (editing carambus_nbv checkout, which shares
origin git@github.com:GernotUllrich/carambus.git on branch master). Per project memory:
Claude commits in master mode but does NOT push to the default branch — the user pushes
himself. Offer the push command at the end; do not run it.

Per scenario-management SKILL: only NEW files (README.md, CONTRIBUTING.md) plus task
artifacts are created. Do NOT touch or stage the pre-existing dirty working-tree files
`db/schema.rb` and `.claude/settings.local.json`.
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@docs/README.de.md
@docs/README.en.md

<facts>
Verified by orchestrator + planner (do NOT re-research):

Repo state:
- Working dir /Users/gullrich/DEV/carambus/carambus_nbv, branch master, shares origin
  git@github.com:GernotUllrich/carambus.git. Default branch on GitHub: master.
- Repo root confirmed to have NO README.md and NO CONTRIBUTING.md (both absent).
- GitHub: 0 stars, 0 forks, description "A billards management suite" (typo), homepage
  null, MIT license. Labels "good first issue" and "help wanted" already exist.
- ALL 15 open issues are Dependabot bumps — NO real curated issues exist. Therefore
  good-first-issue candidates are DRAFTED (files), NOT posted.
- Pre-existing dirty files: db/schema.rb, .claude/settings.local.json — MUST NOT be
  touched or committed.

Project facts for README content:
- Rails 7.2 / Ruby 3.2.1 / PostgreSQL / Redis. Real-time scoreboards for carom/pool/
  snooker (Hotwire/Turbo, StimulusReflex, ActionCable). Tournament + league management.
  Bidirectional ClubCloud (DBU) sync. AI chat assistant for Sportwarte (MCP tools).
  Scenario-based multi-tenant deployment: central API server api.carambus.de + local
  club servers (Raspberry Pi supported). In production at Billardclub Wedel 61 e.V.
  since 2022. Central DB: 17 seasons — 66,860 players, 313,509 games, 18,384 tournaments.
  MIT license.

Screenshots available (relative paths, render on GitHub):
- docs/screenshots/pool_14_1_scoreboard_playing.png
- docs/screenshots/pool_tables_overview.png
- docs/screenshots/pool_quickstart_full.png
- docs/screenshots/pool_14_1_scoreboard_start.png, pool_14_1_after_switch.png,
  pool_quickstart_buttons.png
- docs/managers/images/tournament-wizard-overview.png,
  tournament-monitor-landing.png, tournament-wizard-mode-selection.png

Docs site: https://GernotUllrich.github.io/carambus (mkdocs, bilingual under docs/).
NOTE: docs/README.en.md links use plain `.md` names (e.g. installation-overview.md)
which the mkdocs i18n plugin resolves at build time from `.en.md` files — these links
work in the built site but NOT in raw GitHub. Do not copy those relative links verbatim
into README.md; link to the built docs site (github.io) or to files that actually exist.

Dev commands (from CLAUDE.md, verified: Procfile.dev + package.json build scripts exist):
- Run: foreman start -f Procfile.dev  (or bin/rails server)
- Tests (Minitest): bin/rails test ; bin/rails test:critical ; single file/line forms
- Lint: bundle exec standardrb ; bundle exec erblint --lint-all ; bundle exec brakeman --no-pager
- DB: bin/rails db:migrate ; SAFETY_ASSURED=true bin/rails db:test:prepare
- Assets: yarn build / yarn build:css (esbuild + tailwind)

Local-vs-global concept (from CLAUDE.md, for CONTRIBUTING):
- Records with id < 50_000_000 (MIN_ID) are "global" (synced from central API);
  id >= MIN_ID are local. LocalProtector concern guards global records from local
  modification. In tests LocalProtector is disabled via LocalProtectorTestOverride.

Contact: GitHub issues + email gernot.ullrich@gmx.de (per docs/README.de.md, NOT the
gmail in git config).

Verified REAL good-first-issue candidates (Task 2 executor picks 3-5, re-verifies each):
- i18n EN gaps: config/locales/de.yml has 118 top-level keys, en.yml has 114; subtrees
  notification / locales / views present in de but absent in en (verified via YAML diff).
- No config sample for onboarding: config/database.yml exists but there is NO
  config/database.yml.example / .env.example (verified). CLAUDE.md documents env vars
  (REDIS_URL, DEEPL_API_KEY, OPENAI_API_KEY, SMTP_*) with no template file.
- Hardcoded string flagged for i18n: app/models/table_monitor.rb:337 `# TODO: I18n`
  above the AASM state block (verified present).
- Raw-GitHub broken doc links: docs/README.en.md links to `.md` names that only resolve
  in the mkdocs-built site, not on GitHub (verified — mkdocs i18n plugin in mkdocs.yml).
- Repo typo "billards" in GitHub description — this is fixed by Task 3 metadata update,
  so per D-decision it is NOT a valid issue draft (too trivial / already handled).
</facts>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Write root README.md and CONTRIBUTING.md (English)</name>
  <files>README.md, CONTRIBUTING.md</files>
  <action>
Create two NEW files at the repo root using the Write tool.

**README.md** (English, GitHub convention). Structure per locked decision:
1. Title + one-line tagline. Immediately below the title, a prominent link:
   "🇩🇪 Auf Deutsch lesen: [docs/README.de.md](docs/README.de.md)". (The German doc is
   the docs-directory landing page; that is acceptable as the DE entry point.)
2. Hero paragraph: what Carambus is (open-source tournament & club management for
   billiards — carom, pool, snooker) and why (live scoreboards, league play, ClubCloud
   sync, AI assistant for Sportwarte). Mention "in production at Billardclub Wedel 61
   e.V. since 2022" here or in a dedicated one-liner.
3. 2-3 screenshots via RELATIVE repo paths (these render on GitHub). Use:
   docs/screenshots/pool_14_1_scoreboard_playing.png,
   docs/screenshots/pool_tables_overview.png,
   docs/managers/images/tournament-wizard-overview.png. Give each an alt text.
4. Feature overview: compact bullet list (real-time scoreboards; tournament & league
   management; bidirectional ClubCloud/DBU sync; AI chat assistant via MCP tools;
   scenario-based multi-tenant deployment incl. Raspberry Pi). Link to the docs site
   https://GernotUllrich.github.io/carambus for detail — do NOT duplicate the full
   feature matrix here.
5. Architecture one-liner: central API server (api.carambus.de) holding shared data +
   local club servers that sync from it (LocalProtector guards global records).
   Optionally cite scale: 17 seasons, ~66,860 players, ~313,509 games, ~18,384
   tournaments in the central DB.
6. Tech stack one-liner: Rails 7.2, Ruby 3.2, PostgreSQL, Redis, Hotwire/Turbo +
   StimulusReflex + ActionCable.
7. Quickstart pointer: link to the docs site + to CONTRIBUTING.md for local dev setup.
   Do NOT paste the full setup here (that lives in CONTRIBUTING).
8. Contributing pointer: "See [CONTRIBUTING.md](CONTRIBUTING.md)".
9. License: MIT.

Keep it scannable and honest. Do NOT invent badges for CI/coverage that don't exist.
A MIT license badge and a "docs" link badge are fine. Do NOT reuse docs/README.en.md
verbatim (that is a docs-directory index, not a repo landing page) and do NOT copy its
`.md` relative links (they break on raw GitHub — link to github.io instead).

**CONTRIBUTING.md** (English). Structure per locked decision:
1. Short welcome + note that AI-assisted development is explicitly welcome.
2. Prerequisites: Ruby 3.2.1, PostgreSQL, Redis, Node.js (for yarn/esbuild).
3. Dev setup steps: git clone; bundle install; yarn install; set up config/database.yml
   (note the app also reads config/carambus.yml); bin/rails db:create db:migrate;
   run with `foreman start -f Procfile.dev` (full stack) or `bin/rails server`.
4. Running tests: `bin/rails test` (all), `bin/rails test:critical` (concerns +
   scraping), single-file `bin/rails test test/path_test.rb`, single-line
   `bin/rails test test/path_test.rb:NN`. Note Minitest (not RSpec).
5. Linting: `bundle exec standardrb` (Ruby), `bundle exec erblint --lint-all` (ERB),
   `bundle exec brakeman --no-pager` (security).
6. Key concept — local vs global records: explain id < 50_000_000 (MIN_ID) = "global"
   records synced from the central API; id >= MIN_ID = local; LocalProtector guards
   global records from local modification; in tests it is disabled via
   LocalProtectorTestOverride. This is essential context for anyone touching model saves.
7. Conventions: conventional commit messages; frozen_string_literal in Ruby files;
   German for business-logic comments, English for technical terms (cite CLAUDE.md).
8. Where to ask questions: open a GitHub issue, or email gernot.ullrich@gmx.de.

Both files: English prose, clear headings, no emojis-as-decoration overload (a few
section emoji markers matching the docs style are acceptable but keep it professional).
  </action>
  <verify>
    <automated>test -f README.md && test -f CONTRIBUTING.md && grep -q "docs/README.de.md" README.md && grep -q "docs/screenshots/" README.md && grep -q "github.io/carambus" README.md && grep -qi "MIT" README.md && grep -q "50_000_000\|MIN_ID\|LocalProtector" CONTRIBUTING.md && grep -q "foreman start -f Procfile.dev" CONTRIBUTING.md && grep -q "standardrb" CONTRIBUTING.md && grep -q "gernot.ullrich@gmx.de" CONTRIBUTING.md && echo OK</automated>
  </verify>
  <done>
README.md and CONTRIBUTING.md exist at repo root. README has: DE link, ≥2 relative
screenshot references, docs-site link, feature/architecture/quickstart sections, MIT
license. CONTRIBUTING has: prerequisites, setup, test commands, lint commands, the
local-vs-global (MIN_ID/LocalProtector) explanation, contact email. Referenced
screenshot files all exist on disk (no broken image paths).
  </done>
</task>

<task type="auto">
  <name>Task 2: Draft 3-5 real good-first-issue markdown files</name>
  <files>.planning/quick/260702-tvf-github-auftritt-verbessern-readme-contri/issue-drafts/</files>
  <action>
Create an `issue-drafts/` subdirectory in the task directory and write 3-5 markdown
files, one per drafted good-first-issue. These are DRAFTS for user approval — do NOT
post them to GitHub.

Each file MUST be a REAL, small, self-contained task (verify it is real before writing
the draft — briefly inspect the codebase to confirm the gap still exists). Pick 3-5 from
these pre-verified candidates (re-confirm each with a quick grep/ls/YAML check):

1. **i18n: fill English translation gaps in config/locales/en.yml** — de.yml (118
   top-level keys) has subtrees `notification`, `locales`, `views` that en.yml (114
   keys) lacks. Scope the draft to ONE small subtree (e.g. `notification`) so it stays
   beginner-sized. Re-verify with the YAML top-level diff.
2. **Add config/database.yml.example** — there is no example/sample DB config; new
   contributors must reverse-engineer config/database.yml. A committed
   database.yml.example (with placeholder credentials) is a classic first PR. Re-verify
   the example file is absent.
3. **Add .env.example documenting optional env vars** — CLAUDE.md documents REDIS_URL,
   DEEPL_API_KEY, OPENAI_API_KEY, SMTP_USERNAME/PASSWORD but no template exists.
   Re-verify absence.
4. **Replace hardcoded string flagged `# TODO: I18n`** at app/models/table_monitor.rb:337
   — a small, well-scoped i18n cleanup. Re-verify the TODO marker still exists.
5. **Fix raw-GitHub-broken doc links in docs/README.en.md** — links to `.md` names that
   only resolve in the mkdocs-built site (via the i18n plugin), not on GitHub. Draft:
   make the docs index links robust for both raw-GitHub and built-site viewing. Re-verify
   the plain-`.md` links still exist and the target files carry `.en.md`/`.de.md` suffixes.

Do NOT draft the "fix billards typo in repo description" as an issue — it is trivial and
already handled by Task 3's metadata update.

Each draft file format (filename like `01-i18n-notification-en-gap.md`):
```
# <Concise issue title>

**Labels:** good first issue, help wanted

## Summary
<1-2 sentence problem statement>

## Why it matters
<why this helps the project / a newcomer>

## Where
<exact files/paths/line numbers>

## Suggested approach
<numbered concrete steps a newcomer can follow>

## Definition of done
<verifiable acceptance criteria — e.g. a command that passes>
```

Write 3-5 such files. Prefer the strongest 3-5 candidates; quality over quantity.
  </action>
  <verify>
    <automated>d=".planning/quick/260702-tvf-github-auftritt-verbessern-readme-contri/issue-drafts"; n=$(ls "$d"/*.md 2>/dev/null | wc -l | tr -d ' '); test "$n" -ge 3 && test "$n" -le 5 && grep -rql "good first issue" "$d" && grep -rql "Definition of done" "$d" && echo "OK ($n drafts)"</automated>
  </verify>
  <done>
3-5 markdown files exist in issue-drafts/, each with a title, suggested labels
(good first issue / help wanted), where (exact paths), suggested approach, and a
verifiable definition of done. Every drafted issue was re-verified against the live
codebase as a REAL gap (not invented). Files are NOT posted to GitHub.
  </done>
</task>

<task type="auto">
  <name>Task 3: Update GitHub repo metadata via gh CLI</name>
  <files>(no local files — GitHub API via gh)</files>
  <action>
Update the repo description and homepage using the gh CLI (this is explicitly allowed to
execute directly). Set exactly (per locked decision):

- Description: "Open-source tournament & club management for billiards (carom, pool, snooker) — live scoreboards, league play, ClubCloud sync, AI assistant"
- Homepage: https://gernotullrich.github.io/carambus

Command:
`gh repo edit GernotUllrich/carambus --description "Open-source tournament & club management for billiards (carom, pool, snooker) — live scoreboards, league play, ClubCloud sync, AI assistant" --homepage "https://gernotullrich.github.io/carambus"`

If gh returns an auth error, create a checkpoint asking the user to run `gh auth login`,
then retry — do NOT ask the user to edit the metadata manually in the browser (gh can do
it). After success, read back the values to confirm.
  </action>
  <verify>
    <automated>gh repo view GernotUllrich/carambus --json description,homepageUrl -q '.description + " | " + .homepageUrl' | grep -q "live scoreboards" && gh repo view GernotUllrich/carambus --json homepageUrl -q .homepageUrl | grep -qi "gernotullrich.github.io/carambus" && echo OK</automated>
  </verify>
  <done>
GitHub repo description reads the new billiards tagline (typo "billards" gone) and
homepage is set to https://gernotullrich.github.io/carambus, confirmed via
`gh repo view`.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 4: Human review — README, CONTRIBUTING, issue drafts, repo metadata</name>
  <action>Pause for user review of the artifacts before committing. See <what-built>, <how-to-verify>, and <resume-signal> below.</action>
  <what-built>
Root README.md + CONTRIBUTING.md (English), 3-5 good-first-issue draft files in
issue-drafts/, and updated GitHub repo description + homepage.
  </what-built>
  <how-to-verify>
1. Open README.md in a Markdown preview (or push a branch and view on GitHub) — confirm
   the hero reads well, the 3 screenshots render, the DE link and docs-site link work,
   and the tone represents the project well.
2. Skim CONTRIBUTING.md — confirm the dev setup commands are correct for your machine and
   the local-vs-global explanation is accurate.
3. Review the 3-5 files in
   .planning/quick/260702-tvf-github-auftritt-verbessern-readme-contri/issue-drafts/ —
   approve which ones (if any) should be posted to GitHub as real issues. (Posting is a
   separate manual/gh step you trigger after approval — this task does NOT post them.)
4. Run `gh repo view GernotUllrich/carambus --web` (or refresh the repo page) to confirm
   the new description and homepage.
  </how-to-verify>
  <resume-signal>Type "approved" (optionally note which issue drafts to post), or describe changes.</resume-signal>
</task>

</tasks>

<verification>
- README.md and CONTRIBUTING.md exist at repo root, English, with all required sections.
- All screenshot paths referenced in README.md exist on disk (no broken images).
- 3-5 issue drafts exist, each a re-verified real gap, none posted to GitHub.
- GitHub description + homepage updated and confirmed via gh.
- Pre-existing dirty files db/schema.rb and .claude/settings.local.json were NOT staged
  or committed.
</verification>

<success_criteria>
- A first-time GitHub visitor sees a compelling English README with screenshots,
  feature/architecture overview, docs-site link, DE-version link, and MIT license.
- Contributors have a runnable CONTRIBUTING.md (setup + tests + lint + local-vs-global).
- 3-5 real good-first-issue drafts await user approval in issue-drafts/.
- Repo metadata (description without the "billards" typo, homepage) is live.
- Only NEW files + task artifacts committed with a conventional commit message; NOT
  pushed (user pushes master himself).
</success_criteria>

<output>
After the checkpoint is approved, commit only the new files with a conventional message,
e.g.:

`git add README.md CONTRIBUTING.md .planning/quick/260702-tvf-github-auftritt-verbessern-readme-contri/`
`git commit` with message:
  docs: add root README + CONTRIBUTING and draft good-first-issues

  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>

Do NOT run `git push` — offer the user the command:
  git push origin master

Then create a SUMMARY at
`.planning/quick/260702-tvf-github-auftritt-verbessern-readme-contri/260702-tvf-SUMMARY.md`.
</output>
