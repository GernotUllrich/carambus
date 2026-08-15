---
phase: 38-ux-polish-i18n-debt
plan: 02
type: execute
wave: 2
depends_on: ["01"]
files_modified:
  - app/views/tournaments/_admin_tournament_info.html.erb
  - app/views/tournaments/_balls_goal.html.erb
  - app/views/tournaments/_bracket.html.erb
  - app/views/tournaments/_form.html.erb
  - app/views/tournaments/_groups.html.erb
  - app/views/tournaments/_groups_compact.html.erb
  - app/views/tournaments/_party_record.html.erb
  - app/views/tournaments/_search.html.erb
  - app/views/tournaments/_show.html.erb
  - app/views/tournaments/_tournament_status.html.erb
  - app/views/tournaments/_tournaments_table.html.erb
  - app/views/tournaments/_wizard_step.html.erb
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
  - .planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md
autonomous: true
requirements:
  - I18N-02
tags:
  - i18n
  - yaml
  - erb
  - audit
  - localization

must_haves:
  truths:
    - "Zero hardcoded German user-visible strings remain in app/views/tournaments/*.html.erb outside _wizard_steps_v2.html.erb (which is excluded per CONTEXT.md D-11)"
    - "Every hardcoded string identified in the audit is replaced with a t(...) call"
    - "Every new t(...) key exists in BOTH config/locales/de.yml (authoritative DE value) AND config/locales/en.yml (Claude-written EN translation) — no partial translations"
    - "New keys live under tournaments.monitor.* / tournaments.show.* / tournaments.<action>.* namespaces per CONTEXT.md D-12"
    - "Existing tournaments.parameter_* keys (Phase 36B) are NOT touched — that surface is already fully i18n'd per CONTEXT.md D-15"
    - "A locale smoke test under I18n.locale = :en completes without missing-key warnings on the modified tournament views"
  artifacts:
    - path: ".planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md"
      provides: "Enumerated list of every hardcoded-string finding from the grep sweep + namespace assignment + key name per finding — reviewable before ERB edits start"
      contains: "tournaments.monitor."
    - path: "config/locales/de.yml"
      provides: "New DE keys under tournaments.monitor.* / tournaments.show.* / tournaments.<action>.* (authoritative German values — relocated from ERB literals)"
      contains: "monitor:"
    - path: "config/locales/en.yml"
      provides: "New EN keys matching the DE tree — Claude-written translations of the short UI labels"
      contains: "monitor:"
  key_links:
    - from: "app/views/tournaments/*.html.erb (22 files, excluding _wizard_steps_v2.html.erb)"
      to: "Rails I18n lookup via t(...) helper"
      via: "t('tournaments.monitor.*') / t('tournaments.show.*') / t('tournaments.<action>.*') calls replacing hardcoded strings"
      pattern: "t\\('tournaments\\."
    - from: "config/locales/de.yml tournaments subtree"
      to: "config/locales/en.yml tournaments subtree"
      via: "Parallel key addition — every DE key has an EN counterpart in the same commit (CONTEXT.md D-14)"
      pattern: "monitor:|show:"
    - from: "Rails runner / controller test under I18n.locale = :en"
      to: "All modified tournament ERB templates"
      via: "Locale smoke test confirms zero missing-key warnings on tournament views"
      pattern: "I18n.locale = :en"
---

<objective>
Audit and localize all hardcoded German strings in `app/views/tournaments/*.html.erb` (22 files, excluding `_wizard_steps_v2.html.erb`) into the existing `tournaments.*` i18n tree under `config/locales/de.yml` + `config/locales/en.yml`.

Purpose: Close I18N-02 (G-04) — the pre-existing DE-only debt on tournament_monitor and surrounding tournament views. DE is the primary locale for 2×/year volunteers, but EN-coverage gaps affect admins who switch to EN. Phase 36B already i18n'd the 16 parameter form labels (under `tournaments.parameter_*`); this plan closes everything else that was out-of-scope for Phase 36B.

Output:
- A pre-edit audit artifact `.planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md` enumerating every finding with namespace assignment
- ERB edits across up to 22 files replacing hardcoded strings with `t('tournaments.*')` calls
- New keys added in parallel to `config/locales/de.yml` AND `config/locales/en.yml` under `tournaments.monitor.*`, `tournaments.show.*`, and action-specific namespaces
- A post-edit verification sweep confirming zero remaining German literals in the 22 audited files
- A locale smoke test confirming no missing-key warnings under `I18n.locale = :en` on the audited views

Parallel with Plan 38-01: same wave, zero file overlap. Plan 38-01 touches `_wizard_steps_v2.html.erb` (excluded here per CONTEXT.md D-11) and `en.yml:844-846` under `table_monitor.status.*` (different subtree from `tournaments.*`).
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/38-ux-polish-i18n-debt/38-CONTEXT.md
@.planning/seeds/v71-ux-polish-i18n-debt.md
@.planning/milestones/v7.0-phases/36B-ui-cleanup-kleine-features/36B-HUMAN-UAT.md

<!-- Audit scope: 22 ERB files (23 minus the excluded _wizard_steps_v2.html.erb) -->
@app/views/tournaments/tournament_monitor.html.erb
@app/views/tournaments/show.html.erb
@app/views/tournaments/_show.html.erb
@app/views/tournaments/_admin_tournament_info.html.erb
@app/views/tournaments/_tournament_status.html.erb
@app/views/tournaments/_groups.html.erb
@app/views/tournaments/_groups_compact.html.erb
@app/views/tournaments/_bracket.html.erb
@app/views/tournaments/_form.html.erb
@app/views/tournaments/_search.html.erb
@app/views/tournaments/_balls_goal.html.erb
@app/views/tournaments/_party_record.html.erb
@app/views/tournaments/_tournaments_table.html.erb
@app/views/tournaments/_wizard_step.html.erb
@app/views/tournaments/compare_seedings.html.erb
@app/views/tournaments/define_participants.html.erb
@app/views/tournaments/edit.html.erb
@app/views/tournaments/new.html.erb
@app/views/tournaments/new_team.html.erb
@app/views/tournaments/finalize_modus.html.erb
@app/views/tournaments/parse_invitation.html.erb
@app/views/tournaments/index.html.erb

<!-- Existing i18n trees (executor reads to understand the existing tournaments.* structure before adding keys) -->
@config/locales/de.yml
@config/locales/en.yml

<interfaces>
<!-- The existing tournaments.* key tree — executor MUST read the live files to understand what already exists before adding new keys. -->
<!-- CRITICAL: Phase 36B added the tournaments.parameter_* subtree. DO NOT touch those keys per CONTEXT.md D-15. -->

Existing tournaments.* tree starts at:
- config/locales/de.yml:1010 `tournaments:`
- config/locales/en.yml (search for `  tournaments:` at 2-space indent — the exact line number varies)

New keys to add under:
- `tournaments.monitor.*` — for tournament_monitor.html.erb + _tournament_status + _groups + _groups_compact + _bracket + _balls_goal + _party_record (the post-start monitor surface)
- `tournaments.show.*` — for show.html.erb + _show.html.erb + _admin_tournament_info (the tournament detail page)
- `tournaments.index.*` — for index.html.erb + _tournaments_table (the listing page)
- `tournaments.edit.*` — for edit.html.erb + _form (the edit form)
- `tournaments.new.*` — for new.html.erb (new tournament form — if there are literal strings here beyond Rails form scaffolding)
- `tournaments.new_team.*` — for new_team.html.erb
- `tournaments.compare_seedings.*` — for compare_seedings.html.erb
- `tournaments.define_participants.*` — for define_participants.html.erb
- `tournaments.finalize_modus.*` — for finalize_modus.html.erb
- `tournaments.parse_invitation.*` — for parse_invitation.html.erb

The exact namespace per file is executor discretion per CONTEXT.md D-12 ("Claude picks the namespace per file based on which existing `tournaments.*` subtree is closest"). The above is a starting guide — if a file's content clearly belongs elsewhere (e.g., `_wizard_step.html.erb` is a generic wizard step partial shared across multiple surfaces), pick the most semantically appropriate namespace.

**DO NOT modify (CONTEXT.md D-11 + D-15):**
- `app/views/tournaments/_wizard_steps_v2.html.erb` — already fully i18n'd from Phase 36B, and Plan 38-01 touches it for the G-01 fix
- Any existing `tournaments.parameter_*` keys — Phase 36B parameter form is already fully i18n'd
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Grep audit + namespace assignment — enumerate hardcoded strings, write 38-I18N-AUDIT.md</name>
  <files>.planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md</files>
  <read_first>
    - .planning/phases/38-ux-polish-i18n-debt/38-CONTEXT.md §D-11, §D-12, §D-13, §D-14, §D-15 (audit scope + namespace rules + grep strategy + parallel DE+EN + parameter form exclusion)
    - .planning/milestones/v7.0-phases/36B-ui-cleanup-kleine-features/36B-HUMAN-UAT.md §"G-04" (original gap observation — user quote "vieles auf der Seite ist DE-only")
    - config/locales/de.yml (skim the existing tournaments.* subtree starting at line 1010 — executor must understand the existing key structure before proposing new keys)
    - config/locales/en.yml (matching tournaments.* subtree — for parallel additions)
    - app/views/tournaments/ (full directory listing — confirm the 22-file audit scope matches CONTEXT.md)
  </read_first>
  <action>
    **Step 1 — run the CONTEXT.md D-13 starter grep:**

    ```bash
    grep -rn 'Aktuelle\|Turnier\|Starte\|zurück' app/views/tournaments/ \
      | grep -v "t('" \
      | grep -v "t(\"" \
      | grep -v '_wizard_steps_v2.html.erb'
    ```

    Capture the output verbatim.

    **Step 2 — run a broader German-word sweep:**

    ```bash
    # Common German words that appear in UI strings but rarely in code identifiers
    grep -rnE '(^|[^a-zA-Z_])(Spieler|Teilnehmer|Runde|Setzliste|Meldeliste|Ergebnis|Punkte|Aufnahmen|Disziplin|Modus|Vorgaben|Einladung|Rückblick|Zurück|Weiter|Abbrechen|Speichern|Löschen|Bearbeiten|Bestätigen|Ausgewählt|Schließen|Öffnen|Erstellen|Hinzufügen|Entfernen|Hochladen|Herunterladen|Anzeigen|Verstecken|Sortieren|Filtern|Suchen|Neu|Alle|Keine|Ja|Nein|Fehler|Warnung|Hinweis|Achtung)' \
      app/views/tournaments/ \
      | grep -v "t('" \
      | grep -v "t(\"" \
      | grep -v "t(\"\\.\\." \
      | grep -v '_wizard_steps_v2.html.erb'
    ```

    Also do a pass for common Umlaut-containing words:

    ```bash
    grep -rnP '[A-ZÄÖÜ][a-zäöüß]+(?![a-z_\-])' app/views/tournaments/*.html.erb \
      | grep -v '_wizard_steps_v2.html.erb' \
      | grep -v "t('" \
      | grep -v "t(\""
    ```

    **Step 3 — manually inspect each finding** and classify it as one of:
    - **Hardcoded UI string** — a user-visible German label or button text inside an ERB template (NOT inside a Ruby string that's part of a helper call, NOT a comment, NOT a CSS class, NOT a controller/action name). MUST be localized.
    - **False positive — code identifier** — e.g., a column name, a CSS class, a data- attribute, a helper call argument. SKIP.
    - **False positive — comment** — e.g., `<%# German comment %>` or `<!-- German comment -->`. SKIP (comments are not user-visible).
    - **Already i18n'd** — somehow missed the initial grep filter. SKIP.
    - **Scope-excluded** — belongs to `_wizard_steps_v2.html.erb` or a `tournaments.parameter_*` key already. SKIP.

    **Step 4 — assign i18n key per finding** per CONTEXT.md D-12:
    - File is `tournament_monitor.html.erb` or a monitor-adjacent partial (`_tournament_status`, `_groups`, `_groups_compact`, `_bracket`, `_balls_goal`, `_party_record`) → namespace `tournaments.monitor.*`
    - File is `show.html.erb` / `_show.html.erb` / `_admin_tournament_info.html.erb` → namespace `tournaments.show.*`
    - File is `index.html.erb` / `_tournaments_table.html.erb` → namespace `tournaments.index.*`
    - File is `edit.html.erb` / `_form.html.erb` → namespace `tournaments.edit.*` or `tournaments.form.*` (pick whichever matches existing conventions)
    - File is `new.html.erb` → `tournaments.new.*`
    - File is `new_team.html.erb` → `tournaments.new_team.*`
    - File is `compare_seedings.html.erb` → `tournaments.compare_seedings.*`
    - File is `define_participants.html.erb` → `tournaments.define_participants.*`
    - File is `finalize_modus.html.erb` → `tournaments.finalize_modus.*`
    - File is `parse_invitation.html.erb` → `tournaments.parse_invitation.*`
    - File is `_wizard_step.html.erb` (generic shared partial) → `tournaments.wizard_step.*`
    - File is `_search.html.erb` → `tournaments.search.*`

    Within a namespace, pick short snake_case leaf keys derived from the string's semantic role, NOT the German text itself. Examples:
    - "Zurück" in a back button → `tournaments.monitor.back_button` (NOT `tournaments.monitor.zurueck`)
    - "Aktuelle Spiele" heading → `tournaments.monitor.current_games_heading`
    - "Turnier starten" button → `tournaments.show.start_tournament_button`
    - "Teilnehmerliste" heading → `tournaments.define_participants.heading`

    If the same string appears multiple times with the same semantic (e.g., "Zurück" in 5 different views), reuse the same key — preferably under a shared namespace like `tournaments.common.back` OR duplicate the key per file if the contexts differ. Executor picks — document the decision.

    **Step 5 — write `.planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md`** with the following structure:

    ```markdown
    # Phase 38 I18N-02 Audit

    **Generated:** {date}
    **Scope:** app/views/tournaments/*.html.erb (22 files, excluding _wizard_steps_v2.html.erb per CONTEXT.md D-11)

    ## Summary
    - Total files scanned: 22
    - Files with findings: N
    - Total hardcoded strings found: N
    - False positives skipped: N
    - New i18n keys to add: N

    ## Findings by File

    ### app/views/tournaments/tournament_monitor.html.erb
    | Line | Current text | New key | Notes |
    |------|--------------|---------|-------|
    | 42 | "Aktuelle Spiele" | `tournaments.monitor.current_games_heading` | `<h2>` heading |
    | 67 | "Zurück zum Turnier" | `tournaments.monitor.back_to_tournament` | Back link |
    | ... | ... | ... | ... |

    ### app/views/tournaments/show.html.erb
    | Line | Current text | New key | Notes |
    | ... | ... | ... | ... |

    ## Proposed New Key Tree (DE values verbatim from ERB)

    ```yaml
    de:
      tournaments:
        monitor:
          current_games_heading: Aktuelle Spiele
          back_to_tournament: Zurück zum Turnier
          ...
        show:
          ...
    ```

    ```yaml
    en:
      tournaments:
        monitor:
          current_games_heading: Current games
          back_to_tournament: Back to tournament
          ...
        show:
          ...
    ```

    ## Files with Zero Findings
    - app/views/tournaments/<file>.html.erb — no hardcoded user-visible German strings
    - ...

    ## False Positives Skipped
    | Line | Text | Reason |
    |------|------|--------|
    | foo.html.erb:12 | "Teilnehmer" in data- attribute | CSS/data hook, not user-visible |
    | ... | ... | ... |
    ```

    **Critical:** This task produces ONLY the audit file. It does NOT edit any ERB or YAML files. Tasks 2-5 execute the changes. This task exists so the audit output is reviewable before the bulk edit begins — if the audit finds 200+ strings, the plan may need to split or narrow scope per CONTEXT.md §specifics "warm-up milestone intent" guidance.
  </action>
  <verify>
    <automated>
      test -f .planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md && echo "audit file exists"
      grep -c '^### app/views/tournaments/' .planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md   # ≥ 1 (at least one file section)
      grep -c 'tournaments\.' .planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md                  # ≥ 1 (key namespace mentioned)
      # Sanity: confirm the audit scanned AT LEAST the CONTEXT.md D-13 starter grep terms
      grep -cE 'Aktuelle|Turnier|Starte|zurück|Spieler|Teilnehmer' .planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md   # ≥ 1
    </automated>
  </verify>
  <acceptance_criteria>
    - `.planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md` exists
    - Audit file contains a "Summary" section with total counts
    - Audit file contains at least one "Findings by File" subsection
    - Audit file contains a "Proposed New Key Tree" section with both DE and EN subtrees
    - Audit file mentions `tournaments.monitor.*` OR `tournaments.show.*` OR another `tournaments.<action>.*` namespace
    - Audit file explicitly confirms `_wizard_steps_v2.html.erb` is excluded from scope
    - NO ERB files modified in this task (`git diff --stat app/views/tournaments/` returns zero file changes)
    - NO YAML locale files modified in this task (`git diff --stat config/locales/` returns zero file changes)
    - Audit file includes at least a "False Positives Skipped" section or a "Files with Zero Findings" section (audit completeness signal)
  </acceptance_criteria>
  <done>
    Pre-edit audit complete. `38-I18N-AUDIT.md` enumerates every hardcoded German string in the 22-file scope, assigns each to a target `tournaments.*` i18n namespace + leaf key, and proposes the full DE + EN key tree to add. No ERB or YAML files modified yet — Tasks 2-5 execute the changes based on this audit.
  </done>
</task>

<task type="auto">
  <name>Task 2: Add new keys to config/locales/de.yml + config/locales/en.yml in parallel</name>
  <files>config/locales/de.yml, config/locales/en.yml</files>
  <read_first>
    - .planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md (from Task 1 — the authoritative list of keys to add)
    - .planning/phases/38-ux-polish-i18n-debt/38-CONTEXT.md §D-14 (parallel DE+EN add in one commit; DE authoritative, EN Claude-written, no AI service)
    - config/locales/de.yml around line 1010 (existing `tournaments:` subtree — executor must find the exact insertion point and respect alphabetical/logical ordering within the existing tree)
    - config/locales/en.yml (matching `tournaments:` subtree — executor must find the EN insertion point, parallel to DE)
  </read_first>
  <action>
    Using the "Proposed New Key Tree" section from `38-I18N-AUDIT.md` as the authoritative list:

    **Step 1 — add DE keys to `config/locales/de.yml`:**

    Locate the existing `tournaments:` subtree (starts at line 1010 per Grep). Identify the `tournaments.parameter_*` keys from Phase 36B and DO NOT touch them. Find the appropriate insertion point for each new namespace (`monitor`, `show`, `index`, etc.) — preserve alphabetical ordering within the `tournaments` subtree if the existing tree uses alphabetical order; otherwise group by logical relation.

    Insert new keys with 2-space YAML indent matching the existing tree. Values are the EXACT German strings from the ERB files (relocated, not translated — these are the authoritative DE labels that are about to be replaced by `t(...)` calls in Task 3).

    Example insertion (the exact structure depends on what the audit found):
    ```yaml
      tournaments:
        # ... existing keys preserved ...
        monitor:
          current_games_heading: Aktuelle Spiele
          back_to_tournament: Zurück zum Turnier
          # ... etc
        show:
          # ... etc
        # ... other namespaces from audit ...
        # ... existing parameter_* keys UNTOUCHED ...
    ```

    **Step 2 — add matching EN keys to `config/locales/en.yml`:**

    Locate the matching `tournaments:` subtree. Add the same key structure as DE, with Claude-written English translations. Per CONTEXT.md D-14: "DE is authoritative; EN is a direct translation Claude writes (no AI translation service — these are short UI labels)."

    Translation rules:
    - Short UI labels (1-4 words): direct translation, formal/neutral register
    - Button text: imperative form ("Save" not "To save")
    - Headings: title case for English ("Current Games", not "current games")
    - Keep same semantic — don't reinterpret ambiguous German strings
    - If a German string is idiomatic and hard to translate (rare for UI labels), pick the closest English equivalent and document the choice in a YAML comment above the key

    **Step 3 — sanity checks before commit:**

    - Run `bundle exec rails runner 'puts YAML.load_file("config/locales/de.yml").dig("de", "tournaments").keys'` and confirm the new subtrees appear
    - Run the same for `en.yml` and confirm parity (same keys exist under both locales)
    - Spot-check a handful of new keys via `bundle exec rails runner 'I18n.locale = :de; puts I18n.t("tournaments.monitor.<some_new_key>")'` — should print the German value
    - Repeat with `I18n.locale = :en` — should print the English value

    **Critical constraints:**
    - DO NOT modify any existing `tournaments.parameter_*` keys (CONTEXT.md D-15 — Phase 36B surface is already done)
    - DO NOT modify any existing `tournaments.docs.*` keys (Phase 37 surface)
    - DO NOT modify `en.yml:844-846` `table_monitor.status.warmup*` — that's Plan 38-01 Task 4's surface
    - Both de.yml and en.yml MUST be modified in this same task (CONTEXT.md D-14 says "DE + EN added simultaneously in the same plan commit")
  </action>
  <verify>
    <automated>
      # Both files modified
      git diff --stat config/locales/de.yml | grep -q 'yml' && echo "de.yml modified"
      git diff --stat config/locales/en.yml | grep -q 'yml' && echo "en.yml modified"
      # YAML parses cleanly on both locales
      bundle exec rails runner 'YAML.load_file("config/locales/de.yml")' && echo "de.yml parses"
      bundle exec rails runner 'YAML.load_file("config/locales/en.yml")' && echo "en.yml parses"
      # New namespace present under tournaments
      bundle exec rails runner 'puts YAML.load_file("config/locales/de.yml").dig("de", "tournaments").keys.inspect'
      bundle exec rails runner 'puts YAML.load_file("config/locales/en.yml").dig("en", "tournaments").keys.inspect'
      # Phase 36B parameter_* keys untouched (spot-check)
      grep -c 'parameter_' config/locales/de.yml   # unchanged count from before
      # Plan 38-01 Task 4's warmup keys untouched in THIS task
      grep -c 'warmup: Warm-up' config/locales/en.yml   # either 0 (if Plan 38-01 not merged yet) or 1 (if merged) — should NOT be modified by THIS task
    </automated>
  </verify>
  <acceptance_criteria>
    - `config/locales/de.yml` and `config/locales/en.yml` both show git diff modifications
    - Both YAML files parse cleanly under Rails runner
    - New keys from `38-I18N-AUDIT.md` §"Proposed New Key Tree" are present in BOTH de.yml and en.yml (parity check: `diff <(rails runner 'puts YAML.load_file("config/locales/de.yml").dig("de","tournaments").keys.sort.join("\n")') <(rails runner 'puts YAML.load_file("config/locales/en.yml").dig("en","tournaments").keys.sort.join("\n")')` returns empty — no DE key without EN counterpart)
    - `grep -c 'parameter_' config/locales/de.yml` and `grep -c 'parameter_' config/locales/en.yml` return counts matching the pre-task counts (Phase 36B keys untouched)
    - `tournaments.docs.*` keys (Phase 37) are untouched
    - Spot-check: `bundle exec rails runner 'I18n.locale = :en; puts I18n.t("tournaments.<any_new_key>")'` prints the expected English value without a "translation missing" warning
  </acceptance_criteria>
  <done>
    DE + EN locale files have all new keys from the audit added in parallel. Phase 36B `tournaments.parameter_*` keys untouched. Phase 37 `tournaments.docs.*` keys untouched. Plan 38-01 Task 4's `table_monitor.status.warmup*` keys untouched. Both YAML files parse cleanly and Rails I18n lookup returns the new values.
  </done>
</task>

<task type="auto">
  <name>Task 3: Replace hardcoded strings in tournament_monitor surface ERB files with t(...) calls</name>
  <files>app/views/tournaments/tournament_monitor.html.erb, app/views/tournaments/_tournament_status.html.erb, app/views/tournaments/_groups.html.erb, app/views/tournaments/_groups_compact.html.erb, app/views/tournaments/_bracket.html.erb, app/views/tournaments/_balls_goal.html.erb, app/views/tournaments/_party_record.html.erb</files>
  <read_first>
    - .planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md (the authoritative list of key-to-string mappings for each file in this task's scope)
    - Each file being modified (read ALL of them before editing — the strings must be matched exactly, including any surrounding ERB logic)
    - .planning/phases/38-ux-polish-i18n-debt/38-CONTEXT.md §D-12 (`tournaments.monitor.*` namespace for the monitor surface)
    - config/locales/de.yml after Task 2 (to confirm the keys exist before referencing them)
  </read_first>
  <action>
    For each file in this task's scope, walk through the audit findings for that file and replace each hardcoded German string with the corresponding `t('tournaments.monitor.*')` call.

    **Replacement patterns:**

    Plain text in ERB:
    ```erb
    <!-- Before -->
    <h2>Aktuelle Spiele</h2>

    <!-- After -->
    <h2><%= t('tournaments.monitor.current_games_heading') %></h2>
    ```

    String argument to Rails helper:
    ```erb
    <!-- Before -->
    <%= link_to "Zurück zum Turnier", tournament_path(@tournament), class: "btn" %>

    <!-- After -->
    <%= link_to t('tournaments.monitor.back_to_tournament'), tournament_path(@tournament), class: "btn" %>
    ```

    String inside a helper that already uses `t('...')` for other args: use `t('...')` consistently.

    String with interpolation (e.g., "Es sind bereits #{count} Spieler vorhanden"):
    ```erb
    <!-- Before -->
    <%= "Es sind bereits #{count} Spieler vorhanden" %>

    <!-- After: key with a pluralization/interpolation -->
    <%= t('tournaments.monitor.players_present_count', count: count) %>

    <!-- And in de.yml: -->
    <!-- players_present_count: "Es sind bereits %{count} Spieler vorhanden" -->
    ```

    String inside HTML attribute (title, alt, placeholder):
    ```erb
    <!-- Before -->
    <button title="Turnier starten">Start</button>

    <!-- After -->
    <button title="<%= t('tournaments.monitor.start_tournament_title') %>"><%= t('tournaments.monitor.start_button') %></button>
    ```

    **Scope for THIS task (monitor surface only):**
    - `tournament_monitor.html.erb`
    - `_tournament_status.html.erb`
    - `_groups.html.erb`
    - `_groups_compact.html.erb`
    - `_bracket.html.erb`
    - `_balls_goal.html.erb`
    - `_party_record.html.erb`

    Tasks 4 and 5 handle the remaining files.

    **Critical constraints:**
    - Every replaced string MUST have a corresponding key in `config/locales/de.yml` (added by Task 2). If a key is missing, STOP, add it to both de.yml and en.yml, then continue. Do NOT leave dangling `t(...)` calls with missing keys.
    - Preserve all ERB logic, HTML structure, and indentation. Only the string literals change.
    - Do NOT touch `_wizard_steps_v2.html.erb` — it's excluded from scope per CONTEXT.md D-11 and Plan 38-01 is modifying it for G-01.
    - Do NOT touch existing `t('tournaments.parameter_*')` calls — Phase 36B surface is done.
    - Do NOT introduce `raw` / `html_safe` / `<%==` for the replaced strings — Rails I18n default escaping is sufficient and matches existing patterns.

    **Post-edit verification per file:**
    After editing each file, run `bundle exec erblint <file>` and confirm exit 0. If erblint fails, fix the issue before moving to the next file.
  </action>
  <verify>
    <automated>
      # Every modified file still parses via erblint
      bundle exec erblint app/views/tournaments/tournament_monitor.html.erb
      bundle exec erblint app/views/tournaments/_tournament_status.html.erb
      bundle exec erblint app/views/tournaments/_groups.html.erb
      bundle exec erblint app/views/tournaments/_groups_compact.html.erb
      bundle exec erblint app/views/tournaments/_bracket.html.erb
      bundle exec erblint app/views/tournaments/_balls_goal.html.erb
      bundle exec erblint app/views/tournaments/_party_record.html.erb
      # Re-run the CONTEXT.md D-13 starter grep on the monitor-surface files (should now show zero findings)
      grep -rnE '(Aktuelle|Turnier[^_]|Starte|zurück)' \
        app/views/tournaments/tournament_monitor.html.erb \
        app/views/tournaments/_tournament_status.html.erb \
        app/views/tournaments/_groups.html.erb \
        app/views/tournaments/_groups_compact.html.erb \
        app/views/tournaments/_bracket.html.erb \
        app/views/tournaments/_balls_goal.html.erb \
        app/views/tournaments/_party_record.html.erb \
        | grep -v "t('" \
        | grep -v "t(\"" \
        | wc -l   # must be 0 (or justified false-positives documented in 38-I18N-AUDIT.md)
      # t('tournaments.monitor.*') calls present
      grep -rc "t('tournaments\.monitor\." app/views/tournaments/tournament_monitor.html.erb | grep -v ':0$' | wc -l   # ≥ 1 (at least one call added)
    </automated>
  </verify>
  <acceptance_criteria>
    - `bundle exec erblint` exits 0 on all 7 files in this task's scope
    - Starter grep (`Aktuelle|Turnier|Starte|zurück`) on the 7 files returns zero matches outside `t('...')` / `t("...")` calls
    - `grep -c "t('tournaments\.monitor\." app/views/tournaments/tournament_monitor.html.erb` returns ≥ 1 (at least one t-call added to the primary file)
    - Every `t('tournaments.monitor.*')` call references a key that exists in `config/locales/de.yml` AND `config/locales/en.yml` (verified by Task 6 verification sweep, but spot-checked here)
    - `_wizard_steps_v2.html.erb` is UNCHANGED in this task (`git diff --stat app/views/tournaments/_wizard_steps_v2.html.erb` returns empty)
    - Existing `t('tournaments.parameter_*')` calls are UNCHANGED (Phase 36B surface preserved)
  </acceptance_criteria>
  <done>
    All 7 monitor-surface ERB files have their hardcoded German strings replaced with `t('tournaments.monitor.*')` calls. erblint passes. The starter grep returns zero findings for this file subset.
  </done>
</task>

<task type="auto">
  <name>Task 4: Replace hardcoded strings in tournament show/index/admin ERB files</name>
  <files>app/views/tournaments/show.html.erb, app/views/tournaments/_show.html.erb, app/views/tournaments/_admin_tournament_info.html.erb, app/views/tournaments/index.html.erb, app/views/tournaments/_tournaments_table.html.erb, app/views/tournaments/_search.html.erb, app/views/tournaments/_form.html.erb, app/views/tournaments/_wizard_step.html.erb</files>
  <read_first>
    - .planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md (mapping of hardcoded strings to keys for files in this task's scope)
    - Each file being modified (full read before editing)
    - .planning/phases/38-ux-polish-i18n-debt/38-CONTEXT.md §D-12 (namespace assignment: tournaments.show.* / tournaments.index.* / etc.)
    - config/locales/de.yml after Task 2 (to confirm the keys exist)
  </read_first>
  <action>
    Same pattern as Task 3, but for the tournament show/index/admin surface. For each file in this task's scope:

    - `show.html.erb` → `tournaments.show.*`
    - `_show.html.erb` → `tournaments.show.*`
    - `_admin_tournament_info.html.erb` → `tournaments.show.*` (admin subsection of show page per CONTEXT.md D-12)
    - `index.html.erb` → `tournaments.index.*`
    - `_tournaments_table.html.erb` → `tournaments.index.*` (listing partial)
    - `_search.html.erb` → `tournaments.search.*`
    - `_form.html.erb` → `tournaments.form.*` or `tournaments.edit.*` (pick per CONTEXT.md D-12 "existing tree proximity")
    - `_wizard_step.html.erb` → `tournaments.wizard_step.*` (generic shared partial)

    Apply the same replacement patterns from Task 3 (plain text, helper arguments, attribute strings, interpolations).

    **Critical constraints (repeated from Task 3):**
    - Every replaced string must have a corresponding key added in Task 2 — if a key is missing, STOP and add to both de.yml and en.yml before continuing
    - Do NOT touch `_wizard_steps_v2.html.erb` (excluded from scope)
    - Do NOT touch existing `t('tournaments.parameter_*')` or `t('tournaments.docs.*')` calls
    - erblint must pass on every modified file
  </action>
  <verify>
    <automated>
      bundle exec erblint app/views/tournaments/show.html.erb
      bundle exec erblint app/views/tournaments/_show.html.erb
      bundle exec erblint app/views/tournaments/_admin_tournament_info.html.erb
      bundle exec erblint app/views/tournaments/index.html.erb
      bundle exec erblint app/views/tournaments/_tournaments_table.html.erb
      bundle exec erblint app/views/tournaments/_search.html.erb
      bundle exec erblint app/views/tournaments/_form.html.erb
      bundle exec erblint app/views/tournaments/_wizard_step.html.erb
      # Starter grep returns zero unlocalized matches on this file subset
      grep -rnE '(Aktuelle|Turnier[^_]|Starte|zurück)' \
        app/views/tournaments/show.html.erb \
        app/views/tournaments/_show.html.erb \
        app/views/tournaments/_admin_tournament_info.html.erb \
        app/views/tournaments/index.html.erb \
        app/views/tournaments/_tournaments_table.html.erb \
        app/views/tournaments/_search.html.erb \
        app/views/tournaments/_form.html.erb \
        app/views/tournaments/_wizard_step.html.erb \
        | grep -v "t('" \
        | grep -v "t(\"" \
        | wc -l   # must be 0
    </automated>
  </verify>
  <acceptance_criteria>
    - `bundle exec erblint` exits 0 on all 8 files in this task's scope
    - Starter grep returns zero unlocalized matches on the 8 files
    - At least one `t('tournaments.show.*')` or `t('tournaments.index.*')` call is present in the modified files
    - Existing `t('tournaments.parameter_*')` and `t('tournaments.docs.*')` calls are UNCHANGED
    - `_wizard_steps_v2.html.erb` UNCHANGED
  </acceptance_criteria>
  <done>
    All 8 show/index/admin-surface ERB files have their hardcoded German strings replaced with appropriate `t('tournaments.*')` calls. erblint passes.
  </done>
</task>

<task type="auto">
  <name>Task 5: Replace hardcoded strings in edit/new/compare/finalize/parse action ERB files</name>
  <files>app/views/tournaments/edit.html.erb, app/views/tournaments/new.html.erb, app/views/tournaments/new_team.html.erb, app/views/tournaments/compare_seedings.html.erb, app/views/tournaments/define_participants.html.erb, app/views/tournaments/finalize_modus.html.erb, app/views/tournaments/parse_invitation.html.erb</files>
  <read_first>
    - .planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md (mapping for files in this task's scope)
    - Each file being modified (full read before editing)
    - .planning/phases/38-ux-polish-i18n-debt/38-CONTEXT.md §D-12 (namespace per action view)
    - config/locales/de.yml after Task 2
  </read_first>
  <action>
    Same pattern as Tasks 3 and 4, but for the action views:

    - `edit.html.erb` → `tournaments.edit.*`
    - `new.html.erb` → `tournaments.new.*`
    - `new_team.html.erb` → `tournaments.new_team.*`
    - `compare_seedings.html.erb` → `tournaments.compare_seedings.*`
    - `define_participants.html.erb` → `tournaments.define_participants.*`
    - `finalize_modus.html.erb` → `tournaments.finalize_modus.*`
    - `parse_invitation.html.erb` → `tournaments.parse_invitation.*`

    Same replacement patterns, same constraints (no `_wizard_steps_v2.html.erb`, no `parameter_*` / `docs.*` touching, erblint passes).

    **Note on Rails form scaffolding:** The `new.html.erb` and `edit.html.erb` files may contain strings that come from Rails form helpers (e.g., `f.label :name` auto-localizes via `activerecord.attributes.tournament.name`). Those are NOT hardcoded strings — they use Rails' implicit I18n lookup. Only touch explicit hardcoded German strings, not the scaffolded form helpers.
  </action>
  <verify>
    <automated>
      bundle exec erblint app/views/tournaments/edit.html.erb
      bundle exec erblint app/views/tournaments/new.html.erb
      bundle exec erblint app/views/tournaments/new_team.html.erb
      bundle exec erblint app/views/tournaments/compare_seedings.html.erb
      bundle exec erblint app/views/tournaments/define_participants.html.erb
      bundle exec erblint app/views/tournaments/finalize_modus.html.erb
      bundle exec erblint app/views/tournaments/parse_invitation.html.erb
      grep -rnE '(Aktuelle|Turnier[^_]|Starte|zurück)' \
        app/views/tournaments/edit.html.erb \
        app/views/tournaments/new.html.erb \
        app/views/tournaments/new_team.html.erb \
        app/views/tournaments/compare_seedings.html.erb \
        app/views/tournaments/define_participants.html.erb \
        app/views/tournaments/finalize_modus.html.erb \
        app/views/tournaments/parse_invitation.html.erb \
        | grep -v "t('" \
        | grep -v "t(\"" \
        | wc -l   # must be 0
    </automated>
  </verify>
  <acceptance_criteria>
    - `bundle exec erblint` exits 0 on all 7 files in this task's scope
    - Starter grep returns zero unlocalized matches on the 7 files
    - Rails form scaffolding left alone (no unnecessary `t(...)` wrapping of `f.label`/`f.submit` defaults)
    - `_wizard_steps_v2.html.erb` UNCHANGED
  </acceptance_criteria>
  <done>
    All 7 action-view ERB files have their hardcoded German strings replaced with `t('tournaments.<action>.*')` calls. erblint passes. All 22 files in the audit scope are now i18n'd.
  </done>
</task>

<task type="auto">
  <name>Task 6: Verification sweep — zero-match grep + locale smoke test under :en</name>
  <files></files>
  <read_first>
    - .planning/phases/38-ux-polish-i18n-debt/38-CONTEXT.md §D-13 (authoritative grep pattern)
    - .planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md (the false-positive list — these are allowed to remain after audit, the verification sweep should NOT re-flag them)
  </read_first>
  <action>
    **Step 1 — Final grep sweep across the full audit scope:**

    Re-run the CONTEXT.md D-13 starter grep plus the broader sweep from Task 1 Step 2. Expected result: zero unlocalized matches on any file except `_wizard_steps_v2.html.erb` (excluded) and any false-positive sites documented in `38-I18N-AUDIT.md`.

    ```bash
    # Starter grep
    grep -rn 'Aktuelle\|Turnier\|Starte\|zurück' app/views/tournaments/ \
      | grep -v "t('" \
      | grep -v "t(\"" \
      | grep -v '_wizard_steps_v2.html.erb'
    # Expected: zero output (or only false-positives that match entries in 38-I18N-AUDIT.md)

    # Broader sweep
    grep -rnE '(^|[^a-zA-Z_])(Spieler|Teilnehmer|Runde|Setzliste|Meldeliste|Ergebnis|Punkte|Aufnahmen|Vorgaben|Einladung|Zurück|Weiter|Abbrechen|Speichern|Löschen|Bearbeiten|Bestätigen|Schließen|Öffnen|Erstellen|Hinzufügen|Entfernen|Hochladen|Anzeigen|Neu|Alle|Keine|Fehler|Warnung|Hinweis)' \
      app/views/tournaments/ \
      | grep -v "t('" \
      | grep -v "t(\"" \
      | grep -v '_wizard_steps_v2.html.erb'
    # Expected: zero output OR only entries matching the "False Positives Skipped" section of 38-I18N-AUDIT.md
    ```

    If any finding appears that is NOT in the false-positives list:
    - Investigate — is it a missed hardcoded string? Add to the audit retroactively, add the key to de.yml + en.yml, and replace in the ERB
    - OR is it a legitimate false positive? Add to the false-positives list in 38-I18N-AUDIT.md
    - Either way: iterate until the grep is clean

    **Step 2 — Rails locale smoke test under :en:**

    Run a controller test or a Rails runner command that loads and renders one representative view from each namespace under `I18n.locale = :en`:

    ```bash
    bundle exec rails runner '
      I18n.locale = :en
      # Force load all new keys — missing-key warnings will print to stderr
      %w[
        tournaments.monitor.current_games_heading
        tournaments.show.start_tournament_button
        tournaments.index.new_tournament
      ].each do |key|
        puts "#{key} => #{I18n.t(key, raise: true)}"
      end
    '
    ```

    Replace the three example keys with 3-5 actual keys from the audit. If any `I18n.t(key, raise: true)` raises `I18n::MissingTranslationData`, the en.yml key is missing — fix Task 2's work and re-run.

    **Step 3 — Rails locale smoke test under :de:**

    Same as Step 2 but with `I18n.locale = :de`. All keys must exist under both locales (parity requirement from CONTEXT.md D-14).

    **Step 4 — Optional integration smoke:** If the carambus_api project has any controller test that renders a tournament view under `I18n.locale = :en`, run it and confirm it doesn't print "translation missing" warnings. (Skip if no such test exists — the explicit key lookups in Steps 2-3 are sufficient.)

    **Step 5 — Lint pass:**
    ```bash
    bundle exec erblint --lint-all
    # Focus on app/views/tournaments/ findings; the rest of the codebase is out of scope
    ```
    Confirm no new erblint regressions introduced by Plan 38-02 edits.

    **Step 6 — Final standardrb check on touched Ruby paths:**
    ```bash
    bundle exec standardrb config/locales/
    # YAML files — may be a no-op; defensive
    ```

    If this task finds any issues, iterate (fix + re-verify) until all 6 steps pass.
  </action>
  <verify>
    <automated>
      # Zero unlocalized German in scope (modulo false-positives)
      grep -rn 'Aktuelle\|Turnier\|Starte\|zurück' app/views/tournaments/ \
        | grep -v "t('" | grep -v "t(\"" | grep -v '_wizard_steps_v2.html.erb' | wc -l   # ≤ number of documented false-positives
      # Key parity: every tournaments.* DE key has an EN counterpart
      bundle exec rails runner '
        de_keys = YAML.load_file("config/locales/de.yml").dig("de","tournaments").keys.sort
        en_keys = YAML.load_file("config/locales/en.yml").dig("en","tournaments").keys.sort
        if de_keys == en_keys
          puts "PARITY OK (#{de_keys.length} top-level namespaces)"
        else
          puts "PARITY FAIL: de-only=#{(de_keys-en_keys).inspect}, en-only=#{(en_keys-de_keys).inspect}"
          exit 1
        end
      '
      # erblint clean on all tournament views
      bundle exec erblint app/views/tournaments/   # exit 0 (or only pre-existing warnings)
    </automated>
  </verify>
  <acceptance_criteria>
    - CONTEXT.md D-13 starter grep returns 0 matches on `app/views/tournaments/` excluding `_wizard_steps_v2.html.erb` and documented false-positives
    - Broader German-word sweep returns 0 matches (same exclusions)
    - Rails runner key-parity check prints "PARITY OK" (all `tournaments.*` top-level namespaces exist in both de.yml and en.yml)
    - Rails runner :en smoke test executes 3-5 sample keys with `raise: true` and prints all values without raising
    - Rails runner :de smoke test executes the same sample keys and prints German values without raising
    - `bundle exec erblint app/views/tournaments/` exits 0 (or exits with pre-existing warnings only — no new erblint regressions from Plan 38-02)
    - `_wizard_steps_v2.html.erb` UNCHANGED (`git diff --stat app/views/tournaments/_wizard_steps_v2.html.erb` empty — it's Plan 38-01's file)
    - Existing `tournaments.parameter_*` keys (Phase 36B) UNCHANGED
    - Existing `tournaments.docs.*` keys (Phase 37) UNCHANGED
  </acceptance_criteria>
  <done>
    Post-edit verification complete. Zero hardcoded German strings remain on the 22-file audit scope (modulo documented false-positives). DE+EN key parity confirmed. Rails I18n lookup works under both locales for all new keys. erblint clean on `app/views/tournaments/`. Plan 38-02 is complete and I18N-02 is closed.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Browser → Rails view rendering | ERB templates render HTML; hardcoded string literals replaced with `t(...)` calls that look up values from YAML at request time |
| Rails I18n lookup | `t('tournaments.*')` fetches values from `config/locales/de.yml` / `config/locales/en.yml` under the current `I18n.locale` |
| YAML file parse at Rails boot | New keys added to two YAML files — parse errors would block boot |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-38-02-01 | Tampering / XSS | ERB string replacement with `t(...)` calls | accept | Rails `t(...)` returns an HTML-escaped string by default when called in an ERB template via `<%= %>`. Replacement preserves the existing escape semantics (same `<%= %>` vs `<%==` contexts). No new `raw` / `html_safe` introduced — Task 3-5 actions explicitly prohibit them. |
| T-38-02-02 | Injection via i18n interpolation | Keys with `%{count}`-style interpolations | mitigate | Rails I18n interpolation uses `%{name}` placeholders substituted via safe string formatting, not ERB `eval`. Interpolated values are HTML-escaped at ERB render time (`<%= t('key', count: user_input) %>`). Tasks 3-5 replacement instructions use `t('key', count: count)` form, NOT string concatenation. |
| T-38-02-03 | Denial of Service | Malformed YAML crashes Rails boot | mitigate | Task 2 acceptance criterion explicitly runs `bundle exec rails runner 'YAML.load_file(...)'` on both locale files before commit. Task 6 re-runs a full Rails runner smoke test that boots the framework and performs I18n lookups. A malformed YAML would fail the smoke test. |
| T-38-02-04 | Information Disclosure | New i18n keys expose sensitive data | accept | All new keys are static UI labels (headings, button text, placeholders) relocated from existing ERB literals. No PII, no user-interpolated content, no secrets. The information content is identical to what ERB currently renders — just stored in a different file. |
| T-38-02-05 | Elevation of Privilege | Admin-only views (`_admin_tournament_info.html.erb`) touched | accept | The admin gate is in the controller layer (Pundit / CanCanCan authorization), not the view. Localizing strings in admin views does NOT change who can see them. No new routes, no new controllers, no new policies. |
| T-38-02-06 | Repudiation | Missing audit trail for string changes | accept | Git commit history provides the audit trail. Task 1 produces `38-I18N-AUDIT.md` as an explicit pre-edit inventory for post-hoc review. |

**Overall risk:** LOW. This plan is pure string relocation — hardcoded literals moved from ERB into YAML files with `t(...)` call replacements. Rails I18n is a mature, widely-audited framework. The only genuine risk is YAML parse errors (mitigated by Task 2 and Task 6 smoke tests) and accidental `html_safe` introduction (explicitly prohibited in task actions). No user input touches the i18n lookup path beyond the existing `params[:locale]` / session locale mechanism, which is unchanged.
</threat_model>

<verification>
## Plan-level verification

```bash
# Task 1: audit file exists and is populated
test -f .planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md
grep -c 'tournaments\.' .planning/phases/38-ux-polish-i18n-debt/38-I18N-AUDIT.md    # ≥ 1

# Task 2: key parity between de.yml and en.yml
bundle exec rails runner '
  de_keys = YAML.load_file("config/locales/de.yml").dig("de","tournaments").keys.sort
  en_keys = YAML.load_file("config/locales/en.yml").dig("en","tournaments").keys.sort
  abort "PARITY FAIL" unless de_keys == en_keys
  puts "PARITY OK (#{de_keys.length} namespaces)"
'

# Tasks 3-5: erblint on all tournament ERB files
bundle exec erblint app/views/tournaments/
# Exit 0 (or only pre-existing warnings — no new regressions)

# Task 6: final zero-match grep sweep
grep -rn 'Aktuelle\|Turnier\|Starte\|zurück' app/views/tournaments/ \
  | grep -v "t('" | grep -v "t(\"" | grep -v '_wizard_steps_v2.html.erb'
# Expected: zero output (or only false-positives documented in 38-I18N-AUDIT.md)

# Task 6: locale smoke test under :en
bundle exec rails runner '
  I18n.locale = :en
  # Picks 3-5 actual keys from the audit
  keys = YAML.load_file("config/locales/en.yml").dig("en","tournaments","monitor")&.keys || []
  keys.first(3).each do |k|
    puts "tournaments.monitor.#{k} => #{I18n.t("tournaments.monitor.#{k}", raise: true)}"
  end
'

# Negative checks — Plan 38-02 does NOT touch these files/keys:
git diff --stat app/views/tournaments/_wizard_steps_v2.html.erb   # empty
grep -c 'parameter_' config/locales/de.yml    # unchanged from pre-task count
grep -c 'parameter_' config/locales/en.yml    # unchanged from pre-task count
```
</verification>

<success_criteria>
Plan 38-02 is complete when:

1. I18N-02 (G-04) — Zero hardcoded German user-visible strings remain in `app/views/tournaments/*.html.erb` outside `_wizard_steps_v2.html.erb` and documented false-positives. Verified via the CONTEXT.md D-13 starter grep + the broader sweep.
2. All new i18n keys live under the `tournaments.monitor.*` / `tournaments.show.*` / `tournaments.<action>.*` subtrees per CONTEXT.md D-12.
3. DE + EN key parity — every new `tournaments.*` key exists in BOTH `config/locales/de.yml` AND `config/locales/en.yml` (CONTEXT.md D-14).
4. `38-I18N-AUDIT.md` exists as a pre-edit inventory artifact with findings-by-file, proposed new keys, and a false-positives section.
5. `bundle exec erblint app/views/tournaments/` exits 0 (or with pre-existing warnings only).
6. Rails I18n lookup under `I18n.locale = :en` and `I18n.locale = :de` returns values for all new keys without raising `I18n::MissingTranslationData`.
7. `_wizard_steps_v2.html.erb` UNCHANGED (excluded from scope per CONTEXT.md D-11).
8. Existing `tournaments.parameter_*` (Phase 36B) and `tournaments.docs.*` (Phase 37) keys UNCHANGED.
9. No modifications to `config/locales/en.yml:844-846` (`table_monitor.status.warmup*`) — that's Plan 38-01 Task 4's surface; the two plans must not conflict.
10. No modifications to `app/models/discipline.rb`, `DISCIPLINE_PARAMETER_RANGES`, or any DATA-01-adjacent code (DATA-01 is Phase 39, not Phase 38).
</success_criteria>

<output>
After completion, create `.planning/phases/38-ux-polish-i18n-debt/38-02-SUMMARY.md` following the project template. Include:
- Frontmatter: phase, plan, type, status: complete, requirements: [I18N-02]
- What changed (count of ERB files modified, count of new i18n keys added, audit artifact link)
- Key decisions from CONTEXT.md honored (D-11 scope exclusion, D-12 namespace assignment, D-13 grep strategy, D-14 parallel DE+EN, D-15 Phase 36B preservation)
- Link to `38-I18N-AUDIT.md` as the pre-edit audit record
- Link to the final verification grep output (zero-match confirmation)
- Deferred: full `app/views/` audit beyond `tournaments/` (explicitly out of scope per REQUIREMENTS.md "Out of Scope" table)
</output>
