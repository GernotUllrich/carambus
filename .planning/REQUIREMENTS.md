# Requirements: Carambus API — v7.1 UX Polish & i18n Debt

**Defined:** 2026-04-15
**Core Value:** Code and docs stay in sync — every documented feature works, every working feature is documented, and a volunteer user should never need to read the architecture to run a tournament.

## Context

During the Phase 36B human UAT session on 2026-04-15, six gaps surfaced against the v7.0 wizard UI (G-01 through G-06). One (G-02, `public/docs/` staleness) was fixed inline during the UAT. The other five were non-regressions against v7.0's functional acceptance criteria and got captured as seed `.planning/seeds/v71-ux-polish-i18n-debt.md` for a follow-up milestone.

This milestone (v7.1) promotes that seed to active scope. The source of truth for each requirement's fix sketch, affected files, and line numbers is the seed document and the phase 36B UAT notes:
- `.planning/seeds/v71-ux-polish-i18n-debt.md`
- `.planning/milestones/v7.0-phases/36B-ui-cleanup-kleine-features/36B-HUMAN-UAT.md`

All 6 requirements are small, independently shippable, and together fit into **1–3 plans**. This is a warm-up milestone before the larger v7.2+ ClubCloud Integration / Shootout work resumes.

## v7.1 Requirements

### UX Polish (user-visible fixes)

- [ ] **UX-POL-01**: Wizard `<details>` help block and inline-styled info banners are readable in dark mode. User can read all wizard help text and info banners without switching to light mode, with sufficient contrast against the dark background.
  - Fix sketch (from seed): replace inline `style="background: #dff0d8; …"` on `_wizard_steps_v2.html.erb:167` (and lines 215, 268) with Tailwind `bg-green-50 dark:bg-green-900/30 border border-green-600 dark:border-green-500 text-green-900 dark:text-green-100`. Audit `tournament_wizard.css:287-295` specificity.
  - Source gap: G-01 (medium severity)

- [ ] **UX-POL-02**: Tooltip-decorated labels have a visible affordance. A user who has never seen the tournament_monitor form knows the labels are hoverable without trial-and-error, via dashed underline + `cursor: help` styling.
  - Fix sketch (from seed): one CSS attribute-selector rule on `[data-controller~="tooltip"]` in a new or existing stylesheet imported alongside `application.tailwind.css`. Auto-applies to all 16 existing tooltipped labels on `tournament_monitor.html.erb`.
  - Source gap: G-03 (low severity)

- [ ] **UX-POL-03**: Phase 36B Wizard Header Test 1 criteria are explicitly reconfirmed after G-01 fix ships. AASM state badge is dominant, 6 bucket chips present, "Schritt N von 6" text absent, numeric prefixes absent — all observable in a fresh manual UAT pass.
  - Fix sketch: no code change — this is a retest of the existing Phase 36B UI against its original criteria. Test 1 was marked `issue` during the v7.0 UAT because G-01 was flagged mid-test rather than negating Test 1's header criteria.
  - Source gap: seed §Notes — "Test 1 retest must ship alongside G-01 fix"

### i18n Debt (translation coverage)

- [ ] **I18N-01**: EN locale shows "Warmup" (not "Training") for the three `table_monitor.status.warmup*` keys. English-reading user sees "Warmup / Warm-up Player A / Warm-up Player B" on the scoreboard warm-up screen.
  - Fix sketch (from seed): 3-line edit in `config/locales/en.yml:844-846` (`warmup: Warm-up`, `warmup_a: Warm-up Player A`, `warmup_b: Warm-up Player B`). Do **not** touch `en.yml:387` (`training: Training` — that's a different key for the practice-tournament concept).
  - Source gap: G-05 (low severity)

- [ ] **I18N-02**: Pre-existing DE-only hardcoded strings on tournament views are identified and covered by `t(...)` calls. Audit scope: `app/views/tournaments/` excluding the Phase 36B parameter form (already handled).
  - Fix sketch (from seed): `grep -rn 'Aktuelle\|Turnier\|Starte\|zurück' app/views/tournaments/ | grep -v "t('"` to locate candidates. Create new i18n keys under `tournaments.monitor.*` and `tournaments.show.*` namespaces. DE is primary locale for 2-3x/year volunteers, so EN-coverage gaps mostly affect admins, but still worth closing.
  - Source gap: G-04 (low severity)

### Data Model Tuning

- [ ] **DATA-01**: `Discipline#parameter_ranges` is wide enough for real-world usage without false-positive warnings from the Phase 36B parameter verification modal. Youth, handicap, pool, snooker, biathlon, and kegel disciplines either have explicit range entries or are covered by widened existing ranges. Verification modal no longer fires on legitimate tournament configurations.
  - Fix sketch (from seed): short-term = widen ranges in `app/models/discipline.rb:66-82` + add entries for missing disciplines, replace string keys with symbols to catch typos. Medium-term (may or may not be in scope) = `discipline_parameter_ranges` table with `discipline_id`, `attribute`, `min`, `max`, `tournament_type`. Long-term (out of scope) = nightly rake task populating ranges from historical tournament data.
  - Source gap: G-06 (medium severity) — Phase 36B CONTEXT D-17 explicitly authorized the first-pass hardcoded approach as "first-pass; future refinement may move to a database column or config".
  - **Scope boundary (decide in discuss-phase):** short-term widen only, or short-term + medium-term DB-backed table? The latter is 3-5× larger in scope and would justify its own phase.

## Out of Scope

| Feature | Reason |
|---------|--------|
| `public/docs/` drift CI guard | Separate follow-up to the failed quick task 260415-26d; will be a new quick task or small milestone with a GitHub Actions-based approach instead of a pre-commit hook |
| v7.2 ClubCloud Integration (Endrangliste, CC API finalization, credentials delegation) | Separate larger milestone; skeleton in `.planning/milestones/v7.2-*` (version number to be decided at next kickoff — the "v7.1" skeleton file names from Phase 36c are historical artifacts and don't imply the CCI milestone will actually carry the v7.1 tag) |
| v7.3 Shootout / Stechen Support | Separate milestone; skeleton in `.planning/milestones/v7.2-*` (again version number historical) |
| Long-term data-driven `discipline_parameter_ranges` from historical tournament data | Explicit long-term path in the seed; not in this milestone |
| Full `app/views/` i18n audit (all controllers, all partials) | Scope for this milestone is explicitly only tournament views; broader i18n coverage would be its own milestone |
| Dark-mode audit for non-wizard screens (league views, player profiles, admin dashboards) | Scoped to wizard only because wizard is the volunteer's primary surface |

## Traceability

Which phases cover which requirements. Filled in by the roadmapper during `/gsd-new-milestone` Step 10.

| Requirement | Phase | Status |
|-------------|-------|--------|
| UX-POL-01 | TBD | Pending |
| UX-POL-02 | TBD | Pending |
| UX-POL-03 | TBD | Pending |
| I18N-01 | TBD | Pending |
| I18N-02 | TBD | Pending |
| DATA-01 | TBD | Pending |

**Coverage:**
- v7.1 requirements: 6 total
- Mapped to phases: 0 (pending roadmap)
- Unmapped: 6 ⚠️ (will resolve in roadmap step)

---
*Requirements defined: 2026-04-15*
*Last updated: 2026-04-15 after seed v71-ux-polish-i18n-debt.md promoted to active scope*
