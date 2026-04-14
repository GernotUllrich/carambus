# Phase 37: In-App Doc Links - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-14
**Phase:** 37-in-app-doc-links
**Areas discussed:** Locale-aware mkdocs_link + LINK-01 URL shape, Cross-locale stable anchors (LINK-04 prerequisite), Wizard step partial API + link placement, LINK-03 form help scope + placement

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Locale-aware mkdocs_link + LINK-01 URL shape | REQUIREMENTS vs. actual mkdocs build DE pattern; index slash; link text source | ✓ |
| Cross-locale stable anchors (LINK-04 prerequisite) | Explicit {#id} attrs vs. server-side anchor lookup vs. skip anchors | ✓ |
| Wizard step partial API + link placement | `_wizard_step.html.erb` locals + visual placement + inline step retrofit | ✓ |
| LINK-03 form help scope + placement | Which views, where the link sits, anchor reuse | ✓ |

**User's choice:** All 4 areas selected.

---

## Area 1: Locale-aware mkdocs_link + LINK-01 URL shape

### Q1: LINK-01 URL shape for DE locale

| Option | Description | Selected |
|--------|-------------|----------|
| Match docs_page.html.erb: DE root, EN prefix (Recommended) | DE → /docs/{path}/, EN → /docs/en/{path}/; REQUIREMENTS.md wording treated as typo | ✓ |
| Follow REQUIREMENTS.md: both locales prefixed | DE → /docs/de/{path}/, EN → /docs/en/{path}/; requires mkdocs config change or Nginx redirect | |

**User's choice:** Match docs_page.html.erb pattern.
**Notes:** Zero mkdocs config changes. Code is authoritative over REQUIREMENTS prose for this one.

### Q2: Index page trailing-slash handling

| Option | Description | Selected |
|--------|-------------|----------|
| Replicate docs_page.html.erb logic exactly (Recommended) | Non-index → trailing slash; `/index` or bare `index` → no trailing slash | ✓ |
| Always add trailing slash | Simpler helper but produces /docs/index/ which mkdocs may redirect | |
| Never add trailing slash | Causes 301 on every click under `use_directory_urls: true` | |

**User's choice:** Replicate existing logic.

### Q3: Link text source

| Option | Description | Selected |
|--------|-------------|----------|
| Require caller to pass text: (Recommended) | Remove humanize fallback; callers pass i18n-looked-up strings | ✓ |
| Auto-derive via i18n key lookup | Helper looks up `docs.link_text.{path}` with fallback | |
| Keep current humanize fallback | Produces English text in DE views | |

**User's choice:** Require caller to pass text.
**Notes:** No callers exist yet, so removal is non-breaking. Fallback produces wrong-language text — unacceptable.

---

## Area 2: Cross-locale stable anchors (LINK-04 prerequisite)

### Q1: Anchor strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Add explicit {#stable-id} attrs to both .de.md and .en.md (Recommended) | Phase 37 edits both doc files to add `{#seeding-list}` etc. on target headings; `attr_list` already enabled | ✓ |
| Compute locale-specific anchors server-side | Helper accepts symbolic key + Ruby-side lookup table; fragile — silently breaks on heading edits | |
| Skip anchor fragments (fails LINK-04) | Link only to page top | |

**User's choice:** Explicit {#id} attrs in both doc files.
**Notes:** Durable, zero helper complexity. `attr_list` markdown extension already in mkdocs.yml.

### Q2: Anchor scope

| Option | Description | Selected |
|--------|-------------|----------|
| Exactly 4 anchors, minimum to exceed LINK-04's ≥3 (Recommended) | seeding-list, mode-selection, start-parameters, participants | ✓ |
| All 6 wizard happy-path steps get anchors | Exhaustive; more doc edits and review surface | |
| Exactly 3 anchors (LINK-04 floor) | Single-point failure risk | |

**User's choice:** Exactly 4 anchors.

### Q3: Anchor naming

| Option | Description | Selected |
|--------|-------------|----------|
| English-only kebab-case IDs (Recommended) | Same `{#seeding-list}` in both .de.md and .en.md | ✓ |
| Bilingual/prefixed (e.g., #de-seeding-list / #en-seeding-list) | Forces helper to know locale — same problem as Q1 option 2 | |

**User's choice:** English-only IDs.

---

## Area 3: Wizard step partial API + link placement

### Q1: Partial API

| Option | Description | Selected |
|--------|-------------|----------|
| New optional `docs_path:` and `docs_anchor:` locals (Recommended) | Matches existing `local_assigns.fetch(...)` pattern; backward-compatible | ✓ |
| Single `docs_url:` local — caller builds the URL | Pushes URL-building complexity into callers | |
| New `docs:` hash with path/anchor/text keys | More flexible but unjustified for 2-3 fields | |

**User's choice:** `docs_path:` + `docs_anchor:` separate locals.

### Q2: Link placement

| Option | Description | Selected |
|--------|-------------|----------|
| Below the `<p>` help text inside the collapsible `<details>` (Recommended) | Preserves Phase 36b visual rhythm; surfaces on active step via existing auto-open | ✓ |
| Next to the action button in `wizard-step-actions` | Competes with primary CTA; clutters action row | |
| In the step header next to the title icon | Adds header clutter | |

**User's choice:** Inside `<details>` help block.

### Q3: Inline step retrofit

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — consistent doc link on all 6 wizard steps (Recommended) | Inline steps 1/2/6 get `mkdocs_link` calls with the same placement | ✓ |
| Only the 3 partial-based steps get links | Fails success criterion 2 ("All 6 happy-path wizard steps") | |

**User's choice:** Retrofit all 6 steps.

---

## Area 4: LINK-03 form help scope + placement

### Q1: LINK-03 scope mapping

| Option | Description | Selected |
|--------|-------------|----------|
| All 5 in scope, each view gets ONE link (Recommended) | 4 views cover 5 contexts: parse_invitation, define_participants, finalize_modus, tournament_monitor (covers both table assignment + start settings) | ✓ |
| Only the 3 pre-start views | Fails LINK-03 table assignment / start settings criterion | |
| Only 2 high-traffic views + defer the rest | Fails LINK-03 | |

**User's choice:** All 5 contexts / 4 views.

### Q2: `tournament_monitor.html.erb` relationship to Phase 36b tooltips

| Option | Description | Selected |
|--------|-------------|----------|
| Single prominent `📖 Detailanleitung im Handbuch` link at form top (Recommended) | One header link to `#start-parameters`; Phase 36b's 13 tooltips untouched | ✓ |
| Extend each tooltip to include a `Mehr im Handbuch →` sub-link | 13 new sub-links; overengineered | |
| Both header link AND 2-3 key field sub-links | Middle ground; defer until feedback | |

**User's choice:** Single form-top link, tooltips untouched.

### Q3: Pre-start view link placement

| Option | Description | Selected |
|--------|-------------|----------|
| Below page H1/title in a small `📖 Hilfe:` info box (Recommended) | Consistent location across views; discoverable; blue Tailwind info strip | ✓ |
| Footer region below the form | Out of primary scan path | |
| Flash-message style banner (dismissable) | Disappears on second visit — bad for 2×/year volunteers | |

**User's choice:** Below H1/title info box.

### Q4: Anchor reuse

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse the 4 wizard anchors where they line up (Recommended) | Wizard + form share the same 4 anchors | ✓ |
| Introduce a separate set of form-oriented anchors | Duplicates effort | |

**User's choice:** Reuse the 4 wizard anchors.

---

## Claude's Discretion

- Exact Tailwind class tuning (padding, margins) for the new info boxes — keep consistent with Phase 36b conventions.
- Whether to extract a private `mkdocs_url` helper alongside `mkdocs_link` for raw-URL use cases — recommended to keep `mkdocs_link` as `link_to` wrapper.
- Exact placement of new i18n keys in `tournaments.docs.*` sub-namespace inside `de.yml` / `en.yml`.
- Whether to add a Capybara system test per locale — recommended yes, but scope is planner's call.
- Test fixture changes — only if existing fixtures can't reach an active-step wizard view.

## Deferred Ideas

- Per-field doc sub-links in `tournament_monitor.html.erb` tooltips (rejected as overengineered).
- Separate form-oriented anchor set (rejected; reuse wizard anchors).
- Flash-banner style doc links (rejected; dismissable fails 2×/year volunteer use case).
- Ruby-side anchor registry lookup table (rejected; YAGNI for 4 anchors).
- mkdocs config change to force `/docs/de/` prefix (rejected; too much blast radius).
- Adding stable anchors to doc files beyond `tournament-management.{de,en}.md` (deferred to future linking phases).
- Full per-step Capybara coverage (deferred; one test per locale is in scope).
