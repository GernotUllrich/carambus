# Phase 33: UX Review & Wizard Audit - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Observation and documentation phase. Produce `UX-FINDINGS.md` that (a) identifies the
canonical tournament wizard partial, (b) documents the observed behavior of the
transient `tournament_started_waiting_for_monitors` AASM state, (c) classifies every
happy-path action (`new` → `create` → `edit` → `finish_seeding` → `start`) by intent vs.
observed behavior, and (d) tier-classifies every finding to give Phase 36 an
authoritative spec of what it is allowed to touch.

**No production code changes in this phase.** Retirement of the non-canonical partial
and any fixes are deferred to Phase 36.

</domain>

<decisions>
## Implementation Decisions

### Observation method
- **D-01:** Observe the happy path in a real browser against a running dev server AND cross-read the relevant source (`show.html.erb`, `_wizard_steps_v2.html.erb`, `tournaments_controller.rb`, `tournament.rb` AASM). Browser-only or code-only is not sufficient — the transient AASM state (UX-02) can only be verified visually, and controller intent can only be verified from source.
- **D-02:** Drive the walkthrough against a **real tournament in the development database**. Create one via `rails console` if none exists. Record the reproduction recipe (tournament id, starting AASM state, data preconditions) at the top of `UX-FINDINGS.md` so Phase 34 and Phase 36 can re-observe if needed.
- **D-03:** Capture **screenshots, one per happy-path state transition**, and commit them to `.planning/phases/33-ux-review-wizard-audit/screenshots/`. Expected count: 6–10 PNGs covering each action's before/after plus any transient states. File naming: `NN-<action>-<substate>.png` (e.g., `04-finish_seeding-before.png`).

### UX-FINDINGS.md structure
- **D-04:** One H2 section per happy-path action (`new`, `create`, `edit`, `finish_seeding`, `start`, plus a section for the `tournament_started_waiting_for_monitors` transient state). Each section follows the shape:
  ```
  ## <action>

  **Intent:** what the volunteer is trying to do
  **Observed:** what the UI actually shows/does
  **Screenshot:** screenshots/NN-<action>.png

  | ID   | Type | Finding           | Tier | Gate |
  |------|------|-------------------|------|------|
  | F-NN | ux   | ...               | 1    | open |
  ```
- **D-05:** Every finding gets a **stable ID** (`F-01`, `F-02`, ...) numbered sequentially across the whole file, independent of section. Phase 36 PLAN.md will reference findings by these IDs (e.g., "fixes F-03, F-07, F-12") and a verifier can cross-check.
- **D-06:** The finding table has a `Type` column taking one of `ux | bug | missing-feature`. Bugs discovered during the UX review stay in `UX-FINDINGS.md` (not a separate `BUGS.md`) so Phase 36 has a single source of truth and can filter by `type` + `tier` together.
- **D-07:** Non-happy-path actions (cancel/delete/advanced/admin flows) get a final "Non-happy-path actions (not reviewed)" section listing the action names only, to make the "we deliberately skipped these" decision explicit for downstream phases. Matches UX-04 wording.
- **D-08:** Every finding has a `Gate` column with value `open` initially. Tier-3 findings are written with `Gate: blocked-needs-test-plan` instead (see D-12).

### Retirement scope (non-canonical wizard partial)
- **D-09:** Phase 33 **does NOT delete** the non-canonical partials. It **documents the retirement decision** in `UX-FINDINGS.md` as a Tier 1 finding that Phase 36 will execute. This preserves the "audit phase, no code changes" framing.
- **D-10:** `UX-FINDINGS.md` must include **grep evidence** proving `_wizard_steps_v2.html.erb` is the only partial rendered by `show.html.erb`, plus a grep across `app/`, `config/`, `test/` showing every remaining reference (if any) to `_wizard_steps.html.erb` and `_wizard_step.html.erb`. Downstream agents must be able to re-run these greps. Commands to preserve literally in the file:
  - `grep -rn "wizard_steps\|wizard_step" app/ config/ test/`
  - `grep -n "render.*wizard" app/views/tournaments/show.html.erb app/views/tournaments/_show.html.erb`

### Tier classification rules
- **D-11:** Classify by **highest layer touched** (mechanical, no judgment):
  - **Tier 1** = view / copy / new partial / i18n key / help text only
  - **Tier 2** = any controller change, route change, or service object change
  - **Tier 3** = any AASM state machine change (`tournament.rb` `aasm` block, new/modified states or events)
  - Ambiguous cases resolve to the higher tier, not the lower one.
- **D-12:** **Tier 3 findings are gated.** Every Tier 3 row has `Gate: blocked-needs-test-plan` in `UX-FINDINGS.md`. Phase 36 can only unblock a Tier 3 item by attaching an explicit test-coverage plan in its own `PLAN.md` and referencing the finding ID. Matches success criterion #4 and UX-03.
- **D-13:** Bug-type findings and missing-feature findings are tier-classified by the **same rule** as UX findings — a bug that requires an AASM change is Tier 3 regardless of severity.

### Claude's Discretion
- Exact screenshot tooling (manual macOS screenshot, Puppeteer, etc.) — pick whatever is fastest for a real-browser walkthrough.
- Whether the reproduction recipe uses an existing dev-DB tournament or requires creating one.
- How to phrase "Intent" vs. "Observed" prose per action — short sentences are fine, no template required beyond D-04's shape.
- Whether to include additional columns (e.g., `Effort`) in the finding table if they add value for Phase 36.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 33 goal, success criteria, and UX-01..UX-04 requirement mapping
- `.planning/REQUIREMENTS.md` — UX-01 (canonical partial), UX-02 (transient state), UX-03 (tier classification), UX-04 (happy-path actions list)
- `.planning/PROJECT.md` — v7.0 Manager Experience milestone framing (volunteer persona, 2–3x/year usage)

### Code the audit targets
- `app/views/tournaments/show.html.erb` §line 35 — the single `render 'wizard_steps_v2'` call that establishes canonicality
- `app/views/tournaments/_wizard_steps_v2.html.erb` — canonical wizard partial (confirmed during scout)
- `app/views/tournaments/_wizard_steps.html.erb` — retirement candidate (to be proven unused)
- `app/views/tournaments/_wizard_step.html.erb` — retirement candidate (to be proven unused)
- `app/controllers/tournaments_controller.rb` — happy-path actions: `new` (line 428), `create` (436), `edit` (433), `finish_seeding` (107), `start` (288), with transient-state check at line 415
- `app/models/tournament.rb` §lines 276–295 — `tournament_started_waiting_for_monitors` AASM state and its transitions

### No external specs
Requirements are fully captured in ROADMAP.md + REQUIREMENTS.md + decisions above. There is no separate ADR or design doc for this phase — the audit itself is what produces the spec for downstream phases.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`_wizard_steps_v2.html.erb`** — the canonical wizard partial; rendered by `show.html.erb:35`. The audit confirms this, does not touch it.
- **`_wizard_steps.html.erb` and `_wizard_step.html.erb`** — two sibling partials; scout found no renders pointing at them from `show.html.erb` or `_show.html.erb`. These are the retirement candidates Phase 36 will act on.
- **Dev-DB tournaments** — the project has a populated development database from scraping; walkthrough can reuse an existing record rather than synthesizing one.

### Established Patterns
- **AASM transient states exist.** `tournament.rb:276` defines `tournament_started_waiting_for_monitors` and it is explicitly checked at `tournaments_controller.rb:415`. Whether this state surfaces visibly in the wizard is the central unknown that success criterion #2 must answer.
- **Wizard step rendering** goes through a single partial — there is no controller-side switch on scenario. This makes UX-01 cheap to satisfy (grep the one render call) and confirms the "exactly one wizard partial" acceptance criterion is already structurally true in code.
- **Phase artifacts convention** — every completed phase in `.planning/phases/NN-*/` commits its findings as markdown plus any supporting files. Screenshots belong in a `screenshots/` subdirectory per D-03.

### Integration Points
- **Phase 34 (Task-First Doc Rewrite)** consumes the happy-path walkthrough narrative and the confirmed canonical partial from this phase's findings.
- **Phase 36 (Small-Fix Phase)** consumes the finding IDs + tiers + gates to drive its PLAN.md task list.
- **Phase 37 (In-app Links)** uses the action-level anchors in `UX-FINDINGS.md` to decide where to drop "Help" links in the wizard.

</code_context>

<specifics>
## Specific Ideas

- Finding rows in the table should read like a diff entry: "no confirmation dialog before Setzliste abschließen" beats "UX issue on seeding step".
- The reproduction recipe at the top of `UX-FINDINGS.md` should be copy-pasteable shell + `rails console` commands — a future auditor can re-run the walkthrough without hunting for context.
- The `tournament_started_waiting_for_monitors` section is the load-bearing part of the whole phase. It gets its own H2 even though it is not a controller action; the finding is "what does the volunteer actually see (if anything) when the tournament is in this state for N seconds?".

</specifics>

<deferred>
## Deferred Ideas

- **Retiring the non-canonical wizard partials** — decided but not executed in Phase 33 (D-09). Phase 36 performs the deletes and updates any dangling references.
- **Fixing any Tier 1 / Tier 2 findings surfaced by the audit** — Phase 36 scope.
- **Fixing Tier 3 findings** — gated behind an explicit test-coverage plan attached to Phase 36's PLAN.md; otherwise, spawn a dedicated phase.
- **Reviewing non-happy-path actions** (cancel, delete, advanced flows, admin-only paths) — listed-only in this phase's findings (D-07); no separate phase scheduled yet.
- **System-test-based walkthrough automation** — rejected for Phase 33 (too much scaffolding for an audit). Revisit if Phase 36 wants regression coverage for the fixes it ships.

</deferred>

---

*Phase: 33-ux-review-wizard-audit*
*Context gathered: 2026-04-13*
