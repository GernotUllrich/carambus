---
phase: 38-ux-polish-i18n-debt
verified: 2026-04-15T22:00:00Z
status: human_needed
score: 9/10 must-haves verified
overrides_applied: 0
re_verification: false
deferred:
  - truth: "DATA-01 — Discipline#parameter_ranges is DTP-backed and no longer false-fires on legitimate tournaments"
    addressed_in: "Phase 39"
    evidence: "ROADMAP.md Phase 39 goal + DATA-01 explicitly moved in CONTEXT.md D-19 and REQUIREMENTS.md traceability table (Pending)"
human_verification:
  - test: "Open wizard Schritt 1 in dark mode on carambus_bcw; find the 'Es sind bereits N Spieler vorhanden' info banner and confirm green translucent background + readable light-green text"
    expected: "Banner renders with dark:bg-green-900/30 background and dark:text-green-100 text; text is visually readable against the dark background without squinting"
    why_human: "CSS dark-mode rendering requires a live browser; the Tailwind build is gitignored and cannot be verified from source alone. The UAT artifact documents a second-pass textual approval, but it explicitly notes 'No second-pass screenshot was saved.' A screenshot for the pass state is absent from the evidence record."
  - test: "Hover over any of the 16 tooltipped labels on tournament_monitor.html.erb; confirm dashed underline + cursor:help affordance is visible"
    expected: "Each label shows a 1px dashed underline and the cursor changes to a help pointer on hover"
    why_human: "CSS hover states cannot be verified from source. The UAT artifact covers this under 'everything else approved' second-pass confirmation with no dedicated screenshot."
---

# Phase 38: UX Polish & i18n Debt — Verification Report

**Phase Goal:** Volunteer-facing wizard and tournament_monitor screens are polished — readable in dark mode, tooltips have visible affordance, EN locale is correct, and hardcoded German strings on tournament views are localized. Phase 36B Test 1 header criteria are explicitly reconfirmed.
**Verified:** 2026-04-15T22:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | Wizard info banner readable in dark mode (UX-POL-01) | VERIFIED (code) / human needed for screenshot | `_wizard_steps_v2.html.erb:171` has `bg-green-50 dark:bg-green-900/30 border border-green-600 dark:border-green-500 text-green-900 dark:text-green-100`; `step-info` class dropped from that div; UAT second-pass is textual approval only (no screenshot) |
| 2 | All 16 tooltip labels show dashed underline + cursor:help (UX-POL-02) | VERIFIED (code) | `components/tooltip.css` exists with `[data-controller~="tooltip"] { cursor: help; border-bottom: 1px dashed currentColor; }` imported in `application.tailwind.css:33`; 16 `data-controller="tooltip"` sites confirmed in `tournament_monitor.html.erb` |
| 3 | EN warmup keys say "Warm-up / Warm-up Player A / Warm-up Player B" (I18N-01) | ✓ VERIFIED | `config/locales/en.yml:844-846` — `warmup: Warm-up`, `warmup_a: Warm-up Player A`, `warmup_b: Warm-up Player B`; confirmed by direct file read |
| 4 | `en.yml:387 training: Training` untouched | ✓ VERIFIED | `grep -n "training: Training" config/locales/en.yml` returns line 387 unchanged |
| 5 | Zero hardcoded German user-visible strings remain in tournaments/ (I18N-02) | ✓ VERIFIED | Starter grep `Aktuelle\|Turnier\|Starte\|zurück` on `app/views/tournaments/` (excluding `_wizard_steps_v2.html.erb`) returns only HTML comments and ERB comment lines — no user-visible literals outside `t(...)` calls; 26 `t('...')` / `t("...")` calls confirmed in `tournament_monitor.html.erb` |
| 6 | DE/EN locale parity — every new key present in both de.yml and en.yml | ✓ VERIFIED | `monitor:` namespace count is 13/13 in both locale files; `bracket_bye`, `bracket_winner_of`, `bracket_loser_of` exist in both; WR-01 fix (commit `91ce0f22`) wired these keys into `_bracket.html.erb` AND updated JS to use `dataset.placeholder` instead of German string comparison |
| 7 | Phase 36B Test 1 criteria reconfirmed (UX-POL-03) | ✓ VERIFIED | `38-UX-POL-03-UAT.md` exists with `result: pass`; all 4 required criteria (AASM badge, 6 chips, no "Schritt N von 6", no numeric prefix) individually documented as pass |
| 8 | DATA-01 NOT in Phase 38 scope | ✓ VERIFIED | `discipline.rb` still has `DISCIPLINE_PARAMETER_RANGES` hardcoded constant (untouched); no Phase 38 commit touches `discipline.rb`; CONTEXT.md D-19 and ROADMAP.md Phase 39 confirm the deferral |
| 9 | WR-01 code review finding fixed post-review | ✓ VERIFIED | Commit `91ce0f22` exists ("fix(38): wire bracket placeholder i18n keys + data-attr filter"); `_bracket.html.erb:164,168,171` now uses `t('tournaments.monitor.bracket_bye')` etc.; JS at line 90 now filters on `playerDiv.dataset.placeholder === "true"` instead of German string literals |
| 10 | _wizard_steps_v2.html.erb excluded from I18N-02 sweep (D-11) | ✓ VERIFIED | Plan 38-02 SUMMARY confirms `git diff --stat` returned empty for that file; content check shows no new `t(...)` calls were added by Plan 38-02 |

**Score:** 9/10 truths fully verified programmatically (Truth 1 code-verified but awaits screenshot confirmation of the pass state; Truth 2 code-verified but hover behavior is human-only)

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|-------------|---------|
| 1 | DATA-01 — DTP-backed Discipline#parameter_ranges | Phase 39 | ROADMAP.md Phase 39 goal explicitly covers DATA-01; REQUIREMENTS.md traceability table: "DATA-01 | Phase 39 | Pending" |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `app/assets/stylesheets/components/tooltip.css` | New file; `cursor: help; border-bottom: 1px dashed currentColor` | ✓ VERIFIED | File exists; contains exact selector `[data-controller~="tooltip"]` with both affordance rules; 23-line file with audit comment documenting all 16 safe sites |
| `app/assets/stylesheets/application.tailwind.css` | `@import "components/tooltip.css"` at line ~33 | ✓ VERIFIED | `grep "@import.*tooltip"` returns `33: @import "components/tooltip.css";` |
| `app/views/tournaments/_wizard_steps_v2.html.erb` | `bg-green-50 dark:bg-green-900/30` on info banner; no `step-info` on that div | ✓ VERIFIED | Line 171 has the full D-03 Tailwind class set; line 170 is the G-01 revision comment; `step-info` class not present on line 171 div |
| `config/locales/en.yml` | `warmup: Warm-up`, `warmup_a: Warm-up Player A`, `warmup_b: Warm-up Player B` at 844-846 | ✓ VERIFIED | Direct file read confirms all three values verbatim |
| `.planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md` | `result: pass`; 4 required criteria + bonus G-01 documented | ✓ VERIFIED | Frontmatter `result: pass`; all 4 required criteria pass; G-01 bonus documented as fail → revision → pass |
| `config/locales/de.yml` (tournaments.monitor.* additions) | New monitor/show/action namespaces | ✓ VERIFIED | `monitor:` appears 13 times; `bracket_bye`, `bracket_winner_of`, `bracket_loser_of` present |
| `config/locales/en.yml` (tournaments.monitor.* additions) | Parallel EN keys for all DE additions | ✓ VERIFIED | `monitor:` appears 13 times; bracket keys present with EN values ("Bye", "Winner of %{src}", "Loser of %{src}") |
| `.planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md` | Pre-edit audit enumeration artifact | ✓ VERIFIED | File exists at confirmed path |
| `app/views/tournaments/_bracket.html.erb` (WR-01 fix) | `t('tournaments.monitor.bracket_bye')` etc.; JS uses `dataset.placeholder` | ✓ VERIFIED | Lines 164/168/171 use `t(...)` calls; line 90 JS filters on `playerDiv.dataset.placeholder === "true"`; lines 229/233 add `data-placeholder="true"` when `p_val == -1` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `_wizard_steps_v2.html.erb` | Tailwind dark: variant system | `dark:bg-green-900/30 dark:border-green-500 dark:text-green-100` on info banner div | ✓ WIRED | Class set confirmed on line 171; `step-info` class escape prevents specificity conflict with `tournament_wizard.css:233-235` |
| `application.tailwind.css` | `components/tooltip.css` | `@import "components/tooltip.css"` at line 33 | ✓ WIRED | Confirmed by grep |
| `tournament_monitor.html.erb` | `components/tooltip.css` | `[data-controller~="tooltip"]` CSS attribute selector matching 16 `<span>` sites | ✓ WIRED | 16 tooltip sites confirmed; selector audit in `tooltip.css` comment confirms no form controls carry the attribute |
| `config/locales/en.yml` | Rails I18n warmup lookup | `table_monitor.status.warmup/warmup_a/warmup_b` under `en:` root | ✓ WIRED | Keys at lines 844-846; values verbatim per D-09 |
| `app/views/tournaments/*.html.erb` (22 files) | Rails I18n t(...) | `t('tournaments.monitor.*')` / `t('tournaments.show.*')` / `t('tournaments.<action>.*')` calls | ✓ WIRED | Starter grep returns zero unlocalized German literals outside HTML/ERB comments; 26 t() calls in tournament_monitor alone |
| `_bracket.html.erb` helper | `tournaments.monitor.bracket_*` keys | `t('tournaments.monitor.bracket_bye')` etc. on lines 164/168/171 | ✓ WIRED | WR-01 fix commit `91ce0f22` applied; JS now uses `dataset.placeholder` filter |

### Data-Flow Trace (Level 4)

Not applicable. Phase 38 is a CSS/i18n/UX-only phase — no new data models, API endpoints, or components that render dynamic data from a backend query. All changes are static translations and CSS rules.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Warmup EN translation keys resolve | `grep -n "warmup:" config/locales/en.yml` | Lines 844-846: `warmup: Warm-up` etc. | ✓ PASS |
| Tooltip CSS imported in build pipeline | `grep "@import.*tooltip" app/assets/stylesheets/application.tailwind.css` | Line 33: `@import "components/tooltip.css";` | ✓ PASS |
| Starter grep for unlocalized DE strings | `grep -rn 'Aktuelle\|Turnier\|Starte\|zurück' app/views/tournaments/ (excl. _wizard_steps_v2)` | Returns only HTML comments and ERB comment lines | ✓ PASS |
| training: Training preserved | `grep -n "training: Training" config/locales/en.yml` | Line 387 unchanged | ✓ PASS |
| discipline.rb untouched (DATA-01 deferred) | `grep -n "DISCIPLINE_PARAMETER_RANGES" app/models/discipline.rb` | Lines 53, 84 — constant still present, unmodified | ✓ PASS |
| Dark-mode info banner in browser | Requires live browser in dark mode | Not runnable from source; UAT second-pass is textual only | ? SKIP (human) |
| Tooltip hover affordance in browser | Requires live browser hover interaction | Not runnable from source; UAT is "everything else approved" | ? SKIP (human) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| UX-POL-01 | 38-01 | Wizard dark-mode readability | ✓ SATISFIED | Tailwind dark: variants on info banner; step-info class-escape; ERB interpolation bug fixed; UAT passed (textual second-pass) |
| UX-POL-02 | 38-01 | Tooltip affordance visible | ✓ SATISFIED | `components/tooltip.css` with `[data-controller~="tooltip"]` selector; @import wired; 16 sites confirmed |
| UX-POL-03 | 38-01 | Phase 36B Test 1 reconfirmed | ✓ SATISFIED | `38-UX-POL-03-UAT.md` with `result: pass`; all 4 required criteria individually documented |
| I18N-01 | 38-01 | EN warmup translations correct | ✓ SATISFIED | `en.yml:844-846` verbatim per D-09; `training: Training` at 387 untouched |
| I18N-02 | 38-02 | Hardcoded DE strings localized on tournament views | ✓ SATISFIED | Starter grep clean; 22 ERB files audited; ~180 keys added; DE/EN parity confirmed; WR-01 fix also applies bracket keys |
| DATA-01 | Phase 39 (deferred) | DTP-backed parameter_ranges | Pending (not Phase 38 scope) | CONTEXT.md D-19; ROADMAP.md Phase 39; `discipline.rb` intentionally untouched |

**Note:** The REQUIREMENTS.md body checkboxes for UX-POL-01, UX-POL-02, UX-POL-03, and I18N-01 still show `[ ]` (unchecked) while the traceability table correctly shows "Complete." The ROADMAP.md plan-level entries for `38-01` and `38-02` also show `[ ]`. These are stale documentation cosmetics — not a code gap. The code changes are present and confirmed. This is a trivial documentation update (checking 6 boxes) that can be done at any time.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `_wizard_steps_v2.html.erb` | 51, 55, 60, 158, 162 | `class="step-info"` still present on non-green informational divs | ℹ️ Info | These divs get `html.dark .step-info { color: #d1d5db }` (light gray) in dark mode — the same rule that caused G-01. They are informational text divs (not green info banners), so `#d1d5db` gray on dark background may be acceptable. But the specificity risk pattern is still latent for any future Tailwind dark: additions to these divs. Pre-existing; out of Phase 38 scope. |
| `_wizard_steps_v2.html.erb` | ~275 | `help: "...#{link_to ...}"` with `.html_safe` in partial | ⚠️ Warning | Code review WR-02 finding — fragile trust boundary for future callers. Pre-existing pattern; not introduced by Phase 38. No current XSS risk (all strings are developer-authored). |
| `_tournament_status.html.erb` | 16 | `tournament_monitor.state.gsub("_", " ").humanize` bypasses i18n | ℹ️ Info | Code review IN-05 finding. Pre-existing. Produces always-English humanized state names regardless of locale. Out of Phase 38 scope. |
| `index.html.erb` | 22 | `t('tournament.index.tournaments')` (singular namespace) | ℹ️ Info | Code review IN-06 finding. Pre-existing stale key. Not introduced by Phase 38. |
| `compare_seedings.html.erb` | ~171, 273, 302, 318, 349 | German strings inside `<script>` block (console.error, alert) | ℹ️ Info | Code review IN-04 + Plan 38-02 Deviation 2. Pre-existing; JS strings require data-* attribute refactor beyond Phase 38 ERB/YAML scope. |
| `REQUIREMENTS.md` | 20, 24, 28, 34 | Requirement checkboxes still `[ ]` for UX-POL-01..03, I18N-01 | ℹ️ Info | Documentation cosmetic only; traceability table correctly shows "Complete"; trivial fix |
| `ROADMAP.md` | 65, 66 | Plan entries `38-01` and `38-02` still `[ ]` | ℹ️ Info | Documentation cosmetic only; Phase 38 entry at line 46 correctly shows `[x]`; trivial fix |

### Human Verification Required

#### 1. Dark-mode info banner visual confirmation (UX-POL-01)

**Test:** On `carambus_bcw` with dark mode enabled, navigate to a tournament in `new_tournament` or `accreditation_finished` state with at least one existing player (so the info banner appears). Find the "Es sind bereits N Spieler vorhanden" banner in Schritt 1.

**Expected:** Banner renders with a dark green translucent background, a visible dark-green border, and readable light-green text. The text "Es sind bereits N Spieler vorhanden" is clearly legible — not light-gray-on-light-green as in the first-pass UAT failure.

**Why human:** The Tailwind build artifact (`app/assets/builds/application.css`) is gitignored. The dark: variants must be compiled into the built CSS for them to take effect in the browser. The UAT artifact documents that a Tailwind rebuild (`yarn build:css`) was required after the revision commit `e727b4a3`, and that the second-pass approval was "textual only — no screenshot captured." The code is correct but the visual pass state is only documented as a textual statement, not a screenshot.

#### 2. Tooltip hover affordance visual confirmation (UX-POL-02)

**Test:** On `carambus_bcw`, navigate to `tournament_monitor.html.erb` for any running tournament. Hover over one of the 16 parameter-label `<span>` elements (e.g., the "Punkte" or "Innings" label).

**Expected:** The label shows a 1px dashed underline on hover and the cursor changes to a help pointer (`cursor: help`), matching the `[data-controller~="tooltip"]` rule in `components/tooltip.css`.

**Why human:** CSS hover states cannot be verified from source. The UAT artifact covers this under the second-pass "everything else approved" confirmation, with no dedicated hover screenshot. The CSS rule itself is verified correct in the source, but runtime rendering (especially in the context of Tailwind's CSS reset or any specificity overrides) requires a live browser check.

### Gaps Summary

No code gaps. All Phase 38 success criteria are implemented in the codebase. The two human verification items are visual confirmation requests for behavior that was tested (textual second-pass UAT) but not photographically documented. The phase can be considered complete for code purposes; the human checks are confirmatory, not investigative.

**Documentation cosmetics to update after verification:**
- `REQUIREMENTS.md` lines 20, 24, 28, 34: change `[ ]` to `[x]` for UX-POL-01, UX-POL-02, UX-POL-03, I18N-01
- `ROADMAP.md` lines 65, 66: change `[ ]` to `[x]` for plan entries 38-01 and 38-02

---

_Verified: 2026-04-15T22:00:00Z_
_Verifier: Claude (gsd-verifier)_
