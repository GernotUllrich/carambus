# Phase 38: UX Polish & i18n Debt - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-15
**Phase:** 38-ux-polish-i18n-debt
**Areas discussed:** DATA-01 scope, G-03 CSS placement, I18N-02 audit depth, UX-POL-03 retest mechanism

---

## DATA-01 scope

Initial framing was: short-term widen vs medium-term DB-backed table vs symbol-key-only.
User declined to answer and asked to clarify — then provided critical domain knowledge:
`discipline_tournament_plans` table already exists with real per-discipline/plan/players/
player_class data at http://0.0.0.0:3007/discipline_tournament_plans. A reduced mode (80%
of normal) is possible within tournaments. Vorgabeturniere (`handicap_tournier=true`) have
`innings_goal=0` (no limit) and per-participant `balls_goal` (not a single range).

Codebase probe confirmed:
- `DisciplineTournamentPlan` model exists (`app/models/discipline_tournament_plan.rb`)
  with columns `discipline_id`, `tournament_plan_id`, `points`, `innings`, `players`, `player_class`
- 12 disciplines have DTP entries (Karambol variants + Petit/Grand Prix + Nordcup)
- Pool, Snooker, Kegel, Biathlon, 5-Kegel have NO DTP entries (matches the REQUIREMENTS.md
  false-positive complaints)
- `Tournament#handicap_tournier` and `Tournament#player_class` columns confirmed present

Reformulated gray area after the domain-knowledge drop:

| Option | Description | Selected |
|--------|-------------|----------|
| DTP-backed rewrite (Phase 39) | Split DATA-01 out of Phase 38 entirely. Refactor `Discipline#parameter_ranges(tournament:)` to query DTPs. Normal = exact, reduced = `[points*0.8..points]`, handicap skips innings + widens balls_goal. Hardcoded fallback for uncovered disciplines. Phase 38 ships 2 plans only. | ✓ |
| DTP-backed rewrite inside Phase 38 | Same rewrite but bundled into Plan 38-03. Blows warm-up milestone budget. | |
| Hybrid widen + DTP later | Widen hardcoded constants now, defer DTP rewrite to a future phase. | |
| Pure widen (original roadmap) | Ignore DTP table, just widen the hardcoded ranges. Leaves Pool/Snooker/Kegel uncovered. | |

**User's choice:** DTP-backed rewrite spun off to a new Phase 39.

**Notes:** Consequence — Phase 38 shrinks from 3 plans to 2 plans. Roadmap and REQUIREMENTS.md
need a post-discuss-phase update to reflect: DATA-01 moves out of Phase 38, Phase 39
(DTP-backed parameter_ranges) inserted. That update is not part of this discussion —
handled by `/gsd-insert-phase 39` or a manual ROADMAP.md edit after this CONTEXT.md lands.

---

## G-03 CSS placement

### CSS file location

| Option | Description | Selected |
|--------|-------------|----------|
| New `components/tooltip.css` | Create the component file, register via `@import` in `application.tailwind.css` alongside 14+ other component files. Consistent with established pattern. | ✓ |
| Append to `tournament_wizard.css` | Keeps tournament styles together but tooltip scope is broader (used on `tournament_monitor.html.erb`, not just wizard). | |
| Append to `application.tailwind.css` directly | Breaks the "imports only" convention. | |

**User's choice:** New `components/tooltip.css` (Recommended).

### Selector scope

| Option | Description | Selected |
|--------|-------------|----------|
| Broad `[data-controller~='tooltip']` | Simple, matches all 16 existing sites. Risk is low — tooltipped elements are all inline labels/spans in practice. | |
| Narrow `[data-controller~='tooltip'] > span, label[...]` | Safer against future misuse but more brittle. | |
| Claude decides after auditing the 16 sites | Grep `tournament_monitor.html.erb` during planning/execution, pick narrowest safe selector based on actual usage. | ✓ |

**User's choice:** Defer narrowing decision to planning/execution after site audit.

**Notes:** CSS-only change, zero ERB edits.

---

## I18N-02 audit depth

### Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Full `app/views/tournaments/` sweep (23 ERB files, excluding `_wizard_steps_v2.html.erb`) | Matches REQUIREMENTS.md literally. Every user-visible literal → `t(...)`. | ✓ |
| Tournament-monitor-adjacent only (3 files) | Smaller scope, faster ship. Admin views stay German-only. | |
| Full sweep + included partials from other dirs | Broadest coverage, risks scope creep. | |

**User's choice:** Full sweep.

### Key namespace structure

| Option | Description | Selected |
|--------|-------------|----------|
| `tournaments.monitor.*` + `tournaments.show.*` | Matches REQUIREMENTS.md wording. Two clear namespaces. | ✓ |
| Per-file namespace (`tournaments.tournament_monitor.*`, `tournaments.edit.*`, …) | More granular, more keys. | |
| Flat `tournaments.*` | Shorter paths, risks collisions. | |

**User's choice:** Two-namespace structure per REQUIREMENTS.md wording.

### Translation approach

| Option | Description | Selected |
|--------|-------------|----------|
| Add DE + EN simultaneously | Claude writes both values in the same plan commit. Closes the EN gap in one pass. | ✓ |
| DE only, stub EN with DE fallback | Quicker but EN admins keep seeing German. | |
| DE first, generate EN via AI translation service | Automates but adds review burden. | |

**User's choice:** DE + EN simultaneously.

**Notes:** These are short UI labels, no need for DeepL/OpenAI translation service.

---

## UX-POL-03 retest mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Manual UAT with evidence artifact | Human runs wizard post-G-01-fix, verifies 4 header criteria, writes `38-UX-POL-03-UAT.md` in phase dir. Matches Phase 36B UAT pattern. | ✓ |
| Capybara system test + manual UAT | Add permanent regression test + still run manual UAT. Costs ~1 hour. | |
| Capybara system test only (skip manual) | Faster to ship but loses the dark-mode visual confidence. | |

**User's choice:** Manual UAT only, artifact in phase directory.

**Notes:** Retest is a one-shot confirmation, not a permanent regression guard. Scheduled
inside Plan 38-01 as a final task after the G-01 CSS change ships.

---

## Claude's Discretion

- Tailwind class names if inline styles on lines 215 and 268 use different base colors
  than line 167 (D-03)
- Tooltip selector narrowing if broad form bleeds into nested form controls (D-07)
- Which `tournaments.*.*` namespace each admin/edit view uses (D-12)
- Grep patterns for broader i18n sweep beyond initial 4-word list (D-13)
- Exact EN translations for new keys (D-14)
- UAT artifact exact wording (D-17)

## Deferred Ideas

- **DATA-01 DTP-backed rewrite** → new Phase 39
- Long-term data-driven parameter_ranges from historical tournament data → out of scope
- Full `app/views/` i18n audit beyond tournaments/ → out of scope
- Dark-mode audit beyond the wizard → out of scope
- `public/docs/` CI guard → separate task
- DATA-01 todo file → moves with DATA-01 to Phase 39
