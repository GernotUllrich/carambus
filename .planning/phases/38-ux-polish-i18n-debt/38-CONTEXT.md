# Phase 38: UX Polish & i18n Debt - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Close 5 of the 6 v7.1 requirements (UX-POL-01, UX-POL-02, UX-POL-03, I18N-01, I18N-02)
on volunteer-facing wizard + tournament_monitor screens:

- Wizard `<details>` help blocks and inline-styled info banners are readable in dark mode
  (UX-POL-01 / G-01)
- 16 tooltipped labels on `tournament_monitor.html.erb` get a visible affordance
  (UX-POL-02 / G-03)
- EN locale `table_monitor.status.warmup*` keys say "Warm-up" instead of "Training"
  (I18N-01 / G-05)
- Hardcoded German strings in `app/views/tournaments/` (excluding the Phase 36B parameter
  form) are covered by `t(...)` under `tournaments.monitor.*` + `tournaments.show.*`
  (I18N-02 / G-04)
- Phase 36B Wizard Header Test 1 is explicitly reconfirmed via a manual UAT after the
  G-01 fix ships (UX-POL-03)

**DATA-01 is NOT in Phase 38.** The discuss-phase surfaced that the hardcoded
`DISCIPLINE_PARAMETER_RANGES` approach is redundant with the existing
`discipline_tournament_plans` table, and that the right fix is a DTP-backed rewrite of
`Discipline#parameter_ranges` — significantly larger than a "widen hardcoded constants"
plan. DATA-01 is therefore spun off to a new **Phase 39 (DTP-backed parameter ranges)**
under milestone v7.1. Phase 38 ships with only 2 plans instead of the roadmap's original 3.

</domain>

<decisions>
## Implementation Decisions

### Scope shape
- **D-01:** Phase 38 ships **2 plans** (38-01 quick wins bundle, 38-02 tournament views
  i18n audit). Plan 38-03 (parameter_ranges widening) is deleted — DATA-01 moves to a
  new Phase 39.
- **D-02:** Phase 39 (new) handles DATA-01 in isolation via a DTP-backed rewrite — see
  §"DATA-01 → Phase 39" below. Roadmap update is a post-discuss-phase step, not part of
  this CONTEXT.md.

### G-01: Dark-mode contrast (UX-POL-01)
- **D-03:** Replace inline `style="background: #dff0d8; …"` on
  `_wizard_steps_v2.html.erb:167, 215, 268` with Tailwind
  `bg-green-50 dark:bg-green-900/30 border border-green-600 dark:border-green-500 text-green-900 dark:text-green-100`
  per seed fix sketch. Planner verifies all three lines use a compatible green scheme;
  lines with different source colors get matching Tailwind variants.
- **D-04:** Audit `tournament_wizard.css:287-295` (`html.dark .step-help p` rule)
  via DevTools to confirm the rule actually takes effect post-fix. If specificity is
  clobbered by Tailwind defaults, bump specificity or convert to `@apply`.
- **D-05:** Scope stays on the wizard surface only — no dark-mode audit of league views,
  player profiles, or admin dashboards (explicitly Out of Scope per REQUIREMENTS.md).

### G-03: Tooltip affordance (UX-POL-02)
- **D-06:** Create a new file `app/assets/stylesheets/components/tooltip.css` containing
  the affordance rule. Register via `@import` in `application.tailwind.css` alongside the
  other `components/*.css` imports (around line 29, matching the existing pattern).
- **D-07:** Rule starts as `[data-controller~="tooltip"] { cursor: help; border-bottom:
  1px dashed currentColor; padding-bottom: 1px; }`. **During planning/execution,
  Claude audits all `[data-controller~="tooltip"]` occurrences in
  `tournament_monitor.html.erb` (expected ≈16 sites) and narrows the selector if the
  broad form bleeds into nested form controls.**
- **D-08:** No ERB changes — CSS-only fix, auto-applies to all 16 existing tooltipped
  labels + any future ones.

### I18N-01: Warm-up EN translation (G-05)
- **D-09:** 3-line edit in `config/locales/en.yml:844-846`:
  - `warmup: Warm-up`
  - `warmup_a: Warm-up Player A`
  - `warmup_b: Warm-up Player B`
- **D-10:** **Do NOT touch `en.yml:387`** (`training: Training`). That key is the
  "Training Game" / practice-tournament concept, a different semantic from the
  scoreboard warm-up phase.

### I18N-02: Tournament views i18n audit (G-04)
- **D-11:** Audit scope = **full `app/views/tournaments/` sweep** (23 ERB files),
  explicitly excluding `_wizard_steps_v2.html.erb` which is already i18n'd from Phase 36B.
- **D-12:** New i18n keys use a two-namespace structure:
  - `tournaments.monitor.*` for `tournament_monitor.html.erb` and tournament_monitor-
    adjacent partials (_tournament_status, _groups, _bracket, etc. that render during
    the post-start surface).
  - `tournaments.show.*` for `show.html.erb` / `_show.html.erb` / `_admin_tournament_info`
    and any strings visible in the tournament detail page.
  - Edit/new/admin-only views (`edit.html.erb`, `new.html.erb`, `compare_seedings.html.erb`,
    `parse_invitation.html.erb`, `new_team.html.erb`, `define_participants.html.erb`,
    `finalize_modus.html.erb`) also get keys under `tournaments.<action>.*` — planner
    picks the namespace per file based on which existing `tournaments.*` subtree is
    closest.
- **D-13:** Grep strategy: `grep -rn 'Aktuelle\|Turnier\|Starte\|zurück' app/views/tournaments/ | grep -v "t('"`
  as the starting point, plus a broader pass for any German string (A-ZÄÖÜäöüß…) not
  already inside a `t(...)` or `t(".")` call. Planner enumerates findings, user reviews
  grep output before plan writes.
- **D-14:** **DE + EN added simultaneously in the same plan commit.** DE is authoritative;
  EN is a direct translation Claude writes (no AI translation service — these are short
  UI labels). Both `config/locales/de.yml` and `config/locales/en.yml` updated in one
  commit per key batch.
- **D-15:** Phase 36B parameter form keys (already under `tournaments.parameter_*`
  namespace from Phase 36B) are NOT touched — that surface is already fully i18n'd.

### UX-POL-03: Phase 36B Test 1 retest
- **D-16:** Retest is a **manual UAT pass** executed after the G-01 fix has been
  committed. No automated system test added in Phase 38 — the retest is a one-shot
  confirmation, not a permanent regression guard.
- **D-17:** Evidence artifact = `.planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md`
  written by the executor/human following the Phase 36B UAT template. Criteria to confirm:
  1. Dominant AASM state badge (colored 2xl badge visible at top of wizard header)
  2. 6 bucket chips present and rendered correctly
  3. NO "Schritt N von 6" text anywhere in the header
  4. NO numeric step prefixes on step labels
  5. (Bonus) help `<details>` block is now readable in dark mode — ties the retest to
     the G-01 fix having landed.
- **D-18:** Retest is scheduled inside Plan 38-01 as a final task — after G-01 CSS
  change + Test 1 retest both ship, Plan 38-01 is complete.

### DATA-01 → Phase 39 (spun off, NOT in Phase 38)
- **D-19:** DATA-01 is removed from Phase 38 scope. A new Phase 39 will rewrite
  `Discipline#parameter_ranges` to query `discipline_tournament_plans` instead of
  hardcoded constants. This decision is logged here for traceability but **implemented
  in a separate phase** — no Phase 38 plan changes `discipline.rb`.
- **D-20:** Phase 39 approach (sketch, for roadmap update): `Discipline#parameter_ranges(tournament:)`
  takes a Tournament argument, queries `DisciplineTournamentPlan.where(discipline: self,
  tournament_plan: tournament.tournament_plan, players: ..., player_class: tournament.player_class)`,
  and returns a hash with `points` → `Range` and `innings` → `Range`. Normal mode =
  exact canonical value ±small slack; reduced mode (20%-less) = `(points*0.8).floor..points`.
  For `tournament.handicap_tournier == true`: innings check skipped (0 = no innings limit),
  balls_goal range widened or skipped because it's per-participant. For disciplines
  without a DTP entry (Pool, Snooker, Kegel, Biathlon, 5-Kegel): hardcoded fallback
  table — or, if fallback proves too narrow, returns empty hash = "no check" like today.
- **D-21:** Roadmap + REQUIREMENTS.md must be updated to move DATA-01 out of Phase 38's
  requirement list and into a new Phase 39. That update is a post-discuss-phase task
  (likely a `/gsd-insert-phase 39` invocation, or a manual ROADMAP.md edit followed by
  `/gsd-plan-phase 39`).

### Claude's Discretion
- Exact Tailwind class names if the inline styles on lines 215 and 268 use different
  base colors than line 167 (the seed assumed all green-variant; verify and match per
  line).
- Tooltip selector narrowing if the broad `[data-controller~="tooltip"]` rule bleeds
  into nested form controls (D-07).
- Which tournaments.*.* namespace each admin/edit view uses (D-12) — planner picks
  based on existing i18n tree proximity.
- Grep patterns for the broader i18n sweep beyond the initial 4-word list (D-13).
- Exact EN translations for new keys (D-14) — straightforward UI labels, no DeepL/OpenAI.
- UAT artifact formatting — follows the Phase 36B template but exact wording is free.

### Folded Todos
None — STATE.md reports zero pending todos at discuss-phase time. The one todo matching
this phase (`.planning/todos/pending/2026-04-14-recalibrate-discipline-parameter-ranges-bounds.md`)
is scoped to DATA-01 and therefore moves with DATA-01 to Phase 39.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone scope and origin
- `.planning/REQUIREMENTS.md` — v7.1 requirements UX-POL-01..03, I18N-01..02, DATA-01
  with fix sketches and source-gap mapping
- `.planning/ROADMAP.md` §"Phase 38: UX Polish & i18n Debt" — original phase scope and
  plan breakdown (will be updated to reflect the DATA-01 → Phase 39 split)
- `.planning/seeds/v71-ux-polish-i18n-debt.md` — seed document with fix sketches for
  G-01/G-03/G-04/G-05/G-06 and rough sizing
- `.planning/PROJECT.md` §"Current Milestone" + §"Constraints" — volunteer persona
  filter, behavior preservation scope

### Phase 36B provenance (prior art + Test 1 retest source)
- `.planning/milestones/v7.0-phases/36B-ui-cleanup-kleine-features/36B-HUMAN-UAT.md`
  — full Gap G-01..G-06 details with root cause and evidence
- `.planning/milestones/v7.0-phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md` §D-17
  — authorized the first-pass hardcoded `parameter_ranges` (the thing DATA-01 is fixing)
- `.planning/milestones/v7.0-phases/36B-ui-cleanup-kleine-features/36B-06-parameter-verification-PLAN.md`
  — Phase 36B's plan that introduced `DISCIPLINE_PARAMETER_RANGES`, useful reference
  for Phase 39 but NOT for Phase 38

### Phase 37 provenance (doc links inside help blocks)
- `.planning/phases/37-in-app-doc-links/37-CONTEXT.md` §D-11 — placement decision that
  made G-01 visible (doc links land inside the `<details>` help block that has the
  dark-mode contrast bug)

### G-01 target files (Plan 38-01)
- `app/views/tournaments/_wizard_steps_v2.html.erb:167` — primary inline-style site
- `app/views/tournaments/_wizard_steps_v2.html.erb:215` — second inline-style site (audit)
- `app/views/tournaments/_wizard_steps_v2.html.erb:268` — third inline-style site (audit)
- `app/assets/stylesheets/tournament_wizard.css:287-295` — `html.dark .step-help p`
  specificity audit target

### G-03 target files (Plan 38-01)
- `app/views/tournaments/tournament_monitor.html.erb` — 16 existing `data-controller~="tooltip"`
  sites, selector audit source
- `app/javascript/controllers/tooltip_controller.js` — Phase 36B Stimulus controller
  that sets the `data-controller` attribute (reference only, not modified)
- `app/assets/stylesheets/application.tailwind.css:11-29` — `@import` section where the
  new `components/tooltip.css` registers
- `app/assets/stylesheets/components/` — existing component CSS directory (pattern to
  follow for the new `tooltip.css` file)

### I18N-01 target file (Plan 38-01)
- `config/locales/en.yml:844-846` — 3-line edit target (`warmup: Warm-up`,
  `warmup_a: Warm-up Player A`, `warmup_b: Warm-up Player B`)
- `config/locales/en.yml:387` — **DO NOT TOUCH** — `training: Training` is the
  practice-tournament concept, different semantic from the scoreboard warm-up phase

### I18N-02 target files (Plan 38-02)
- `app/views/tournaments/` — 23 ERB files in the audit scope:
  - `_admin_tournament_info.html.erb`, `_balls_goal.html.erb`, `_bracket.html.erb`,
    `_form.html.erb`, `_groups.html.erb`, `_groups_compact.html.erb`,
    `_party_record.html.erb`, `_search.html.erb`, `_show.html.erb`,
    `_tournament_status.html.erb`, `_tournaments_table.html.erb`, `_wizard_step.html.erb`,
    `compare_seedings.html.erb`, `define_participants.html.erb`, `edit.html.erb`,
    `finalize_modus.html.erb`, `index.html.erb`, `new.html.erb`, `new_team.html.erb`,
    `parse_invitation.html.erb`, `show.html.erb`, `tournament_monitor.html.erb`
  - **Excluded:** `_wizard_steps_v2.html.erb` (already fully i18n'd from Phase 36B)
- `config/locales/de.yml` §`tournaments.*` — existing DE keys tree; new keys land under
  `tournaments.monitor.*` / `tournaments.show.*`
- `config/locales/en.yml` §`tournaments.*` — existing EN keys tree; new keys land in
  matching positions

### DATA-01 → Phase 39 source (NOT modified in Phase 38)
- `app/models/discipline.rb:50-94` — current hardcoded `DISCIPLINE_PARAMETER_RANGES` +
  `parameter_ranges` method — **untouched in Phase 38**
- `app/models/discipline_tournament_plan.rb` — DTP model, Phase 39 data source
- `app/models/tournament.rb:24-32` — `handicap_tournier:boolean` + `player_class:string`
  columns used by Phase 39 dispatch logic
- `http://0.0.0.0:3007/discipline_tournament_plans` — administrate dashboard for DTP
  inspection (reference only)

### Test coverage reference
- `test/models/discipline_test.rb` — existing `parameter_ranges` tests (Phase 39 must
  update these when Discipline API changes)
- `test/system/tournament_parameter_verification_test.rb:27,115,117` — Phase 36B system
  test that asserts parameter verification behavior — will need updates in Phase 39

### Codebase maps (project-level context)
- `.planning/codebase/STRUCTURE.md` — project layout
- `.planning/codebase/CONVENTIONS.md` — naming + style conventions
- `.planning/codebase/STACK.md` — gem and runtime inventory

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Tailwind dark: variant support** — already wired project-wide via `application.tailwind.css`;
  G-01 fix just needs to use `dark:*` class suffixes, no new config
- **`app/assets/stylesheets/components/` directory + @import pattern** — established
  component file pattern for G-03's new `tooltip.css`. 14+ existing component files
  already follow this pattern
- **`t(...)` helper + `tournaments.*` i18n tree** — both `de.yml` and `en.yml` already
  have a substantial `tournaments:` subtree from prior phases; I18N-02 extends it
  rather than creating from scratch
- **Phase 36B parameter form i18n patterns** — reference for naming keys
  (`tournaments.parameter_*` subtree); I18N-02 should use similar conventions but under
  `tournaments.monitor.*` / `tournaments.show.*`
- **`discipline_tournament_plans` table + `DisciplineTournamentPlan` model** — the Phase 39
  data source. Has `points`, `innings`, `players`, `player_class`, `discipline_id`,
  `tournament_plan_id`. Populated for 12 disciplines (Karambol variants + Petit/Grand Prix +
  Nordcup). NOT used by Phase 38
- **Phase 36B Wizard Header Test 1 criteria** — already documented in Phase 36B UAT;
  UX-POL-03 just re-runs them

### Established Patterns
- **CSS component files go under `app/assets/stylesheets/components/` and register via
  `@import` in `application.tailwind.css`.** G-03 follows this pattern exactly.
- **Inline `style=` attributes on ERB are legacy** — the rest of the codebase prefers
  Tailwind utility classes; G-01 converts three sites to match.
- **i18n key paths mirror the view structure** with `tournaments.<action_or_section>.*`
  namespaces (e.g., `tournaments.parameter_*` from Phase 36B, `tournaments.docs.*` from
  Phase 37). I18N-02 adds `tournaments.monitor.*` and `tournaments.show.*`.
- **Phase 36B's Stimulus `tooltip_controller`** sets `data-controller="tooltip"` on target
  elements — G-03's CSS attribute selector targets that exact attribute.
- **Phase 36B UAT evidence artifacts** live inside the phase directory as `*-HUMAN-UAT.md`
  files. UX-POL-03 follows the same pattern (`38-UX-POL-03-UAT.md`).

### Integration Points
- G-01: modifies `_wizard_steps_v2.html.erb` only; no controller/helper/JS changes
- G-03: adds one CSS file + one `@import` line in `application.tailwind.css`; zero
  ERB or JS changes
- I18N-01: single 3-line `en.yml` edit; zero code changes
- I18N-02: edits `de.yml` + `en.yml` + 22 ERB files in `app/views/tournaments/`;
  controllers and helpers already delegate to `t(...)` so no controller changes needed
- UX-POL-03: zero code changes, pure manual test with artifact
- **No new routes, no new models, no new migrations** in Phase 38
- **Phase 39 (DATA-01, deferred)** will touch `discipline.rb`, `tournaments_controller.rb`
  (parameter verification callsite), and `test/models/discipline_test.rb` +
  `test/system/tournament_parameter_verification_test.rb`

</code_context>

<specifics>
## Specific Ideas

- **User domain insight (Vorgabeturniere):** for handicap tournaments (`Tournament#handicap_tournier == true`),
  `innings_goal` is always 0 (no innings limit) and `balls_goal` is per-participant from the
  participant list — NOT a single range-checkable value. This informs Phase 39's design but
  does NOT affect Phase 38.
- **User domain insight (reduced mode):** within a tournament, a "reduced" parameter mode
  exists that uses 80% of the normal discipline+plan values. Phase 39 will model this as a
  range `(points*0.8).floor..points` vs normal mode's exact-match check.
- **User domain insight (DTP as source of truth):** `discipline_tournament_plans` already
  holds the canonical `points`/`innings`/`players`/`player_class` combinations. Phase 39
  leverages this existing data instead of a new `discipline_parameter_ranges` table.
- **Seed-fix-sketches are authoritative** for G-01/G-03/G-05 exact classes/rules/values —
  planner copies verbatim from `v71-ux-polish-i18n-debt.md`.
- **Warm-up milestone intent** — Phase 38 stays tight, shippable in 1-2 days. If anything
  blows up scope (e.g., I18N-02 uncovering more than expected), the bigger slice moves to
  Phase 39 or a new phase. Polish milestone = ship polish, not refactor.

</specifics>

<deferred>
## Deferred Ideas

### Moved to Phase 39 (new phase to be inserted)
- **DATA-01: DTP-backed Discipline#parameter_ranges rewrite** — query
  `discipline_tournament_plans` instead of hardcoded `DISCIPLINE_PARAMETER_RANGES`
  constant. Handles normal/reduced modes, `handicap_tournier=true` special case, and
  hardcoded fallback for uncovered disciplines (Pool, Snooker, Kegel, Biathlon, 5-Kegel).
  Size estimate: 1-2 days. Requires roadmap update to insert Phase 39.

### Out-of-scope for v7.1 (explicitly deferred per REQUIREMENTS.md)
- **Long-term data-driven `parameter_ranges`** — nightly rake task populating ranges
  from historical tournament data across completed tournaments. Out of scope for Phase 39
  too; separate future phase or milestone.
- **Full `app/views/` i18n audit** beyond `app/views/tournaments/`. Non-tournament views
  (league, player, admin dashboards) are their own milestone.
- **Dark-mode audit for non-wizard screens** (league views, player profiles, admin
  dashboards) — scoped to wizard only.
- **`public/docs/` drift CI guard** — GitHub Actions-based guard in a separate quick
  task / small milestone after the failed 260415-26d overcommit hook attempt.
- **v7.2 ClubCloud Integration** — skeleton at `.planning/milestones/v7.2-*`
- **v7.3 Shootout / Stechen Support** — separate milestone

### Reviewed Todos (not folded)
- `.planning/todos/pending/2026-04-14-recalibrate-discipline-parameter-ranges-bounds.md`
  — scoped to DATA-01, therefore moves to Phase 39 along with DATA-01. Not dropped,
  just relocated out of Phase 38's surface.

</deferred>

---

*Phase: 38-ux-polish-i18n-debt*
*Context gathered: 2026-04-15*
