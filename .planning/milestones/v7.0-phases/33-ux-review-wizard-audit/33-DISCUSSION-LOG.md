# Phase 33: UX Review & Wizard Audit - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 33-CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-13
**Phase:** 33-ux-review-wizard-audit
**Mode:** discuss (interactive)
**Areas discussed:** Observation method, UX-FINDINGS.md structure, Retirement scope, Tier classification rules

---

## Observation method

### Q1 — How should the happy path be observed for Phase 33?

| Option | Description | Selected |
|--------|-------------|----------|
| Browser + code-read | Run dev server, walk new→create→edit→finish_seeding→start, capture screenshots, cross-check against controller/view code. Best for catching UI surprises and the transient AASM state. | ✓ |
| Code-read only | Read show.html.erb, _wizard_steps_v2.html.erb, tournaments_controller.rb, tournament.rb AASM. No browser. Cannot observe transient AASM visibility. | |
| Browser only | Walk the flow without deep code read. Likely to miss intent vs. behavior drift. | |

**User's choice:** Browser + code-read (recommended).

### Q2 — Should screenshots be committed into the phase directory?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, one per happy-path state | Commit PNGs to `.planning/phases/33-ux-review-wizard-audit/screenshots/`. Helps Phase 34 doc rewrite. | ✓ |
| No, text descriptions only | Keep phase directory small; downstream phases re-observe if needed. | |

**User's choice:** Commit screenshots.

### Q3 — Which tournament fixture/data should drive the walkthrough?

| Option | Description | Selected |
|--------|-------------|----------|
| Real dev DB tournament | Use/create tournament in development DB. Closest to volunteer reality. | ✓ |
| Test fixture tournament in system test | Drive flow via system test that captures screenshots. More reproducible but adds test scaffolding. | |
| You decide | Claude picks whichever is fastest. | |

**User's choice:** Real dev DB tournament.

---

## UX-FINDINGS.md structure

### Q4 — How should UX-FINDINGS.md be structured?

| Option | Description | Selected |
|--------|-------------|----------|
| Section per action, findings table inside | One H2 per happy-path action with Intent → Observed → Finding table (ID \| Description \| Tier \| Gate). Greppable by tier, linkable by action. | ✓ |
| Single flat table | One big table across all actions. Compact but hard to attach narrative/screenshots to a specific action. | |
| Narrative per action, no table | Pure prose. Best readability, worst for tier-gating. | |

**User's choice:** Section per action with findings table (user confirmed preview).

### Q5 — Should each finding get a stable ID?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, stable F-NN IDs | Phase 36 PLAN.md can say "fixes F-03, F-05, F-12" and verifier cross-checks. | ✓ |
| No, bullet lists only | Phase 36 references by quote. Fragile. | |

**User's choice:** Stable F-NN IDs.

### Q6 — Should non-happy-path actions appear in UX-FINDINGS.md?

| Option | Description | Selected |
|--------|-------------|----------|
| Listed only | Short "Non-happy-path (not reviewed)" section listing them. Matches UX-04. | ✓ |
| Omit entirely | Simpler file but loses the explicit "we know these exist" signal. | |

**User's choice:** Listed only.

---

## Retirement scope

### Q7 — Does Phase 33 actually retire the non-canonical wizard partial?

| Option | Description | Selected |
|--------|-------------|----------|
| Document decision only, Phase 36 executes | Keeps audit clean, no code changes this phase. | ✓ |
| Retire in Phase 33 itself | Faster but mixes observation with code changes. | |
| Retire only if trivially safe | If zero refs, delete now; otherwise defer. Pragmatic hybrid. | |

**User's choice:** Document decision only; Phase 36 executes.

### Q8 — What must UX-FINDINGS.md prove about the canonical partial?

| Option | Description | Selected |
|--------|-------------|----------|
| Grep evidence + render trace | Include exact grep output showing canonical render + zero refs to retirees. Re-runnable. | ✓ |
| Just the decision statement | Shorter but unverifiable. | |

**User's choice:** Grep evidence + render trace.

---

## Tier classification rules

### Q9 — How should ambiguous findings be classified?

| Option | Description | Selected |
|--------|-------------|----------|
| Classify by highest layer touched | Mechanical: view = Tier 1, controller = Tier 2, AASM = Tier 3. Ambiguous → higher tier. | ✓ |
| Classify by perceived risk | Judgment call. Blurs the gate. | |
| Dual-classify when borderline | "Tier 1/2" with note; Phase 36 decides. Most accurate, least decisive. | |

**User's choice:** Classify by highest layer touched.

### Q10 — Is Tier 3 allowed in Phase 36?

| Option | Description | Selected |
|--------|-------------|----------|
| Gated: explicit test-coverage plan required | Matches success criterion #4. Default gate = `blocked-needs-test-plan`. | ✓ |
| Gated: any Tier 3 → new phase | Auto-spawn backlog entry; Phase 36 never touches Tier 3. | |
| Allowed if small | Judgment call. Weakest gate. | |

**User's choice:** Gated with explicit test-coverage plan.

### Q11 — How to handle bugs discovered during UX review?

| Option | Description | Selected |
|--------|-------------|----------|
| Record in UX-FINDINGS.md, tag as "bug", classify by tier | One source of truth. `type` column filters bug vs. ux vs. missing-feature. | ✓ |
| Split into UX-FINDINGS.md + BUGS.md | Clean separation; more artifacts to track. | |
| Skip bugs entirely | Log elsewhere; misses the opportunity. | |

**User's choice:** Keep in UX-FINDINGS.md with type tag.

---

## Claude's Discretion

- Exact screenshot tooling (manual macOS, Puppeteer, etc.)
- Whether to reuse or create the dev-DB tournament for the walkthrough
- Prose style of Intent vs. Observed per action
- Additional finding-table columns beyond the D-04 shape

## Deferred Ideas

- Retiring the non-canonical wizard partials (Phase 36 executes)
- Fixing any Tier 1/2 findings (Phase 36 scope)
- Fixing Tier 3 findings (gated: dedicated phase unless test plan attached)
- Reviewing non-happy-path actions (listed-only in this phase; no follow-up phase scheduled)
- System-test-based walkthrough automation (rejected as too much scaffolding for audit)
