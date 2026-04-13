# Pitfalls Research

**Domain:** Volunteer-facing doc rewrite + UX review on existing Rails wizard (v7.0 Manager Experience)
**Researched:** 2026-04-13
**Confidence:** HIGH — all pitfalls derived from direct inspection of `app/models/tournament.rb` (AASM block), `app/views/tournaments/_wizard_steps*.html.erb`, `app/controllers/tournaments_controller.rb`, `docs/managers/tournament-management.en.md`, and `.planning/PROJECT.md`. No generic advice.

---

## Critical Pitfalls

### Pitfall 1: Two Wizard Partials Exist — Docs Can't Describe Both

**What goes wrong:**
The wizard is rendered by two separate partials: `_wizard_steps.html.erb` (v1, 6 steps with English labels mixed in) and `_wizard_steps_v2.html.erb` (v2, restructured with a new "Setzliste aus Einladung" step 2, a always-visible glossary box, and the wizard hiding itself after `tournament_started`). These are two completely different UIs. A doc that says "Step 2 is ClubCloud sync" is correct for v1 but wrong for v2, where Step 2 is "Import Seeding from Invitation PDF." If `show.html.erb` conditionally renders one or the other, the condition is part of the truth that the doc must either describe or the UX review must resolve.

**Why it happens:**
The developer added v2 as a safe parallel rollout without retiring v1. Doc authors assume one canonical wizard exists.

**How to avoid:**
Before writing a single doc line, run `grep -rn "wizard_steps" app/views/tournaments/show.html.erb` to identify which partial is rendered and under what condition. If both are live, the UX review phase must retire v1 (or document it as the legacy path) before the doc phase begins. Never write docs against a partial that may not be what users see.

**Warning signs:**
- Doc says "Step 2: ClubCloud sync" but wizard shows "Setzliste aus Einladung" as step 2
- Step numbers in doc don't match volunteer's screen
- Both `_wizard_steps.html.erb` and `_wizard_steps_v2.html.erb` are present without a clear gate in `show.html.erb`

**Phase to address:**
UX review phase — confirm canonical partial as a pre-condition before doc phase opens.

---

### Pitfall 2: AASM Has Two States With No Entry Event — Docs Will Fabricate a Path

**What goes wrong:**
The AASM defines 9 states: `new_tournament`, `accreditation_finished`, `tournament_seeding_finished`, `tournament_mode_defined`, `tournament_started_waiting_for_monitors`, `tournament_started`, `tournament_finished`, `results_published`, `closed`. Of these, `accreditation_finished` has no declared event that transitions into it (no `from:` clause in any event points to it as a target). `closed` has no event at all. `results_published` is reachable only via `have_results_published` which has no visible UI surface. A doc author reading the state list as a sequence will either invent wizard steps for these states or describe them as part of the happy path when they are not.

**Why it happens:**
The AASM state list looks like a sequential workflow. In practice, 5 of the 9 states are the wizard path; the rest are legacy, background-set, or future states. This is invisible without tracing each state to a controller action.

**How to avoid:**
Before writing, map each AASM state to a controller action or background job that drives it. States with no inbound transition from any controller are not part of the wizard path — say so explicitly in the doc audit. The doc should describe only controller-driven states.

**Warning signs:**
- Doc section describes an "accreditation step" or "close tournament" action that has no route in `routes.rb`
- A numbered wizard step in the doc has no corresponding `POST`/`GET` action in `TournamentsController`
- `closed` or `accreditation_finished` appears in a wizard step description

**Phase to address:**
Doc rewrite phase — add a pre-condition: each documented step must map to a named controller action.

---

### Pitfall 3: `tournament_started_waiting_for_monitors` Is Transient — Docs Will Skip It and Users Will Be Confused

**What goes wrong:**
`start_tournament!` (called from `TournamentsController#start`) transitions the tournament to `tournament_started_waiting_for_monitors`, not directly to `tournament_started`. A separate event, `signal_tournament_monitors_ready`, transitions to `tournament_started`. The wizard step 6 links to `tournament_monitor_tournament_path` (a GET), not to the start POST. A doc that says "click Start, tournament is running" skips the transient state entirely. If any user-visible loading behavior or waiting screen exists during this state, volunteers who see it will be confused because the doc gave no warning.

**Why it happens:**
The transient state passes quickly during developer testing, making it effectively invisible. The happy path "works" without noticing it.

**How to avoid:**
During the UX review phase, test the actual start flow in a browser and observe whether the transient state surfaces any UI. Check the `tournament_monitor` controller action for whether it triggers `signal_tournament_monitors_ready` automatically or whether the transition requires a separate action. Document what the volunteer sees between clicking Start and the tournament monitor opening — even if it is only a loading flash.

**Warning signs:**
- Doc says "tournament starts immediately" with no mention of monitor initialization
- Volunteer reports "after clicking Start, nothing seems to happen for a moment"
- `tournament_started_waiting_for_monitors` never appears in any doc section or note

**Phase to address:**
UX review phase — observe the transient state behavior before doc phase writes about the start step.

---

### Pitfall 4: The `auto_upload_to_cc` Checkbox Is Not in the Wizard Step Panel — Current Doc Gets the Location Wrong

**What goes wrong:**
The existing EN doc states: "Activation: Checkbox 'Automatically upload results to ClubCloud' in Step 6 of the wizard (default: enabled)." But wizard step 6 in `_wizard_steps_v2.html.erb` contains no form or checkbox — it is a single link button to `tournament_monitor_tournament_path`. The `auto_upload_to_cc` param is consumed by `TournamentsController#start` via `params[:auto_upload_to_cc]`, meaning the checkbox lives in the tournament-monitor start form, not the wizard overview. A volunteer following the doc will look for a checkbox in the wizard step panel that does not exist there.

**Why it happens:**
The doc was written describing intent or a slightly different version of the UI, not the current rendered view. The checkbox exists in the code but in a different location than described.

**How to avoid:**
For every UI element the doc references, verify its location with `grep -rn "auto_upload_to_cc" app/views/`. Document the checkbox in the context where it actually appears (the tournament start form), not where the doc currently claims it is.

**Warning signs:**
- Doc references a checkbox in a wizard step panel; grep finds the checkbox only in a non-wizard view
- A volunteer says "I can't find that option on the page the doc describes"

**Phase to address:**
Doc rewrite phase — every documented UI interaction must be verified against a `grep` before being written.

---

### Pitfall 5: Wizard Step Numbers Are Conditional on Organizer Type — Hard-Coded Step Numbers Break Half the Cases

**What goes wrong:**
Both wizard partials render different step numbers depending on `tournament.organizer.is_a?(Region)`. Club tournaments skip the ClubCloud sync step (or renumber it), so a club officer sees 5 steps numbered 1-5, while a regional officer sees 6 steps. The EN doc refers to "Step 6" for auto_upload activation with no qualifier. A club officer reading the doc will look for a "Step 6" that does not exist on their screen.

**Why it happens:**
Developer experience is always with the regional tournament case. The conditional rendering is present in the code but invisible to anyone not looking for it.

**How to avoid:**
The doc rewrite must describe steps by name, not number. "In the Start step..." rather than "In Step 6...". If steps must be numbered, fork the description explicitly: "For regional tournaments (6 steps)... / For club tournaments (5 steps)...". The volunteer persona filter makes option (a) clearly better — volunteers will not remember whether their tournament is "regional" or "club" type.

**Warning signs:**
- Any doc line contains "Step [0-9]" as a bare number with no organizer-type qualifier
- A club officer reports their screen shows different step numbers than the doc

**Phase to address:**
Doc rewrite phase — enforce step-name-not-number as a writing rule; verify by `grep "Step [0-9]\|Schritt [0-9]"` on the doc output.

---

### Pitfall 6: The "Sympathetic Developer" Terminology Leak

**What goes wrong:**
The doc author is the Rails developer. The current EN doc already opens with: "Technically speaking, Carambus is a hierarchy of web services," "the so-called Carambus API server," "based on standardized HTML protocols." A task-first rewrite will likely re-introduce implementation detail under the guise of explaining *why* something works — "the sync button works because the local server requests from the API server which retrieves from ClubCloud instances" is a developer explanation, not user task guidance. The existing doc puts architecture content first (first 60% of the file) and workflow last, which is the direct product of this pitfall.

**Why it happens:**
Developer-authors conflate "explaining the feature" with "explaining the system." They know why things work and assume users share that curiosity.

**How to avoid:**
Apply the "2-3x/year volunteer" filter to every paragraph: does this sentence tell the user what to do, or what to expect next? If it explains infrastructure, move it to `docs/developers/`. Use the existing doc's "Tournament Management - Detailed Workflow" section as the content nucleus — it describes tasks. Architecture content already lives there erroneously and must move, not be rewritten.

**Warning signs:**
- Rewritten opening paragraph contains a diagram of system layers or the word "server"
- The phrase "technically speaking" appears anywhere in the managers doc
- Any reference to Rails, ActiveRecord, AASM, API server architecture, or gem names in user-facing content

**Phase to address:**
Doc rewrite phase — add a review pass: remove any sentence not answering "what does the user do" or "what will the user see."

---

### Pitfall 7: Bilingual Drift During a Large Rewrite

**What goes wrong:**
DE and EN docs are separate files. A rewrite that proceeds EN-first then "translates" DE will produce structural divergence: section headers won't match (making anchor names differ), callouts added to EN mid-rewrite won't exist in DE, and steps added in one language will be missing in the other. v6.0 closed 17 bilingual gaps; a large v7.0 rewrite will open new ones at a higher rate unless structure is locked before content is written. Diverged anchor names between DE and EN break cross-locale links and make future `diff`-based gap-checking unreliable.

**Why it happens:**
The natural workflow is "write one language, translate the other." Translation happens at the end when the structure is already frozen. Any mid-rewrite addition in one language is not mirrored.

**How to avoid:**
Define the section skeleton (H2/H3 headers with matching anchor names) in both DE and EN before writing any prose. Commit the skeleton. Then write prose for each section in both languages before moving to the next section. Do not write all of EN then translate all of DE.

**Warning signs:**
- EN doc has a "Quick Reference Card" section; DE does not
- `diff <(grep "^#" docs/managers/tournament-management.en.md) <(grep "^#" docs/managers/tournament-management.de.md)` produces mismatches
- Anchor names in DE use German words while EN uses English words

**Phase to address:**
Doc rewrite phase — enforce skeleton-first commit as a gate before prose writing begins.

---

### Pitfall 8: In-App Doc Links Will Point to Sections That Move During the Rewrite

**What goes wrong:**
v7.0 adds in-app links from wizard steps to mkdocs pages. If those links are added in the same milestone as the doc rewrite, they will be written against the current doc structure. When the rewrite moves or renames sections (e.g., the architecture section moves to developer docs), the in-app links will point to removed anchors. `mkdocs build --strict` does not validate external URL references from ERB files — the build passes but the links are broken.

**Why it happens:**
The feature (in-app links) and the doc structure change are in the same milestone. The link targets move while the link sources are being written.

**How to avoid:**
Implement in-app links in a phase that runs *after* the doc rewrite is committed and anchor names are stable. Alternatively, introduce named anchor comments at the top of each wizard-relevant section (e.g., `<!-- anchor: wizard-seeding -->`) that are treated as immutable regardless of section reorganization, and link to those.

**Warning signs:**
- An in-app link is added in the same commit that restructures the target doc
- After `mkdocs build --strict` passes, a manual click-test finds the in-app link hits a 404 within the docs site
- ERB views reference anchor names that no longer exist in the doc after the rewrite

**Phase to address:**
In-app links phase — must be sequenced after the doc rewrite phase closes and anchor names are stable.

---

### Pitfall 9: "Documented But Missing" vs "Intentionally Removed" — No Signal Exists Without Research

**What goes wrong:**
The current EN doc describes features that may or may not exist in code: "Future Project: Simplified Referee Operation," "statistics on training games are planned," and a "Manual upload" path described as a present alternative. The doc has no record of intent. If the UX review surfaces these as "documented but not implemented," there is no way to tell from the doc alone whether they were intentionally deferred (a prior decision), never built (oversight), or removed after building (a decision). The v7.0 constraint evolution says "feature additions are newly allowed," which increases the risk of treating deferred decisions as open invitations without checking prior intent.

**Why it happens:**
Historical context for deferrals lives in developer memory or old commits, not in the doc. The looser constraint makes "implement what the doc promises" feel justified.

**How to avoid:**
For each "documented but not implemented" finding: (1) run `git log --all -S "feature keyword"` to see if it was ever implemented and removed; (2) check PROJECT.md "Out of Scope" and "Key Decisions" sections; (3) if neither has a record, classify as "intent unknown" and require explicit decision before implementing. Never scope implementation on the basis of "the doc says it should exist."

**Warning signs:**
- A UX review finding says "the doc mentions X but there's no controller action for it" and the next phase immediately scopes X as a new feature without a decision record
- The "Future Project" section of the doc gets promoted to an active v7.0 requirement
- `git log` shows a feature was removed with an explanatory commit message that was not consulted

**Phase to address:**
UX review phase — findings output must include "intent unknown" as a category, not just "missing" vs "present."

---

### Pitfall 10: Wizard UX Review Without Real Users Produces Cosmetic Fixes, Not Task Fixes

**What goes wrong:**
A developer reviewing the wizard happy path will notice: visual inconsistency between v1 and v2 partials, button label mismatches ("Setzliste finalisieren" vs "Rangliste abschließen"), mixed DE/EN labels in v1 ("Tournament -> Update Seeding List" in English inside a German context), opacity-25 on inactive steps without tooltips. These are visible, fixable, and satisfying. What the developer will not notice without user observation: whether the seeding/Setzliste/Teilnehmerliste terminology distinction is understood by a volunteer who uses this 2-3 times per year, whether the irreversible finalize confirmation is read or clicked through, whether the wizard hiding itself after `tournament_started` (v2 behavior) confuses a returning volunteer who expects to see where they were.

**Why it happens:**
Cosmetic problems are immediately visible. Task-level friction requires simulating a user who is not the developer. Without UAT data, developers default to what they can see.

**How to avoid:**
Write 3 task scenarios before opening any view file: "Volunteer, 8 players, 2 no-shows, first use this season," "Regional officer, day-of, one late withdrawal," "Club officer running their own tournament." Walk each scenario step by step, narrating user uncertainty, not developer knowledge. Document friction as "user question at this point" — not "visual issue." Cosmetic issues go on a separate list and are not prioritized above task friction.

**Warning signs:**
- UX review issue list is 80% label/styling changes and 0% "user might not know what to do next"
- The "Step 4 is irreversible" confirmation dialog is noted as "working correctly" without evaluating whether a non-technical user would read it before clicking
- Review budget is consumed by renaming buttons without evaluating step ordering or warning placement

**Phase to address:**
UX review phase — write task scenarios before opening any view file; task friction findings must outnumber cosmetic findings before the review is considered complete.

---

### Pitfall 11: Newly Loosened Constraints Create Improvement Cascade Risk

**What goes wrong:**
The constraint evolution says "feature additions are newly allowed." The wizard has 9 AASM states and approximately 30 controller actions. The UX review will surface real friction — but each fix can pull in a new controller action, new AASM event, new view partial, new i18n keys in DE and EN, and new test coverage. "Small UX fixes" that touch the AASM definition are not small: they risk invalidating the 85 tournament AASM characterization tests from v2.1, affecting `tournament_started_waiting_for_monitors` broadcast behavior, and requiring full wizard regression. The looser constraint is an invitation to scope creep if each fix is not classified by impact before being accepted.

**Why it happens:**
Each fix looks small in isolation. "Just add an event" is true of the AASM change in isolation, but not true of its downstream implications in tests, broadcasts, and the two existing wizard partials that both need updating.

**How to avoid:**
Classify each UX finding by impact tier before accepting it into scope: Tier 1 = view/copy change only (no controller, no AASM); Tier 2 = controller action change, no AASM change; Tier 3 = AASM change or new state. Tier 3 findings require an explicit test coverage plan before being scoped. Cap Tier 3 items at 1-2 per milestone. "Fix the label" is Tier 1; "add a confirmation screen between steps 4 and 5" is a new state (Tier 3).

**Warning signs:**
- A UX fix "just adds a state" to the AASM for a cleaner UI transition
- A finding says "add a review screen between finalize and mode selection" — this implies a new AASM state
- Phase scope grows after the UX review to include "while we're in here" changes not in the original review findings

**Phase to address:**
Cross-cutting concern across all v7.0 phases — each phase plan must require explicit impact tier classification before accepting a fix.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Write EN doc first, translate DE after | Faster first draft | Structural drift, anchor mismatch, re-sync effort in v8.0 | Never for structural changes; acceptable for small prose-only corrections |
| Reference wizard step numbers (not names) in docs | Concise | Breaks when organizer type changes numbering; requires doc update on any step reorder | Never — use step names |
| Add in-app doc links in same PR as doc restructure | Single PR | Links point to moved anchors on deploy | Never — sequence as a separate phase |
| Describe AASM states as user steps | Matches source code | States and user steps are different abstractions; "accreditation_finished" has no user meaning | Never in user-facing docs |
| Fix cosmetic UX issues before completing task UX review | Quick wins, visible progress | Cosmetic fixes consume budget; task friction remains invisible until post-release | Only after all task-friction findings are documented and prioritized |
| Implement "documented but missing" features without intent check | Satisfies the doc | May contradict a prior decision to defer or remove the feature | Never without checking `git log` and PROJECT.md first |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| ClubCloud sync in wizard | Doc says sync is "Step 2" — it is optional and conditional on organizer type | Describe as conditional: present for regional tournaments, absent for club tournaments |
| `auto_upload_to_cc` checkbox | Documented as in "Step 6 wizard panel" — actually in the tournament-start form | `grep -rn "auto_upload_to_cc" app/views/` before writing its location |
| mkdocs anchor links from ERB | Written against current doc structure during a doc restructure | Anchor names must be frozen before in-app links are written; sequence phases accordingly |
| AASM `skip_validation_on_save: true` | Characterization tests may not catch silent validation bypass during state transitions | Assert tournament validity explicitly after each AASM transition in new tests |
| Wizard partial (v1 vs v2) | Doc written against one partial that may not be the rendered one | Confirm which partial is canonical in `show.html.erb` before writing any doc |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Irreversible "Finalize" step confirmation uses billiards/developer terminology | Volunteer clicks through without reading; cannot undo seeding | Plain-language confirmation: "After this, you cannot add or remove players. Groups will be calculated from this list." |
| Wizard v2 hides itself after `tournament_started` | Returning volunteer sees no wizard and cannot find where they were | Document explicitly: once started, the wizard is done — use the Tournament Monitor link |
| Disabled steps (opacity-25) have no tooltip | Volunteer does not know which prior step to complete | Add "Complete step [Name] first" tooltip to disabled buttons |
| Meldeliste/Setzliste/Teilnehmerliste glossary is collapsed in `<details>` | Volunteer with 2-3x/year usage cannot recall terminology distinction under time pressure | The v2 partial has a glossary box — make it always visible, not collapsed |
| Mixed DE/EN labels in v1 partial | Volunteer's screen shows English action labels; German doc refers to German labels | Resolve DE/EN label consistency before writing docs that reference UI labels |

---

## "Looks Done But Isn't" Checklist

- [ ] **Wizard partial confirmed:** `grep -rn "wizard_steps" app/views/tournaments/show.html.erb` identifies exactly one canonical partial and the condition under which it renders.
- [ ] **`auto_upload_to_cc` checkbox located:** `grep -rn "auto_upload_to_cc" app/views/` run before writing the doc section that describes this checkbox.
- [ ] **AASM dead states mapped:** `accreditation_finished` and `closed` traced to determine if any controller action or background job transitions into them — not assumed to be wizard steps.
- [ ] **Bilingual skeleton committed:** DE and EN section headers match before any prose is written.
- [ ] **In-app links sequenced after doc freeze:** No in-app doc link written until the doc rewrite phase closes and anchor names are tagged as stable.
- [ ] **Wizard v1 retirement decision made:** Either v1 partial is retired, or both paths are explicitly documented before the doc rewrite begins.
- [ ] **Each "documented but missing" finding triaged:** Categorized as "never implemented," "was removed," or "intent unknown" before any implementation is scoped.
- [ ] **Each UX fix classified by tier:** Tier 1 (view only), Tier 2 (controller change), Tier 3 (AASM change) — Tier 3 items have a test coverage plan before entering scope.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Doc describes wrong wizard partial | MEDIUM | Identify canonical partial, rewrite affected sections, update anchors, re-check in-app links |
| Step numbers in doc wrong for club users | LOW | Replace all step numbers with step names in a single pass |
| In-app links point to moved anchors | LOW | Add stable anchor comments to doc, update in-app link targets |
| Bilingual structural drift | HIGH | Diff H2/H3 between DE/EN, reconcile structure, retranslate affected sections |
| AASM Tier 3 fix breaks characterization tests | HIGH | Revert AASM change, write new characterization tests first, then re-implement |
| "Future feature" implemented without intent check | MEDIUM | Check git history and PROJECT.md, document the decision, re-scope if feature was previously deferred |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Two wizard partials, wrong one documented | UX review phase (pre-condition) | `grep -rn "wizard_steps" app/views/tournaments/show.html.erb` confirms one canonical partial |
| AASM dead states fabricated as wizard steps | Doc rewrite phase | Each documented step maps to a named controller action; dead states explicitly annotated |
| Transient waiting state missing from docs | UX review phase | Happy-path start flow observed in browser; transient state behavior documented or confirmed invisible |
| `auto_upload_to_cc` in wrong doc location | Doc rewrite phase | Checkbox location confirmed by `grep` before writing |
| Step numbers conditional on organizer type | Doc rewrite phase | Doc output contains no bare "Step N" without organizer qualifier; verified by grep |
| Sympathetic developer terminology leak | Doc rewrite phase | Review pass removes every sentence not answering "what does user do/see" |
| Bilingual drift | Doc rewrite phase (skeleton gate) | `diff` of H2/H3 headers between DE/EN passes before prose phase begins |
| In-app links to moving targets | In-app links phase (after doc freeze) | In-app links phase does not open until doc rewrite phase is closed and anchors are tagged stable |
| "Documented but missing" intent unknown | UX review phase | Each finding labeled "never implemented / was removed / intent unknown"; no Tier-3 feature scoped without decision record |
| Cosmetic over task UX fixes | UX review phase | Task-scenario findings written before any view file is opened; task findings outnumber cosmetic findings |
| Improvement cascade from loosened constraints | Cross-cutting all v7.0 phases | Each fix tier-classified; Tier 3 items have test coverage plan before scoping |

---

## Sources

- Direct inspection: `app/models/tournament.rb` AASM block (lines 271-311) — 9 states, event definitions, missing inbound transitions for `accreditation_finished` and `closed`
- Direct inspection: `app/views/tournaments/_wizard_steps.html.erb` and `_wizard_steps_v2.html.erb` — two parallel wizard UIs with different step structure and numbering
- Direct inspection: `app/controllers/tournaments_controller.rb` lines 288-350 — `start` action reads `auto_upload_to_cc` from params; `start_tournament!` transitions to `tournament_started_waiting_for_monitors` not `tournament_started`
- Direct inspection: `docs/managers/tournament-management.en.md` — current claims about step numbers, `auto_upload_to_cc` location, architecture-first structure
- Direct inspection: `.planning/PROJECT.md` — v7.0 scope, constraint evolution ("behavior preservation scoped"), out-of-scope decisions
- Pattern from v6.0: 17 bilingual gaps closed in the previous milestone confirms structural drift is a recurring pattern in this codebase's doc workflow

---
*Pitfalls research for: v7.0 Manager Experience — task-first doc rewrite + wizard UX review on Carambus Rails app*
*Researched: 2026-04-13*
