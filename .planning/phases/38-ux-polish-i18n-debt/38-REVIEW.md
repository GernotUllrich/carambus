---
phase: 38-ux-polish-i18n-debt
reviewed: 2026-04-15T00:00:00Z
depth: standard
files_reviewed: 25
files_reviewed_list:
  - app/assets/stylesheets/application.tailwind.css
  - app/assets/stylesheets/components/tooltip.css
  - app/assets/stylesheets/tournament_wizard.css
  - app/views/tournaments/_admin_tournament_info.html.erb
  - app/views/tournaments/_bracket.html.erb
  - app/views/tournaments/_form.html.erb
  - app/views/tournaments/_groups.html.erb
  - app/views/tournaments/_groups_compact.html.erb
  - app/views/tournaments/_show.html.erb
  - app/views/tournaments/_tournament_status.html.erb
  - app/views/tournaments/_wizard_step.html.erb
  - app/views/tournaments/_wizard_steps_v2.html.erb
  - app/views/tournaments/compare_seedings.html.erb
  - app/views/tournaments/define_participants.html.erb
  - app/views/tournaments/edit.html.erb
  - app/views/tournaments/finalize_modus.html.erb
  - app/views/tournaments/index.html.erb
  - app/views/tournaments/new.html.erb
  - app/views/tournaments/new_team.html.erb
  - app/views/tournaments/parse_invitation.html.erb
  - app/views/tournaments/show.html.erb
  - app/views/tournaments/tournament_monitor.html.erb
  - config/locales/de.yml
  - config/locales/en.yml
findings:
  critical: 0
  warning: 2
  info: 6
  total: 8
status: issues_found
---

# Phase 38: Code Review Report

**Reviewed:** 2026-04-15
**Depth:** standard
**Files Reviewed:** 25
**Status:** issues_found

## Summary

Phase 38 (UX-POL-01..03 + I18N-01 + I18N-02) is a focused polish/i18n phase.
Findings:

- **Locked-file protection honored.** `home.index.training` (`en.yml:387`) is
  unchanged at "Training". The `tournaments.parameter_*` subtree from Phase 36B
  is untouched. No models, controllers, services, or tests were modified.
- **i18n key parity is clean.** All 226 new DE keys have paired EN keys. The 5
  EN-only diff lines (`warmup*`, `proposed_*`) are value corrections for keys
  that already existed in `de.yml` (I18N-01 EN warmup fix + reused DE keys for
  bracket/finalize translations). Verified via key-name diff.
- **XSS surface is safe.** All 19 `.html_safe` call sites on new i18n keys use
  static, developer-authored translations. Three sites pass interpolated model
  attributes (`discipline.name`, `tournament_plan.name`), but they use the
  `_html` key convention so Rails i18n's auto-escape of `%{var}` still applies
  before the redundant `.html_safe`. No user-controlled data is interpolated
  into `t()` calls.
- **Tooltip CSS scope is verified safe.** `grep` confirms `data-controller="tooltip"`
  is used only on the 16 `<span>` labels in `tournament_monitor.html.erb`. The
  new `[data-controller~="tooltip"]` selector in `components/tooltip.css` does
  not bleed into form controls, buttons, or any other views.
- **No remaining `#{...}` misuse in ERB body.** All Ruby interpolations live
  inside Ruby string literals (button labels, data-attribute values, partial
  locals) — none in ERB plain-text context.

Two **warning-level** findings relate to inconsistencies introduced by the
phase: the DKO bracket display still hardcodes German labels despite new
`bracket_*` keys being added, and the `_wizard_step` partial uses `.html_safe`
on a locals-sourced `help` string with embedded `link_to` output (trusted but
fragile pattern).

Six **info-level** findings cover pre-existing debt not touched by this phase
(out-of-scope hardcoded strings in wizard-v2, JS text in compare_seedings,
bracket rescue comment leakage, `humanize` state display, and a suspicious
`tournament.index.tournaments` key path in `index.html.erb:22`).

---

## Warnings

### WR-01: Bracket display hardcodes German while paired i18n keys were added (orphaned keys + JS coupling risk)

**File:** `app/views/tournaments/_bracket.html.erb:164,168,171` (and JS at lines 90, 164-171)
**Issue:**

Phase 38 added three new i18n keys to both `de.yml:1068-1073` and
`en.yml:1048-1053`:

```
tournaments.monitor.bracket_bye      ("Freilos / Bye" / "Bye")
tournaments.monitor.bracket_winner_of ("Sieger %{src}" / "Winner of %{src}")
tournaments.monitor.bracket_loser_of  ("Verlierer %{src}" / "Loser of %{src}")
```

But the `display_player` helper in `_bracket.html.erb` still emits hardcoded
German:

```ruby
return ["Freilos / Bye", "-", -1]        # line 164
return ["Sieger #{src}", "-", -1]        # line 168
return ["Verlierer #{src}", "-", -1]     # line 171
```

This is either (a) dead i18n keys (should have been applied to this helper), or
(b) a latent bug waiting for the application step. Either way it's a consistency
hole in I18N-02.

**Compounding JS risk:** if the translations *are* applied, the inline JS click
handler at line 90 will silently break for EN locale users because it filters
on the German display text directly:

```javascript
if(!nameTxt || nameTxt === "TBD" || nameTxt === "-" || nameTxt === "Freilos / Bye"
    || nameTxt.startsWith("Sieger") || nameTxt.startsWith("Verlierer")) {
  return;
}
```

Once `nameTxt` becomes "Bye" / "Winner of ..." / "Loser of ...", the highlight
click would erroneously try to cross-highlight placeholder/bye slots as if they
were real players.

**Fix:**

Apply the keys AND make the JS filter locale-independent. Prefer data
attributes:

```erb
<% # Mark placeholders with a data attribute instead of matching on text %>
<div class="bracket-player bracket-player-top <%= 'winner' if p1_winner %>"
     data-placeholder="<%= p1_val == -1 && !p1_name_is_real ? 'true' : 'false' %>">
  <span class="truncate pr-2 bracket-player-name" title="<%= p1_name %>"><%= p1_name %></span>
  ...
</div>
```

And in the helper:

```ruby
if rule.start_with?("sl.")
  pos = rule.split('.').last.gsub('rk', '').to_i
  seeding = tournament.seedings.where("id >= 50000000").find_by(position: pos)
  if seeding&.player
    return [seeding.player.fullname, "-", -1]
  else
    return [t('tournaments.monitor.bracket_bye'), "-", -1]
  end
elsif rule.include?(".rk1")
  src = rule.split('.').first
  return [t('tournaments.monitor.bracket_winner_of', src: src), "-", -1]
elsif rule.include?(".rk2")
  src = rule.split('.').first
  return [t('tournaments.monitor.bracket_loser_of', src: src), "-", -1]
end
```

Then in JS, gate on `playerDiv.dataset.placeholder === 'true'` instead of
string-matching on localized text.

---

### WR-02: `_wizard_step.html.erb:54` applies `.html_safe` to locals-sourced `help` with embedded `link_to` (trust boundary)

**File:** `app/views/tournaments/_wizard_step.html.erb:54`
**Issue:**

```erb
<p><%= help.html_safe %></p>
```

The `help` local is passed from `_wizard_steps_v2.html.erb:275`:

```erb
help: "...<strong>Für Tests:</strong> #{link_to '📝 Direkt zur Teilnehmerliste (für manuelle Eingabe)',
       define_participants_tournament_path(tournament), class: 'text-blue-600 ...'}"
```

Today this is safe — the surrounding text is a developer-authored literal and
`link_to` returns an `ActiveSupport::SafeBuffer`. But the pattern is fragile:

1. `"#{link_to ...}"` string-interpolates a `SafeBuffer` *into a plain String*,
   which returns a plain (unsafe) String — the `SafeBuffer` safety marker is
   lost. The partial then compensates with `.html_safe` on the whole thing,
   which blindly whitelists the string.
2. If any future caller passes a help string containing user-controlled data
   (e.g. a sanitized user description), this `.html_safe` call would trust the
   entire string without re-escaping.
3. There is no type check in the partial guarding against this.

**Fix:**

Either (a) lock the contract on the caller side by building the help content as
a `SafeBuffer` from the start, or (b) migrate the partial to render help from
an i18n key with the `_html` suffix so Rails handles safety:

```erb
<% # Option A: partial consumes an already-safe buffer %>
<p><%= help %></p>

<%# caller builds help as a SafeBuffer via content_tag or a helper: %>
help: safe_join([
  "Passen Sie die Teilnehmerliste direkt am Turniertag an:".html_safe,
  tag.br,
  "• ✏️ Änderungen werden sofort gespeichert".html_safe,
  tag.br,
  link_to("📝 Direkt zur Teilnehmerliste", define_participants_tournament_path(tournament),
          class: "text-blue-600 dark:text-blue-400 underline")
])
```

Or (preferred, aligns with the rest of Phase 38's i18n direction):

```erb
<% # Option B: move help to i18n and use _html keys %>
help: t('tournaments.wizard_step_v2.step3_help_html',
        participants_link: link_to(t('tournaments.wizard_step_v2.direct_to_participants'),
                                   define_participants_tournament_path(tournament),
                                   class: 'text-blue-600 dark:text-blue-400 underline'))
```

Then the partial can drop `.html_safe` entirely. This also hooks the wizard
help strings into the I18N-02 sweep (the whole `_wizard_steps_v2.html.erb` is
currently out of scope, see IN-01).

---

## Info

### IN-01: `_wizard_steps_v2.html.erb` still contains ~30+ hardcoded German strings (out of phase scope, but tracked)

**File:** `app/views/tournaments/_wizard_steps_v2.html.erb:9-401`
**Issue:**
Per `<phase_context>` this file was intentionally excluded from the I18N-02
sweep. The review confirms extensive untranslated literals remain:

- Line 9: `Turnier-Setup: <%= tournament.title %>`
- Lines 41, 43, 47: `"Meldeliste von ClubCloud laden"`, `"Geladen"`, `"Empfohlen"`, `"Optional"`
- Lines 52, 62: `"Lädt die Meldeliste..."`, `"📅 Meldeschluss:"`
- Lines 67-76: `<details>` block explaining Meldeliste vs Setzliste vs Teilnehmerliste
- Lines 86, 92, 101: button labels `"Jetzt synchronisieren"`, `"📊 Ergebnisse von ClubCloud laden"`, `"🔗 ClubCloud öffnen"`
- Lines 96, 121, 134: `data: { confirm: ... }` payloads with German text
- Lines 112, 116, 117, 124, 129, 130, 137: troubleshooting block text
- Lines 154, 162-164: Schritt 2 heading + info strings
- Lines 172-180, 186-197, 215, 224-250: Schritt 2 content + buttons
- Lines 259-295 (help: and text: kwargs for renders of `_wizard_step`)
- Lines 326, 328, 335, 345-350, 364, 370, 375, 380, 389-399: Schritt 6 +
  glossary box + buttons

**Fix:** No action required for Phase 38 (explicitly out of scope). Track in
a follow-up phase or as an I18N-02 continuation. Total effort estimate: roughly
another 50-70 new DE/EN key pairs across a new `tournaments.wizard.*`
namespace.

---

### IN-02: Pre-existing silent rescue leaks exception message into HTML comment in `_bracket.html.erb:245`

**File:** `app/views/tournaments/_bracket.html.erb:244-246`
**Issue:**
```erb
<% rescue StandardError => e %>
  <!-- Bracket ERROR: <%= e.message %> -->
<% end %>
```

Rails ERB auto-escaping operates on HTML *text content*, not HTML *comment*
content. An exception message containing the character sequence `-->` would
terminate the comment early and allow subsequent output to render as HTML.
The source of `e` is internal (`JSON.parse`, hash lookups), so today this is
not user-reachable — but the pattern is pre-existing technical debt.

**Fix:** Not Phase 38's problem. If touched later, either drop the comment
entirely (errors should go to `Rails.logger` / `DEBUG_LOGGER`) or sanitize:

```erb
<% rescue StandardError => e %>
  <% Rails.logger.warn("[bracket partial] #{e.class}: #{e.message}") %>
<% end %>
```

---

### IN-03: Hardcoded English option labels in `tournament_monitor.html.erb:136`

**File:** `app/views/tournaments/tournament_monitor.html.erb:136`
**Issue:**
```erb
<%= select_tag :fixed_display_left, options_for_select(
  [["Kick-Off Left", ""], ["Player A", "playera"], ["Player B", "playerb"]]) %>
```

"Kick-Off Left", "Player A", "Player B" are English and not routed through
i18n. This is outside the tooltip pattern that Phase 36B / 38 audited, and
pre-existing.

**Fix:** Out of scope for Phase 38. When addressed, add keys under
`tournaments.monitor_form.options.fixed_display_left.*` for consistency with
the existing monitor_form namespace.

---

### IN-04: Hardcoded German strings inside JavaScript in `compare_seedings.html.erb`

**File:** `app/views/tournaments/compare_seedings.html.erb:171,273,302,318,349`
**Issue:** Lines contain `'PDF oder Screenshot (PNG, JPG)'`, `'DataTransfer nicht verfügbar'`,
`'Keine Datei erkannt. Bitte ziehen Sie eine Datei direkt...'`, `'Bitte nur PDF, PNG oder JPEG Dateien hochladen!'`,
`'Fehler beim Verarbeiten der Datei. Bitte nutzen Sie die Dateiauswahl.'`.

These live inside `<script>` blocks. Phase 38's I18N-02 sweep covered ERB text
but JS literals are a separate concern. Drops and error alerts will always
display German regardless of user locale.

**Fix:** Out of scope for Phase 38. When addressed, either:
1. Render the strings from `data-*` attributes on a DOM element via
   `t('...')` in ERB, then read them in JS, or
2. Move the inline script to a Stimulus controller and use a translated
   `data-i18n-*-value` pattern consistent with the rest of the codebase.

---

### IN-05: `tournament.state.gsub("_", " ").humanize` bypasses i18n in `_tournament_status.html.erb:16`

**File:** `app/views/tournaments/_tournament_status.html.erb:16`
**Issue:**
```erb
<%= tournament_monitor.state.gsub("_", " ").humanize %>
```

The AASM state names (`playing_groups`, `finals_finished`, `results_published`,
etc.) are displayed directly to users via Ruby's `humanize`, producing
"Playing groups", "Finals finished", etc. Always English regardless of
`I18n.locale`. Pre-existing, not touched by Phase 38.

**Fix:** Out of scope. When addressed, define a mapping:

```yaml
# de.yml
tournament_monitor:
  state:
    new_tournament: Neu
    accreditation_finished: Akkreditierung abgeschlossen
    playing_groups: Gruppen werden gespielt
    playing_finals: Finalrunden werden gespielt
    finals_finished: Finalrunden beendet
    results_published: Ergebnisse veröffentlicht
```

And in the view:

```erb
<%= t("tournament_monitor.state.#{tournament_monitor.state}",
      default: tournament_monitor.state.humanize) %>
```

---

### IN-06: Suspicious translation key `tournament.index.tournaments` (singular "tournament") in `index.html.erb:22`

**File:** `app/views/tournaments/index.html.erb:22`
**Issue:**
```erb
title: t('tournament.index.tournaments'),
```

The key uses the **singular** namespace `tournament.index` while every other
call in this file uses `tournaments.index.*` (plural). The lookup currently
resolves to an actual key at `en.yml:873-875` / `de.yml` but sits under the
`tournament:` (singular) ActiveRecord attribute block, which is a namespace
reserved for `t('activerecord.attributes.tournament.*')`-style model labels.
This is pre-existing — Phase 38 did not touch this line — but it's a code
smell worth a follow-up.

**Fix:** Out of scope. When addressed, move the label under the action
namespace:

```yaml
# de.yml / en.yml
tournaments:
  index:
    page_title: Turniere / Tournaments
```

```erb
title: t('tournaments.index.page_title'),
```

And remove the odd `tournament.index.{tournament,tournaments}` block from the
activerecord.attributes area.

---

_Reviewed: 2026-04-15_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
