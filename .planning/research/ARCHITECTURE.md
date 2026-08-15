# Architecture Research

**Domain:** Brownfield Rails app — docs-first manager UX improvements (v7.0)
**Researched:** 2026-04-13
**Confidence:** HIGH (all findings derived from reading actual source files)

---

## System Overview

```
Browser (manager, local_server? == true)
    │
    ├── GET /tournaments/:id  →  show.html.erb
    │       ├── render 'show' partial (tournament details card)
    │       ├── render 'wizard_steps_v2'   (conditional: tournament_director? && local_server?)
    │       │       ├── _wizard_step.html.erb  (generic step card partial)
    │       │       └── TournamentWizardHelper  (wizard_step_status, step_class, step_icon, …)
    │       └── render 'tournament_status'
    │
    ├── Wizard action routes (POST member routes on tournaments resource)
    │       reload_from_cc            →  TournamentsController#reload_from_cc
    │       use_clubcloud_as_participants  →  TournamentsController#use_clubcloud_as_participants
    │       finish_seeding            →  TournamentsController#finish_seeding → tournament.finish_seeding! (AASM)
    │       finalize_modus (GET)      →  TournamentsController#finalize_modus  (renders selection page)
    │       select_modus              →  TournamentsController#select_modus   → tournament.finish_mode_selection! (AASM)
    │       start                     →  TournamentsController#start          → tournament.start_tournament! (AASM)
    │
    └── Documentation routes
          GET /docs_page/:locale/*path  →  StaticController#docs_page   (Markdown in Rails layout)
          GET /docs/*path               →  DocsController#show           (pre-built MkDocs HTML)
```

The wizard is not a multi-page flow. It lives entirely on `show.html.erb`. Each step renders as a card. The active step's button triggers a separate controller action which redirects back to `show`. AASM state is the authoritative source of wizard progress.

---

## Component Responsibilities

| Component | File | Responsibility |
|-----------|------|----------------|
| Wizard UI (current) | `app/views/tournaments/_wizard_steps_v2.html.erb` | 6-step wizard rendered on show; reads AASM state via helper |
| Generic step partial | `app/views/tournaments/_wizard_step.html.erb` | Single step card; accepts: number, title, status, action, info, help, warning, danger |
| Wizard state helper | `app/helpers/tournament_wizard_helper.rb` | Maps AASM states → step numbers; computes :active/:completed/:pending per step |
| Controller wizard actions | `app/controllers/tournaments_controller.rb` | ~30 actions total; key wizard ones: `finish_seeding`, `finalize_modus`, `select_modus`, `start` |
| AASM state machine | `app/models/tournament.rb` | 9 states: new_tournament → accreditation_finished → tournament_seeding_finished → tournament_mode_defined → tournament_started → playing_groups → playing_finals → finals_finished → results_published |
| Docs serving (built site) | `app/controllers/docs_controller.rb` | Serves pre-built MkDocs HTML from `public/docs/` via `GET /docs/*path` |
| Docs serving (Markdown) | `app/controllers/static_controller.rb` | `docs_page` action: reads raw `.{locale}.md` files from `docs/`, renders via Redcarpet inside Rails layout |
| Doc link helpers | `app/helpers/application_helper.rb` | `docs_page_link(path, locale:, text:)` and `mkdocs_link(path, locale:, text:)` — both exist already |
| i18n plugin | `mkdocs.yml` | mkdocs-static-i18n with suffix convention: `file.de.md` / `file.en.md`; German is default locale |

---

## Existing Infrastructure for In-App Doc Links

This is the most important finding: the plumbing already exists. No new Rails infrastructure is needed.

### Two link helper methods (both in `app/helpers/application_helper.rb`)

**`docs_page_link(path, locale: nil, text: nil, options: {})`**
- Builds URL via `docs_page_path(path: path, locale: locale)`
- Routes to `StaticController#docs_page` which reads the `.{locale}.md` source file from `docs/` and renders it in the Rails application layout
- Locale defaults to `I18n.locale.to_s` — already locale-aware
- Example path: `'managers/tournament-management'`

**`mkdocs_link(path, locale: nil, text: nil, options: {})`**
- Builds URL as `/docs/#{path}` directly
- Routes to `DocsController#show` which serves the pre-built MkDocs HTML from `public/docs/`
- Opens `target: '_blank'` by default
- Does not inject locale into the URL — the MkDocs site has its own language switcher

### Route structure

```
GET /docs_page/:locale/*path   → StaticController#docs_page   (locale-aware, in-app Markdown render)
GET /docs_page/*path           → StaticController#docs_page   (defaults locale: 'de')
GET /docs/*path                → DocsController#show           (built site, layout: false)
```

### Recommendation: use `mkdocs_link` for wizard step help links

`mkdocs_link` is the right choice for in-wizard doc links because:
- It opens the full MkDocs site with navigation, search, and the language switcher intact
- The user can browse related pages without leaving docs context
- `target: '_blank'` keeps the wizard session active
- Locale is handled by the MkDocs site itself (no URL mismatch)

Use `docs_page_link` only if you want to render the doc inline within the Rails layout (no MkDocs chrome). Not appropriate for contextual help links.

Anchor links to specific sections work with both helpers: append `#section-heading-slug` to the path argument. MkDocs generates anchor IDs from heading text via the toc extension (e.g., heading `## Seeding List` → `#seeding-list`).

---

## Bilingual Doc Structure Constraints

The mkdocs-static-i18n plugin uses the **suffix convention**: `filename.{locale}.md`. German is the default locale (`default: true`).

```
docs/managers/
├── tournament-management.de.md    ← German source (default)
├── tournament-management.en.md    ← English source
├── index.de.md
├── index.en.md
...
```

### Nav entry for a page

```yaml
# mkdocs.yml nav
- Tournament Management: managers/tournament-management.md
```

The nav entry uses the base filename (no locale suffix). The i18n plugin resolves to the correct locale file at build time.

### nav_translations block

Every nav entry title that should appear in German must have an entry in the `nav_translations` block under `locale: de`. The current block has approximately 60 entries. Adding a new page requires three coordinated changes:

1. Add a nav entry under `Managers:` in the `mkdocs.yml` nav section
2. Add `New Page Title: Übersetzter Titel` to `nav_translations` under `locale: de`
3. Create both `docs/managers/new-page.de.md` and `docs/managers/new-page.en.md`

Missing any of the three causes one of: page unreachable from nav, English title showing for German users, or a strict-build warning. The `mkdocs build --strict` flag (used since v6.0) will catch missing files.

### Constraint: fallback_to_default: true

When `.en.md` is missing, the i18n plugin silently serves the German version to English users. This means a missing English pair is not a hard error — it's invisible staleness. The convention is to always create both files together.

---

## Architecture Decisions for v7.0 New Work

### Q1: Replace or add alongside existing tournament-management doc?

**Replace in place.** The file is already in the nav as `Tournament Management: managers/tournament-management.md`. Replacing both `.de.md` and `.en.md` with task-first content requires no nav changes, no nav_translations changes, and no new file registrations.

Adding a quickstart file alongside the existing one would require: a new nav entry, a new nav_translations entry, and two new files. That is justified only if the two documents serve genuinely different use cases (quickstart vs. complete reference). For v7.0, a single file with a task-first opening section and an architecture appendix serves both use cases without nav complexity. Splitting can happen in a future milestone if the file grows unwieldy.

### Q2: Quick reference card — separate page or section?

**Separate page.** A printable one-page checklist requires either a dedicated print stylesheet applied only to that page, or at minimum a standalone section that can be opened directly and printed without surrounding navigation. Neither is achievable by embedding in the main doc. The card should be `docs/managers/quick-reference.{de,en}.md` with a nav entry and nav_translations entry.

If "printable" means visual compactness rather than literal print-to-paper, the card can instead be an admonition block inside the main tournament-management doc — zero nav changes. The decision turns on whether managers need to actually print it (paper checklists at a billiard venue) or just reference it on screen.

### Q3: In-app doc links — mechanism

The `mkdocs_link` helper already exists. The integration point is `_wizard_step.html.erb`. The cleanest approach is to add an optional `docs_path` local variable to that partial. When present, it renders a small help link below the step's help text.

Change to `_wizard_step.html.erb`:

```erb
<% docs_path = local_assigns.fetch(:docs_path, nil) %>

...within the help block...
<% if docs_path.present? %>
  <div class="step-docs-link">
    <%= mkdocs_link(docs_path,
        text: I18n.t('wizard.read_in_docs', default: 'Hilfe in der Dokumentation'),
        options: { class: 'wizard-docs-link text-xs text-blue-600 hover:underline' }) %>
  </div>
<% end %>
```

Then in `_wizard_steps_v2.html.erb`, each step render call passes a `docs_path:`:

```erb
<%= render 'wizard_step',
    number: ...,
    title: ...,
    docs_path: 'managers/tournament-management#seeding-list',
    ... %>
```

This approach adds zero new helpers, zero new routes, and makes the docs link optional (steps without a doc anchor simply omit `docs_path:`).

For locale: `mkdocs_link` already defaults to `I18n.locale.to_s` — no additional work needed. However, note that the MkDocs built site handles its own language toggle; the `locale` parameter in `mkdocs_link` is not used in the URL construction (it only builds `/docs/#{path}`). The built site language matches wherever the user last toggled the MkDocs language switcher, not the Rails app locale. This is acceptable behavior for contextual help links.

### Q4: Wizard UX review output — where does it live?

The review is a temporary execution artifact, not a permanent doc. It should live in `.planning/wizard-review.md` and be consumed during the fix phase. It is not committed to the docs site.

The review findings drive two downstream outputs:
- Code changes in `TournamentsController` and wizard view partials
- Content corrections in `docs/managers/tournament-management.{de,en}.md`

Once both outputs are complete, the review note is stale. It can remain in `.planning/` for historical reference but should not be published.

### Q5: Build order

The dependencies create a strict ordering:

```
Step 1: Rewrite docs (task-first rewrite of tournament-management.{de,en}.md)
         ↓ docs now describe the intended happy path
Step 2: Quick reference card (can run in parallel with Step 1)
         ↓ independent of wizard state; just a checklist
Step 3: UX review of wizard against the rewritten docs
         ↓ surfaces mismatches: things docs say should work but don't, or wizard friction not covered
Step 4: Fix mismatches (code changes in TournamentsController/partials + doc corrections)
         ↓ wizard and docs are now aligned
Step 5: Re-read docs for consistency check (short pass)
         ↓ verifies corrections from Step 4 landed correctly in docs
Step 6: Add in-app doc links to wizard steps
         ↓ links now point to accurate, aligned documentation
```

The key dependency is Steps 1 → 3: the review has no authoritative spec without the rewritten docs. Adding links before the review (Step 6 before Step 3) would point to docs that may still be inaccurate. Fixing wizard code before rewriting docs means fixing against no specification.

### Q6: Link from wizard view to doc — which route

Use `mkdocs_link` with the pre-built site path and a section anchor:

```erb
mkdocs_link('managers/tournament-management#step-3-participants',
    text: t('wizard.read_in_docs', default: 'Hilfe in der Dokumentation'),
    options: { class: 'wizard-docs-link' })
```

This renders as: `<a href="/docs/managers/tournament-management/#step-3-participants" target="_blank" rel="noopener">`.

The `DocsController#show` serves `public/docs/managers/tournament-management/index.html` (the MkDocs-built file). The browser handles the `#anchor` scroll. MkDocs generates anchor slugs from heading text via the `toc` extension — so headings in the rewritten doc must be written with the anchor URLs in mind, or the anchor list must be determined after writing.

Do not use `docs_page_link` for wizard links. That helper renders raw Markdown in the Rails layout, stripping MkDocs navigation, search, and styles. It is appropriate for in-app tutorial-style content, not for contextual help links from the wizard.

### Q7: Bilingual constraint summary for new page additions

Every new page in `docs/managers/` requires these three coordinated changes in a single commit:

| Change | File | Risk if missed |
|--------|------|----------------|
| Add nav entry | `mkdocs.yml` under `Managers:` | Page unreachable from nav |
| Add nav_translations entry | `mkdocs.yml` under `locale: de → nav_translations` | English nav title shown for German users |
| Create `new-page.de.md` | `docs/managers/` | Build fails or lang-switch shows 404 |
| Create `new-page.en.md` | `docs/managers/` | English users silently get German content |

Run `mkdocs build --strict` before committing any nav change to catch mismatches early.

---

## Data Flow: Wizard Step Interaction

```
User on /tournaments/:id (show page)
    │
    ├── _wizard_steps_v2.html.erb renders 6 step cards
    │       For each step: wizard_step_status(tournament, N) → :active/:completed/:pending
    │       Status derived from tournament.state (AASM) via TournamentWizardHelper
    │
    ├── User clicks active step button
    │       button_to → POST /tournaments/:id/{action}  (or GET for finalize_modus, define_participants)
    │
    ├── TournamentsController action
    │       if AASM event: tournament.{event}! → new state saved to DB
    │       redirect_to tournament_path(@tournament)  (always redirects back to show)
    │
    └── show.html.erb re-renders
            wizard_current_step now returns N+1
            step N: :completed, step N+1: :active
```

```
User clicks "Help in docs" link (new in v7.0)
    │
    ├── mkdocs_link('managers/tournament-management#section-anchor', ...)
    │       Renders: <a href="/docs/managers/tournament-management/#section-anchor" target="_blank">
    │
    ├── DocsController#show (GET /docs/managers/tournament-management/)
    │       Reads: public/docs/managers/tournament-management/index.html  (pre-built MkDocs HTML)
    │       Serves with layout: false (MkDocs page is self-contained HTML with its own head/nav)
    │
    └── New browser tab: MkDocs page, scrolled to anchor
            MkDocs language switcher available for DE/EN toggle
            Back to app: original wizard tab still open
```

---

## Integration Points for v7.0 Work

### Files to Modify or Create

| File | Action | Nav impact |
|------|--------|-----------|
| `docs/managers/tournament-management.de.md` | Replace content (task-first rewrite) | No change — existing nav entry |
| `docs/managers/tournament-management.en.md` | Replace content (same rewrite in English) | No change |
| `docs/managers/quick-reference.de.md` | Create new | Add nav entry + translation |
| `docs/managers/quick-reference.en.md` | Create new | Same |
| `mkdocs.yml` | Add nav + nav_translations for quick-reference | Only for new page |
| `app/views/tournaments/_wizard_step.html.erb` | Add optional `docs_path` local variable | None |
| `app/views/tournaments/_wizard_steps_v2.html.erb` | Pass `docs_path:` to each step render call | None |
| `app/helpers/application_helper.rb` | No change needed | None |
| `app/helpers/tournament_wizard_helper.rb` | No change needed unless review finds bugs | None |
| `app/controllers/tournaments_controller.rb` | Targeted fixes only for documented-but-missing features surfaced by review | None |
| `.planning/wizard-review.md` | Create during review phase (ephemeral, not in docs) | None |

### What Does Not Change

- `DocsController` — already serves built site correctly
- `StaticController#docs_page` — already handles locale-aware Markdown rendering
- Routes — `docs_page` and `docs` routes already exist
- AASM states on Tournament model — not in scope for v7.0
- `TournamentWizardHelper` step-status logic — correct as-is

---

## Anti-Patterns

### Anti-Pattern 1: Hardcoding absolute doc URLs in wizard views

**What people do:** Write `<a href="https://gernotullrich.github.io/carambus/managers/tournament-management/">`.

**Why it's wrong:** Breaks on local/self-hosted installations. The app is deployed on club network servers without internet access. The docs are served from `public/docs/` via `DocsController`.

**Do this instead:** Use `mkdocs_link('managers/tournament-management#section')` which builds `/docs/...` relative paths that work on any deployment.

### Anti-Pattern 2: Adding a doc page without the three-part nav commit

**What people do:** Create both `.de.md` and `.en.md` files, then run `mkdocs build --strict` and find the page missing from nav.

**Why it's wrong:** Nav entry omission means the page is unreachable. nav_translations omission means the German nav tab shows the English title. These three things are atomically required.

**Do this instead:** Add nav entry, nav_translations entry, and both locale files in a single commit. Run `mkdocs build --strict` before committing.

### Anti-Pattern 3: Rewriting docs without first reviewing the wizard

**What people do:** Write docs describing how the wizard should work, add in-app links pointing to those docs, discover the wizard does something different.

**Why it's wrong:** In-app links point to inaccurate docs. The user follows doc instructions, the wizard behaves differently, trust is broken.

**Do this instead:** Draft docs first (for the spec), review wizard behavior against the draft, make corrections, then publish. The review phase must close the loop before links go live.

### Anti-Pattern 4: Using `docs_page_link` for wizard step contextual help

**What people do:** Use `docs_page_link` because it "stays in the app."

**Why it's wrong:** `docs_page_link` renders raw Markdown in the Rails layout via Redcarpet. No MkDocs navigation, no search, no language switcher, no proper heading anchors. The experience is a stripped-down text dump, not the documentation site users expect.

**Do this instead:** Use `mkdocs_link` which opens the pre-built MkDocs site in a new tab with full navigation intact.

### Anti-Pattern 5: Adding wizard doc links before the doc rewrite is done

**What people do:** Add in-app links in the first phase to "get them out of the way," pointing to the existing architecture-heavy `tournament-management.en.md`.

**Why it's wrong:** Links point to the wrong doc. The current doc is the problem being fixed in v7.0. Link placement is Step 6 (last) for this reason.

**Do this instead:** Follow the build order: docs → review → fix → links.

---

## Sources

All findings are HIGH confidence, derived from reading source files directly.

- `app/views/tournaments/show.html.erb` — conditional wizard rendering (`wizard_steps_v2` only for tournament_director? && local_server?)
- `app/views/tournaments/_wizard_steps_v2.html.erb` — active wizard version; 6 steps; inline styles present
- `app/views/tournaments/_wizard_step.html.erb` — generic step partial API; accepted locals documented in file header
- `app/helpers/tournament_wizard_helper.rb` — AASM state → wizard step number mapping; :active/:completed/:pending logic
- `app/controllers/tournaments_controller.rb` — all wizard controller actions and their redirect targets
- `app/helpers/application_helper.rb` — `docs_page_link` and `mkdocs_link` helpers (both at lines ~95–151)
- `app/controllers/static_controller.rb` — `docs_page` action; locale resolution; Redcarpet rendering
- `app/controllers/docs_controller.rb` — `show` action; serves `public/docs/` static files
- `config/routes.rb` — `docs_page/:locale/*path` (line 328), `docs/*path` (line 342)
- `mkdocs.yml` — nav structure; i18n plugin config (suffix, fallback_to_default, nav_translations ~60 entries)
- `docs/managers/tournament-management.en.md` — current content: architecture-heavy, no task-first opening
- `docs/managers/index.en.md` — manager hub page; links to tournament-management.md
- `.planning/PROJECT.md` — v7.0 milestone scope; constraints; core value statement

---

*Architecture research for: v7.0 Manager Experience — task-first docs + wizard UX review + in-app doc linking*
*Researched: 2026-04-13*
