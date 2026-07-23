# Stack Research: Manager Experience (v7.0)

**Domain:** Volunteer-friendly tournament manager UX + task-first documentation
**Researched:** 2026-04-13
**Confidence:** HIGH — all findings based on reading actual codebase files; no guesses about installed versions or capabilities

---

## Decision Summary

**No new gems. No new pip packages required for the core v7.0 scope.**

Every capability needed — printable reference card, in-app docs deep links, wizard UX enhancements — can be delivered with what is already installed. The two things that need adding are both cost-free: a `print.css` file (new file, no dependency) and a bug fix in the existing `mkdocs_link` helper (locale prefix missing for English). The wizard already has progress bars, step icons, and contextual help; no JS library is justified against the volunteer persona filter.

---

## Recommended Stack

### Core Technologies (already installed — do not change)

| Technology | Version | Purpose | Status |
|------------|---------|---------|--------|
| mkdocs-material | 9.6.15 (installed) / >=9.5.0 (pinned) | Docs site theme | Already working; print via custom CSS |
| mkdocs-static-i18n | 1.3.0 (installed) / >=1.0.0 (pinned) | DE/EN bilingual docs (suffix structure) | Already working; locale URLs confirmed |
| pymdownx.tasklist | bundled with pymdown-extensions 10.16 | `- [ ]` checkbox syntax for quick-reference card | Already enabled in mkdocs.yml |
| pymdownx (attr_list, md_in_html) | bundled | CSS class injection in Markdown for print page-breaks | Already enabled in mkdocs.yml |
| Rails 7.2 / Tailwind CSS | existing | Wizard UI | Wizard already fully implemented |
| Stimulus.js | existing | In-app interactivity | No new controller needed for help links |
| ApplicationHelper | existing | `mkdocs_link` + `docs_page_link` helpers | Both exist; `mkdocs_link` has a locale bug to fix |

### Supporting Additions (CSS-only, zero dependencies)

| Addition | File | Purpose | Work Required |
|----------|------|---------|---------------|
| Print stylesheet | `docs/stylesheets/print.css` (new) | Hide nav chrome for browser print; page setup for A4 | Write ~30 lines of `@media print` CSS |
| Register print.css | `mkdocs.yml` `extra_css` list | Activates print CSS for all pages | Add one line |
| Fix `mkdocs_link` locale bug | `app/helpers/application_helper.rb:149` | Locale-aware deep links from wizard steps | Change 1 line |

### Optional pip addition (only if offline PDF export is a hard requirement)

| Package | Version | Purpose | Recommendation |
|---------|---------|---------|----------------|
| mkdocs-print-site-plugin | ~2.3.x | Merges all nav pages into single `/print_page/` URL | Do NOT add for v7.0. See anti-recommendations below. |

---

## mkdocs-material Print Features (verified against installed 9.6.15)

mkdocs-material OSS does **not** have a built-in print plugin. It does provide clean semantic HTML that prints correctly with custom `@media print` CSS. This is the right approach for a single quick-reference card page.

### What is already available (no additions needed)

**`@media print` CSS hooks** — The 9.x theme uses well-known semantic CSS classes. Hiding nav/header/footer is straightforward by targeting `.md-header`, `.md-sidebar--primary`, `.md-sidebar--secondary`, `.md-footer`, `.md-tabs`.

**`attr_list` extension** — Already enabled in mkdocs.yml. Allows adding CSS classes directly in Markdown: `## Before the Tournament { .print-break }`. Use this to insert `page-break-before: always` at section boundaries in the reference card.

**`pymdownx.tasklist`** — Already enabled. `- [ ]` / `- [x]` renders as checkboxes in browser and prints correctly as a physical checklist.

### Minimum print.css implementation

```css
@media print {
  /* Hide navigation chrome */
  .md-header,
  .md-tabs,
  .md-sidebar,
  .md-footer,
  .md-search,
  [data-md-component="toc"],
  .md-top,
  .md-source {
    display: none !important;
  }

  /* Full-width content without sidebar offset */
  .md-content {
    max-width: 100% !important;
    margin: 0 !important;
    padding: 0 !important;
  }

  .md-main__inner {
    margin-top: 0 !important;
  }

  /* Page setup (A4 portrait, standard margins) */
  @page {
    size: A4 portrait;
    margin: 15mm;
  }

  /* Page breaks: use { .print-break } in Markdown with attr_list */
  .print-break {
    page-break-before: always;
  }

  /* Print tasklist checkboxes at legible size */
  .task-list-item input[type="checkbox"] {
    display: inline-block !important;
    width: 14px;
    height: 14px;
    margin-right: 6px;
  }
}
```

**Confidence note:** The CSS selectors above are based on mkdocs-material 9.x DOM structure (training knowledge, Aug 2025 cutoff). Web access was blocked during research so selectors could not be re-verified against live 9.6.15 docs. The class names `.md-header`, `.md-sidebar`, `.md-footer`, `.md-tabs` are stable across the 9.x series and unlikely to have changed. If any selector does not work, inspect the rendered HTML with browser DevTools.

Register in mkdocs.yml:
```yaml
extra_css:
  - stylesheets/extra.css
  - stylesheets/print.css   # add this line
```

---

## In-App → mkdocs Deep Linking (Rails helpers)

### Current state (verified by reading codebase)

Two helpers already exist in `app/helpers/application_helper.rb`:

**`docs_page_link(path, locale:, text:, options:)`** (line 135) — links to the Rails-embedded doc proxy route (`docs_page_path`). Renders markdown inline within the app layout. Use this when you want embedded doc content inside the app.

**`mkdocs_link(path, locale:, text:, options:)`** (line 143) — links directly to the served mkdocs site at `/docs/#{path}`. **Bug on line 149:** always generates `/docs/#{path}` regardless of locale. English pages should be at `/docs/en/#{path}/`.

The correct locale URL pattern is already implemented correctly in `app/views/static/docs_page.html.erb` lines 18-22:
```ruby
mkdocs_url = if params[:locale] == 'en'
  is_index_file ? "/docs/en/#{mkdocs_path}" : "/docs/en/#{mkdocs_path}/"
else
  is_index_file ? "/docs/#{mkdocs_path}" : "/docs/#{mkdocs_path}/"
end
```

### Required fix for `mkdocs_link` (one line change)

Current (broken for EN):
```ruby
url = "/docs/#{path}"
```

Fixed:
```ruby
url = locale == 'en' ? "/docs/en/#{path}/" : "/docs/#{path}/"
```

The full corrected method:
```ruby
def mkdocs_link(path, locale: nil, text: nil, **options)
  locale ||= I18n.locale.to_s
  text ||= path.split('/').last.humanize
  url = locale == 'en' ? "/docs/en/#{path}/" : "/docs/#{path}/"
  link_to text, url, target: '_blank', rel: 'noopener', **options
end
```

### Pattern for adding links to wizard steps

The `_wizard_step.html.erb` partial already has a `help:` parameter that renders `help.html_safe` inside a `<details>` element. Add deep links directly in the `help:` string using the fixed `mkdocs_link`:

```erb
help: "Sortiert die Spieler automatisch nach ihrer Rangliste. " \
      "#{mkdocs_link('managers/tournament-management', text: 'Hilfe in der Dokumentation', locale: I18n.locale.to_s)}"
```

No new partial, no new controller, no new Stimulus controller required.

### Anchor targeting for section deep links

mkdocs-material auto-generates heading anchors from heading text. `toc.permalink: true` is already enabled in mkdocs.yml. Use `#section-slug` suffixes:

- DE: `/docs/managers/tournament-management/#nach-rangliste-sortieren`
- EN: `/docs/en/managers/tournament-management/#sorting-the-seeding-list`

**Important:** anchor slugs will change when the doc rewrite renames headings. Verify anchors after the rewrite by viewing source in the built site, not by guessing from heading text.

---

## Wizard UX — No New Dependencies Needed

### Current wizard state (verified by reading `_wizard_steps_v2.html.erb` and `_wizard_step.html.erb`)

The wizard already implements:
- Progress bar with percentage via `wizard_progress_percent` helper
- Step counter text ("Schritt X von 6")
- Status icons per step (`:completed` checkmark, `:active` active, `:pending` locked)
- Danger/irreversible step indicator
- Contextual help via native `<details>`/`<summary>` (no JS required)
- Inline troubleshooting sections with `<details>`
- Terminology explanation box at bottom of `_wizard_steps_v2.html.erb`
- Disabled state text ("Erst verfügbar nach vorherigem Schritt")

The wizard UX friction for volunteers is not a missing component — it is content friction (unclear step labels when the wizard renders for a returning user who forgot the terminology, absence of doc links, no printed fallback). These are doc and content problems, not component problems.

### Wizard implementation notes for v7.0 changes

- There are **two wizard partial versions**: `_wizard_steps.html.erb` (original) and `_wizard_steps_v2.html.erb` (current, with revised step order). The `show.html.erb` view determines which is rendered. Confirm which is active before editing.
- Steps are German-only in the partials (hardcoded strings). If the wizard needs to render in EN for non-German users, the `title:` parameters in `_wizard_steps_v2.html.erb` need `I18n.t` calls. The original `_wizard_steps.html.erb` already uses `I18n.t` with fallbacks for most steps.
- The `help:` parameter in `_wizard_step.html.erb` renders `help.html_safe`. Any `mkdocs_link` calls in `help:` strings will produce correct HTML links.

---

## What NOT to Add

| Avoid | Why | Volunteer Persona Impact |
|-------|-----|--------------------------|
| `mkdocs-print-site-plugin` | Creates a `/print_page/` nav entry visible to all users. Requires suppression config. Merges the entire site, not just the reference card. For a single page, custom print CSS is 10x simpler. | No impact on volunteer; adds build complexity for developer |
| `mkdocs-pdf-export-plugin` | Requires `weasyprint` system dependency; complex install; produces full-site PDF by default | No benefit; print-to-PDF from browser on a print-CSS page achieves the same result |
| Intro.js / Shepherd.js JS tour | Volunteer uses app 2-3x/year; they forget guided tours between uses; adds 40-80 KB JS; requires maintenance when UI changes | Negative: tour is stale within one release cycle |
| ViewComponent gem | Wizard partials work fine; adding ViewComponent requires component tests, contradicts targeted-fixes scope, adds architecture layer | No volunteer benefit |
| Turbo Frames per wizard step | Wizard state transitions require server-side AASM events and page reload. Adding Turbo Frames would require client-side state that duplicates AASM. | No volunteer benefit; adds hidden failure modes |
| New breadcrumb gem | Rails `content_for` + manual breadcrumb in layout already works | No volunteer benefit |
| Step-by-step JS tooltip library (Tippy.js etc.) | Native `<details>` already provides contextual help without JS. Prints correctly. Zero maintenance. | Simpler is better for low-frequency users |
| New i18n helper for doc URLs | `mkdocs_link` and `docs_page_link` already exist; adding a third helper creates confusion about which to use | No benefit; fix the existing helper instead |

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| Custom `print.css` in `extra_css` | `mkdocs-print-site-plugin` | Plugin creates a `/print_page/` route visible to all users; adds full-site merge build step; not scoped to a single reference card page |
| Fix existing `mkdocs_link` locale bug | Build a new locale-aware URL helper | A one-line fix is preferable to a new helper that creates two competing APIs |
| `docs_page_link` for in-app embedded doc views | External mkdocs link only | Some wizard help contexts benefit from inline rendering without leaving the wizard flow; the existing proxy already handles this |
| Native `<details>` for contextual help | Stimulus disclosure controller | `<details>` renders without JS, prints correctly, needs zero JS, is already the established pattern in both wizard partials |
| `I18n.t` with fallback strings for wizard step titles | Separate DE/EN wizard templates | Single template with `I18n.t` is maintainable; two templates would diverge |

---

## Version Compatibility

| Package | Installed | Pinned in requirements.txt | Notes |
|---------|-----------|---------------------------|-------|
| mkdocs | 1.6.1 | not pinned | Compatible with material 9.6.15 |
| mkdocs-material | 9.6.15 | >=9.5.0 | Stable 9.x series; print CSS selectors unchanged across 9.x |
| mkdocs-static-i18n | 1.3.0 | >=1.0.0 | Suffix-based locale structure; confirmed working with 9.6.15 |
| pymdown-extensions | 10.16 | >=10.0.0 | All extensions in mkdocs.yml active without errors |
| mkdocs-print-site-plugin | not installed | not pinned | Only add if offline single-file PDF is a hard requirement; version ~2.3.x compatible with mkdocs 1.6 |

---

## Installation

Nothing new to install. Changes are file additions and one code fix:

```bash
# 1. Create print stylesheet
touch docs/stylesheets/print.css
# (write @media print rules as shown above)

# 2. Register in mkdocs.yml extra_css — add one line:
#    - stylesheets/print.css

# 3. Fix mkdocs_link helper — one line change in:
#    app/helpers/application_helper.rb line 149
```

---

## Sources

- `requirements.txt` — confirmed pip packages and version constraints (HIGH)
- `mkdocs.yml` — confirmed installed plugins 9.6.15, static-i18n 1.3.0, enabled extensions, extra_css list (HIGH)
- `docs/stylesheets/extra.css` — confirmed no print rules exist; safe to add separate print.css (HIGH)
- `app/helpers/application_helper.rb:135-151` — confirmed both helpers exist; confirmed `mkdocs_link` locale bug on line 149 (HIGH)
- `app/views/static/docs_page.html.erb:18-22` — confirmed correct locale URL pattern already in production use (HIGH)
- `app/views/tournaments/_wizard_steps_v2.html.erb` — confirmed wizard features already implemented; confirmed hardcoded German strings (HIGH)
- `app/views/tournaments/_wizard_step.html.erb` — confirmed `help:` parameter renders `.html_safe` inside `<details>` (HIGH)
- mkdocs-material 9.x print CSS selector names — training knowledge (Aug 2025 cutoff); web access blocked during research; MEDIUM confidence on exact selector names; verify with DevTools if any selector does not match

---

*Stack research for: v7.0 Manager Experience — Carambus Rails 7.2 app*
*Researched: 2026-04-13*
