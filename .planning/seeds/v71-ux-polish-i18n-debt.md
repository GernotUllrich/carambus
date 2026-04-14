# Seed: v7.1 UX polish & i18n debt (G-01, G-03, G-04, G-05, G-06)

**Planted:** 2026-04-15 (during Phase 36B human UAT, v7.0)
**Source finding:** `.planning/phases/36B-ui-cleanup-kleine-features/36B-HUMAN-UAT.md` §Gaps
**Target milestone:** Next milestone kickoff (whichever version comes after v7.0 is archived).
**Scope estimate:** Small — 1 plan, a few hours.

## Problem

During the 2026-04-15 human UAT session for Phase 36B, six gaps surfaced. One (G-02) was
fixed inline. The other five are small, non-regression follow-ups that do NOT block v7.0
milestone completion but should land soon before they rot or accumulate more debt:

| Gap | Severity | Title | Fix size |
|-----|----------|-------|----------|
| **G-01** | medium | Dark-mode contrast in wizard `<details>` help block + inline-styled info banners | ~15 LOC CSS + audit |
| **G-03** | low | Tooltip labels lack visual affordance (no dashed underline, no `cursor: help`) | 1 CSS attribute-selector rule |
| **G-04** | low | Pre-existing DE-only hardcoded strings on tournament_monitor + surrounds | audit + small i18n pass |
| **G-05** | low | EN locale shows "Training" for warm-up state — should be "Warmup" | 3 lines in `config/locales/en.yml:844-846` |
| **G-06** | medium | `Discipline#parameter_ranges` derived from one specific scenario, needs widening | widen ranges short-term; database-backed long-term |

All 5 are **pre-existing or follow-up items, not Phase 36B regressions**. Phase 36B's
functional acceptance criteria (UI-01..07 + FIX-01/03/04) all passed the UAT — the
findings are polish and debt, not broken features.

## Why it's a seed, not a todo

These 5 items touch different files and concerns (CSS dark-mode rules, Stimulus controller
affordance, i18n YAML values, German/English coverage, Ruby model constants), but each is
independently trivial. Together they fit into a **single small phase, likely 1 plan**,
that a future milestone can fold in as a warm-up round alongside its main feature work.
They don't need their own milestone.

A seed (rather than 5 separate todos) preserves the **why** behind each item — the exact
UAT observation that surfaced it — and the **fix sketch** already worked out during the
UAT session. See the full rationale in `36B-HUMAN-UAT.md` under each Gap header.

The seed auto-surfaces when `/gsd-new-milestone` runs after v7.0 is archived, so none of
these gaps get lost in the transition.

## Conditions that should surface this seed

- **Primary:** Next milestone kickoff — `/gsd-new-milestone` is run after v7.0 is archived.
  Surface the seed as a proposed scope item for whichever milestone comes next.
- **Secondary:** If a future discuss-phase touches dark-mode, tooltips, i18n coverage, or
  UX consistency for volunteer-facing screens, surface G-01/G-03/G-04/G-05 as prior art.
- **Tertiary:** If a real 2×/year volunteer files a usability report matching any of G-01..G-06,
  promote the relevant gap to a todo immediately and draw from this seed's fix sketches.

## Rough fix paths (copied from 36B-HUMAN-UAT.md Gaps section)

### G-01: Dark-mode contrast

- `_wizard_steps_v2.html.erb:167` — replace inline `style="background: #dff0d8; ..."` with
  Tailwind `bg-green-50 dark:bg-green-900/30 border border-green-600 dark:border-green-500
  text-green-900 dark:text-green-100`
- Audit `tournament_wizard.css:287-295` — verify `html.dark .step-help p` rule actually takes
  effect via DevTools; bump specificity or convert to `@apply` if it's being clobbered
- Audit all inline `style="background: ..."` declarations in `_wizard_steps_v2.html.erb`
  (lines 167, 215, 268 at least) and either wrap with `dark:bg-*` Tailwind classes or add
  matching `dark:text-*` overrides

### G-03: Tooltip affordance

- Add to `application.tailwind.css` or a new `tooltip.css` imported alongside it:
  ```css
  [data-controller~="tooltip"] {
    cursor: help;
    border-bottom: 1px dashed currentColor;
    padding-bottom: 1px;
  }
  ```
- Auto-applies to all 16 existing tooltipped labels in `tournament_monitor.html.erb`
  (and any future ones) without touching ERB. ~5 minutes.
- Care: if option A bleeds into nested form controls, scope with
  `[data-controller~="tooltip"] > span, label`

### G-04: Pre-existing DE-only strings

- grep for literal German words outside `t('...')` calls:
  `grep -rn 'Aktuelle\|Turnier\|Starte\|zurück' app/views/tournaments/ | grep -v "t('"`
- Create new i18n keys under `tournaments.monitor.*` and `tournaments.show.*` namespaces
- Not urgent — DE is primary locale for 2×/year volunteers; EN coverage gaps mostly affect
  admins who are English-comfortable in the shell

### G-05: Warm-up EN translation

- Single-file edit, 3 lines in `config/locales/en.yml`:
  ```yaml
  # lines 844-846, under table_monitor.status:
  warmup: Warm-up          # was: Training
  warmup_a: Warm-up Player A  # was: Training Player A
  warmup_b: Warm-up Player B  # was: Training Player B
  ```
- Do NOT touch `en.yml:387` (`training: Training`) — that's a different key for
  "Training Game" (practice tournament), not the warm-up phase. Correct as-is.
- ~5 minutes including a locale-switch smoke test

### G-06: parameter_ranges rework

Short-term (next pass, low risk):
- Widen ranges in `app/models/discipline.rb:66-82` — lower `balls_goal_min` for youth, higher
  max for handicap outliers, more forgiving `timeout`
- Add `Pool`, `Snooker`, `Biathlon`, `Kegel` entries (even wide — at least warns on typos)
- Replace string key with `discipline_id` or symbol to protect against typo-disabling

Medium-term (proper data model):
- `discipline_parameter_ranges` database table: `discipline_id`, `attribute`, `min`, `max`,
  `tournament_type`
- `Discipline#parameter_ranges(tournament_type:)` filters by type
- `Tournament#tournament_type` attribute picks the right profile automatically

Long-term (data-driven):
- Populate ranges from historical tournament data (min/max of actually-used values per
  discipline across completed tournaments)
- Rake task refreshes ranges nightly

**Out-of-scope confirmation:** Phase 36B CONTEXT D-17 explicitly said "first-pass hardcoded;
future refinement may move to a database column or config". This is an acknowledged
follow-up, not a missed requirement.

## Related documents

- `.planning/phases/36B-ui-cleanup-kleine-features/36B-HUMAN-UAT.md` — full Gap details
  with evidence screenshots, root-cause analysis, and exact fix sketches
- `.planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md` §D-17 — authorized the
  first-pass hardcoded parameter_ranges (G-06 source)
- `.planning/phases/37-in-app-doc-links/37-CONTEXT.md` — Phase 37 D-11 placement decision
  that made G-01 visible (doc link inside `<details>` block ALSO affected by dark-mode contrast)
- `app/assets/stylesheets/tournament_wizard.css` — existing CSS for G-01 audit
- `app/javascript/controllers/tooltip_controller.js` — Phase 36B tooltip Stimulus controller
  (reference for G-03)
- `app/models/discipline.rb:50-94` — current parameter_ranges constants (G-06 target)
- `config/locales/en.yml:387,844-846` — G-05 target + the correctly-translated training key

## Size estimate

**Small.** Realistic bundling:

- **One plan** covers G-03 (CSS rule), G-05 (3 YAML lines), and the G-01 quick wins
  (the `_wizard_steps_v2.html.erb:167` Tailwind class replacement). ~30-60 minutes.
- G-04 (broad i18n audit) and G-06 (parameter_ranges widening) may each deserve their
  own plan if the team decides to do them thoroughly — pushing to ~3 plans total.
- The database-backed G-06 redesign is a separate decision and could be a full phase
  on its own if the team chooses that path.

Baseline estimate for the minimal-viable version: **1 plan, ~2 hours of work** including
commit messages, lint, and smoke test. Maximum reasonable version: **3 plans, ~1 day**.

## Notes

- G-02 (public/docs/ stale) was **fixed inline during the UAT session** (`7cf16114`,
  2026-04-15). Not part of this seed.
- Test 1 of the Phase 36B UAT was marked `issue` because the user flagged G-01 while on
  Test 1 rather than explicitly negating the Test 1 header criteria. Test 1's actual
  header criteria (badge dominance, 6 chips, no "Schritt N von 6", no numeric prefixes)
  still need explicit confirmation once G-01 is fixed — **include a Test 1 retest as
  part of the plan that ships G-01's fix**.
- This seed is flat on purpose — no XX-01/XX-02 sub-items. Let the future planner decide
  the right phase/plan breakdown based on whichever milestone folds it in.
