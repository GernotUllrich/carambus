# Feature Research

**Domain:** Volunteer-friendly tournament manager UX + task-first documentation (v7.0 scope)
**Researched:** 2026-04-13
**Confidence:** HIGH (based on direct code inspection + existing doc review; external web research unavailable this session)

---

## Scope Boundary

This research covers **v7.0 only**: docs rewrite, quick-reference card, in-app help links, wizard UX polish, and small documented-but-missing feature implementations. No new capabilities are in scope. Every feature below is evaluated against the persona: volunteer club officer, 2-3 tournaments/year, low tech comfort, German-speaking.

Carambus status codes used throughout:
- **EXISTS** — code exists and works today
- **PARTIAL** — code exists but is incomplete or inconsistent
- **NEW** — does not exist, would need implementation

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features that, if missing, cause the volunteer to fail or call for help.

| Feature | Why Expected | Complexity | Carambus Status | Notes |
|---------|--------------|------------|-----------------|-------|
| Task-first doc opening ("Running a tournament") | Volunteer opens docs once a year; an architecture overview as the first thing they see is a failure | LOW | PARTIAL | `tournament-management.en.md` opens with architecture/system overview, not a user task. `single-tournament.en.md` is closer but buried under index |
| Happy-path wizard walkthrough doc (steps 1-6 only) | The full doc mixes setup, edge cases, technical details, and troubleshooting — volunteer needs a single linear flow | LOW | PARTIAL | `single-tournament.en.md` covers all 6 steps but mixes happy-path with troubleshooting inline |
| State badge on wizard (what state am I in?) | 2-3x/year user forgets between uses; needs immediate orientation | LOW | EXISTS | `wizard_status_text` + progress bar already present in `_wizard_steps_v2.html.erb`; progress text shows "Schritt X von 6" |
| Numeric step counter visible throughout wizard | Volunteers can count; "Step 3 of 6" is orientation, not hand-holding | LOW | EXISTS | `_wizard_steps_v2` renders "Schritt X von 6" in header; both v1 and v2 templates have this |
| Irreversible-action warning before finalize steps | Step 4 (finalize participant list) cannot be undone; volunteer must know before clicking | LOW | EXISTS | Confirm dialog on finish_seeding; "danger" flag on wizard step renders red styling; warning text present |
| Troubleshooting section per doc page | Volunteer arrives at the doc when something is wrong, not when planning; needs problem-to-solution structure | LOW | PARTIAL | `single-tournament.en.md` has a Troubleshooting section; `tournament-management.en.md` does not; `index.en.md` has Common Problems but describes a different workflow than the actual wizard |
| Glossary inline or linked (Meldeliste vs. Setzliste vs. Teilnehmerliste) | These three terms are genuinely confusing and not standard German outside billiards administration | LOW | EXISTS | `_wizard_steps_v2` has a "Begriffserklärung" box; `single-tournament.en.md` has a dedicated section; full glossary exists at `/docs/reference/glossary.md` but is not linked from wizard |
| Before/During/After mental model in docs | Volunteers think in tournament phases, not in system states | LOW | PARTIAL | `index.en.md` "Best Practices" section has this structure but it references features that don't match the actual wizard (e.g., "Create tournament" as step 1, but Carambus starts from a ClubCloud-sourced tournament) |
| In-app link from wizard to relevant doc section | When stuck in the wizard, the volunteer needs to reach the relevant doc without leaving the page to search | MEDIUM | NEW | `docs_page.html.erb` exists and is a complete in-app doc renderer; `TournamentsController` has no links to it from wizard steps; no `help_url` pattern or doc-link helper in wizard views |
| Printable quick-reference card (Before/During/After) | On tournament day, no one reads docs on a laptop; a laminated one-pager is the real UX | LOW | NEW | No quick-reference document exists in `docs/managers/` |

### Differentiators (Nice to Have, Improves the Experience)

| Feature | Value Proposition | Complexity | Carambus Status | Notes |
|---------|-------------------|------------|-----------------|-------|
| Anchor-targeted in-app doc links (link to specific heading, not just page) | Wizard step 2 should link directly to "Step 2: Import Seeding List" heading, not the full 400-line doc | LOW | PARTIAL | `docs_page.html.erb` renders full page; no anchor-fragment support visible; mkdocs generates anchor IDs so the URL pattern exists, just needs wiring |
| State badge as primary orientation cue | A badge reading "Setzliste konfigurieren" is more meaningful than "33%" for a low-frequency user | LOW | PARTIAL | Both exist (`wizard_status_text` + progress bar); the badge text is visually secondary to the progress bar in current CSS; reordering is a layout change |
| Collapsed help section open by default for active step only | Expanding `<details>` manually is friction; the active step's help should be visible without a click | LOW | PARTIAL | All `<details>` elements in wizard steps are collapsed by default; adding `open` attribute conditionally when `status == :active` would fix this with one ERB change |
| "What changed since last time" note at top of doc | 2-3x/year user doesn't re-read the whole doc; a "Changed in this version" note saves time | LOW | NEW | No changelog section in manager docs |
| Quick-reference card in DE + EN | German is primary but some club officers run mixed events | LOW | NEW | All existing manager docs are bilingual; card should follow the same pattern |
| Wizard disappears after tournament start (or collapses) | After step 6, the wizard is replaced by the tournament status view — this is the right behavior | LOW | EXISTS | `_wizard_steps_v2` has `unless tournament.tournament_started` guard; tournament status section always renders |
| Step-level context always visible (not in `<details>`) | Active step context should not require a click to reveal | LOW | PARTIAL | All step help is behind `<details summary="Was macht dieser Schritt?">` — user must click to read context |

### Anti-Features (Tempting to Add, Actively Harmful for 2-3x/Year Users)

| Anti-Feature | Why It Looks Good | Why It Hurts Volunteers | Alternative |
|--------------|-------------------|------------------------|-------------|
| Comprehensive onboarding tour / interactive walkthrough | Seems welcoming; guides first-time users | 2-3x/year users forget the tour by next use; on return visits it becomes an obstacle; tours go stale when UI changes | Write the doc to be re-readable in 2 minutes; use the state badge for orientation on return |
| Modal help dialogs on wizard steps | Centralizes contextual help | Modals block the UI; on tournament day the volunteer is under time pressure; dismiss-to-proceed is friction | Use inline `<details>` open by default for the active step (already the structural pattern) |
| Over-explanation on the quick-reference card | More information feels safer | A card that doesn't fit on one A4 side is not a card — it's a doc that won't get printed | Strict rule: Before column 5 items max, During 5 items max, After 3 items max; link to full doc for anything longer |
| Multiple help entry points per step (tooltip + link + modal + inline) | Redundancy seems thorough | Cognitive overload; volunteer doesn't know which one to click; inconsistency erodes trust | One help mechanism per step; `<details>` open by default for the active step |
| Searchable documentation inside the app | Seems convenient | Low-frequency users don't know what to search for; they recognize context, not keywords; search requires knowing what to ask | Context-sensitive link from each wizard step directly to the relevant doc section |
| Feature-complete documentation index as the entry point | Looks professional | A volunteer arriving at `docs/managers/index.en.md` sees 8 sections, 10 tournament formats, statistics, PWA features — none relevant to running a single regional tournament | Make the entry point "Running Your First Tournament" as an H1, with everything else linked below |
| Undo/rollback button on finalize steps | Feels safer | If implemented incorrectly it creates ambiguity about state; AASM transitions are intentionally one-way; a partial rollback is worse than none | Make the confirmation dialog concrete ("12 players will be locked. No-shows cannot be re-added.") |
| "Advanced" / "Expert" mode toggle | Seems to serve power users | Volunteers are the only users of the wizard; there is no second audience; a toggle creates two UX paths to maintain | Design the happy path for the volunteer; expose edge cases through troubleshooting sections, not a mode switch |
| Progress percentage (33%, 66%) as primary metric | Numbers seem informative | Percentage implies granularity that doesn't exist (6 steps are not uniform work); "33%" while waiting on tournament day for players to arrive has no actionable meaning | State badge ("Setzliste konfigurieren", "Bereit zum Start") is more actionable than a percentage |
| Video tutorial embedded in wizard | Looks modern | Videos don't work offline, are painful to watch under time pressure on tournament day, and go stale when UI changes | Short inline text + printable card; in-app link to the relevant doc section |

---

## Feature Dependencies

```
Printable quick-reference card
    └──requires──> Task-first doc content (happy-path only, decided first)
                       └──requires──> Wizard UX review (what actually happens in each step)

In-app doc links from wizard steps
    └──requires──> URL mapping: wizard step number → doc section anchor
    └──enhances──> Collapsed help (doc link as fallback when details is closed)

Open-by-default help for active step
    └──enhances──> State badge as primary orientation
                       └──conflicts──> Progress percentage as primary orientation
                                           (one should be demoted; badge to primary, bar to secondary)

Anchor-targeted in-app doc links
    └──requires──> docs_page.html.erb anchor-fragment support (partial implementation exists)
    └──requires──> Task-first doc rewrite (anchors only useful once headings are well-structured)
```

### Dependency Notes

- **Quick-reference card requires task-first doc rewrite first:** The card content must be derived from the same happy-path walkthrough. Writing them in parallel risks inconsistency between card and doc.
- **In-app doc links require wizard UX review first:** We need to confirm which steps have friction before wiring links to specific doc sections. Linking to the wrong sections adds noise.
- **State badge vs. progress bar:** Both exist in `_wizard_steps_v2`. The progress bar is visually primary (wide, colored, prominent). The status text is secondary in the current layout. Demoting the bar and promoting the badge is a CSS/layout change with no logic risk.
- **Open-by-default details:** The `_wizard_step.html.erb` partial uses a static `<details>` tag. Adding `open` conditionally when `status == :active` is one ERB condition. Risk: if multiple steps are simultaneously active (steps 3+4 can both be active), both would be open — which is correct behavior.

---

## MVP Definition

### Launch With (v7.0)

Minimum deliverables for the milestone.

- [ ] **Task-first doc rewrite** of `docs/managers/tournament-management.{de,en}.md` — "Running a tournament from ClubCloud to finish" replaces the architecture overview; technical details move to appendix. Reason: This is the entry point volunteers find first; its current form fails the volunteer persona.
- [ ] **Printable quick-reference card** (one A4 page, Before/During/After, DE + EN) in `docs/managers/`. Reason: On tournament day, no one reads docs on a laptop. The card is the actual runtime UX for a low-frequency user.
- [ ] **In-app doc links from wizard steps** — Each of the 6 steps in `_wizard_steps_v2` gets a link to the corresponding section of the rewritten doc. Reason: `docs_page.html.erb` renderer already exists; wiring the link is LOW complexity and HIGH volunteer value.
- [ ] **Open-by-default help for the active step** — The `<details>` element on the active step renders with `open` attribute. Reason: One ERB condition; eliminates one click of friction at the moment of highest confusion.

### Add After Validation (v7.x)

- [ ] **Anchor-targeted doc links** — Link from step 2 directly to "Step 2" heading in the doc, not the top of the page. Trigger: Volunteers scroll past the heading when landing on the full page.
- [ ] **State badge as primary orientation cue** — Demote progress bar, elevate `wizard_status_text`. Trigger: Observed that volunteers misread the % bar or find it meaningless.

### Future Consideration (v8+)

- [ ] **"What changed" section in manager docs** — Adds maintenance burden; only worthwhile if the wizard is actively evolving and the user base is large enough to read it.
- [ ] **Simplified referee UI** — Already flagged in `tournament-management.en.md` as a future project; out of v7.0 scope.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Task-first doc rewrite | HIGH | LOW (writing, no code) | P1 |
| Printable quick-reference card | HIGH | LOW (writing, no code) | P1 |
| In-app doc links from wizard steps | HIGH | LOW (ERB + route helper) | P1 |
| Open-by-default help for active step | MEDIUM | LOW (one ERB condition) | P1 |
| State badge as primary orientation | MEDIUM | LOW (CSS reorder) | P2 |
| Anchor-targeted doc links | MEDIUM | MEDIUM (fragment routing in docs_page) | P2 |
| "What changed" note in docs | LOW | LOW | P3 |

---

## Competitor Feature Analysis

Analogous patterns from volunteer-oriented admin software (sports management, event management, club administration tools).

| Pattern | How Analogous Products Do It | Carambus Current State | v7.0 Approach |
|---------|------------------------------|------------------------|---------------|
| Task-first docs | "Create your first bracket in 3 steps" as the opening; Challonge opens with a tournament type picker — task, not architecture | Opens with architecture/system overview | Rewrite opening to "Run a tournament in 6 steps" |
| Quick-reference / cheat sheet | Club software often includes a laminated card in onboarding; "Day Of" checklist pattern common in event management tools | Does not exist | One-page Before/During/After printable card |
| Inline contextual help | Modern SaaS wizards use always-visible or on-hover help adjacent to the action button; collapsed by default is a known friction point for infrequent users | Behind `<details>` collapsed by default | Open by default for active step |
| In-app doc navigation | Context-sensitive help links (Intercom-style, or simpler "?" icon linking to relevant doc section) are table stakes in any wizard flow | `docs_page.html.erb` exists but wizard has zero links to it | Wire one link per wizard step |
| Step numbering | Universal pattern; "Step 3 of 6" always present in multi-step flows | EXISTS (`_wizard_steps_v2` renders "Schritt X von 6") | No change needed |
| State/phase label | Sports tools use phase names ("Registration", "In Progress", "Complete") rather than percentages as the primary status indicator | EXISTS as secondary element (`wizard_status_text`); progress bar is primary | Promote state label, demote percentage bar |
| Glossary for domain terms | Low-frequency-admin products (government portals, club management software) that use specialized terminology always provide a glossary; key terms are explained inline near first use | EXISTS in wizard (Begriffserklärung box) and in separate page; not linked from wizard | Verify link from wizard to glossary exists; add if missing |

---

## Sources

- Direct code inspection: `app/views/tournaments/_wizard_steps.html.erb`, `_wizard_steps_v2.html.erb`, `_wizard_step.html.erb`
- Direct code inspection: `app/helpers/tournament_wizard_helper.rb`, `app/helpers/tournaments_helper.rb`
- Direct code inspection: `app/controllers/tournaments_controller.rb` (happy-path action list)
- Direct code inspection: `app/views/tournaments/show.html.erb` (wizard render conditions)
- Existing documentation: `docs/managers/tournament-management.en.md`, `docs/managers/index.en.md`, `docs/managers/single-tournament.en.md`, `docs/decision-makers/features-overview.en.md`
- Project context: `.planning/PROJECT.md` (v7.0 milestone definition, volunteer persona constraint)
- In-app doc infrastructure: `app/views/static/docs_page.html.erb` (confirms renderer exists and is fully functional)
- Confidence for Carambus-status assessments: HIGH (all from direct code inspection)
- Confidence for analogous-product patterns: MEDIUM (training knowledge; no external search available this session)

---

*Feature research for: Carambus v7.0 Manager Experience — docs + wizard UX for volunteer club officers*
*Researched: 2026-04-13*
