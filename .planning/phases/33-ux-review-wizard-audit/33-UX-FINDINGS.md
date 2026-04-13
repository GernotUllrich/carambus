# Phase 33 — UX Findings: Tournament Wizard Audit

**Phase:** 33-ux-review-wizard-audit
**Date:** 2026-04-13
**Status:** Complete — Phase 33 final (2026-04-13)

---

## Reproduction recipe

**⚠ Scenario: `carambus_bcw` (NOT `carambus_api`)**

The walkthrough MUST run against a `context: LOCAL` scenario. `carambus_api` runs in API mode in dev — `LocalProtector` blocks writes on global records and many tournament management actions behave differently or are blocked. `carambus_bcw` is the canonical local-server checkout with a populated tournament DB and unrestricted writes.

GSD planning artifacts (this file, screenshots, PLAN.md) still live in `carambus_api/.planning/` — only the runtime dev server runs in `carambus_bcw`. Source code is identical (same git commit), so all line-number references to `tournaments_controller.rb` / `tournament.rb` / `show.html.erb` apply unchanged.

**Why a global (synced) CAROM tournament that is upcoming and not-yet-played:** Three constraints compound:

1. **Global/synced (`id < 50_000_000`):** The realistic volunteer workflow operates on tournaments synced from the central API server. A central carambus.net publishes e.g. an NBV Bezirksmeisterschaft; a LOCAL club like BCW syncs it and runs it. `LocalProtector` has carve-outs that allow wizard-triggered operations (state transitions, scoring, monitoring) on these synced records while still blocking writes to identity fields (title, dates, organizer). A purely local tournament (`id >= MIN_ID`) would bypass exactly the code paths the volunteer actually exercises.
2. **Carom (Karambol) discipline — NOT Pool / Snooker:** Only carom disciplines have pre-built `TournamentPlan`s in the system (excepting single-elimination KO formats). The wizard's "Setup" step reads from these pre-built plans; a Pool or Snooker tournament forces a different (and less representative) code path. Observing the canonical wizard behavior requires a tournament whose discipline is one of `Freie Partie`, `Cadre 35/2`, `Cadre 47/1`, `Cadre 47/2`, `Cadre 71/2`, `Dreiband`, `Einband`, etc. — never Pool, never Snooker.
3. **Upcoming and not yet played:** The tournament's `date` must be in the near future (so the wizard shows the full "pre-play" happy path) and its state must still be `new_tournament` (so none of the wizard steps have been completed yet). A tournament that already ran would skip straight past the steps Phase 33 needs to observe.

```bash
# Dev server: started via RubyMine run configuration against carambus_bcw
# bind: 0.0.0.0  port: 3007  (note: non-standard port — NOT 3000)
# Verified reachable: curl http://localhost:3007/tournaments/17403 → HTTP 200

# If you need to start it from the shell instead:
# cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
# bin/rails server -b 0.0.0.0 -p 3007
# or: foreman start -f Procfile.dev  (check Procfile.dev for the default port)

# In another shell, list upcoming carom tournaments still in new_tournament state
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
psql carambus_bcw_development -c "
  SELECT t.id, t.title, t.state, t.date::date, d.name AS discipline
  FROM tournaments t
  JOIN disciplines d ON d.id = t.discipline_id
  WHERE t.state = 'new_tournament'
    AND t.id < 50000000
    AND t.date >= CURRENT_DATE - INTERVAL '7 days'
    AND d.name NOT ILIKE '%pool%'
    AND d.name NOT ILIKE '%snooker%'
  ORDER BY t.date ASC
  LIMIT 15;"

# Chosen tournament for this walkthrough (queried 2026-04-13):
# TOURNAMENT_ID=17403
# TITLE="NDM Freie Partie Klasse 1-3"
# DISCIPLINE="Freie Partie klein"  (carom — has pre-built TournamentPlan code path)
# DATE=2026-04-19  (upcoming, 6 days out)
# AASM_STATE=new_tournament
# id < 50_000_000 (GLOBAL / synced), organizer=Region (NBV)
# URL: http://localhost:3007/tournaments/17403

# If the tournament needs participants for the finish_seeding / start steps, inspect first:
# cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
# bin/rails runner 't = Tournament.find(17403); puts "players=#{t.tournament_players.count}, plan=#{t.tournament_plan_id.inspect}, modus=#{t.modus}"'
# Note: t.tournament_plan_id starts as NULL — the wizard ASSIGNS it when the director
# walks through the setup step. Observing this assignment is one of the audit targets.
```

**Preconditions before starting:**
- You are on the `carambus_bcw` checkout, `ApplicationRecord.local_server?` returns `true`
- Logged in as a user with the `tournament_director` role (`User.first.roles.map(&:name)` to check)
- The tournament is GLOBAL/synced (`id < 50_000_000`), carom discipline, upcoming date, still `new_tournament`
- `has_clubcloud_results?` returns `false` for the tournament (otherwise the wizard is hidden)
- The wizard only renders when: `tournament_director?(current_user)` is true AND `local_server?` is true AND `!@tournament.has_clubcloud_results?`
- **Expect LocalProtector carve-outs:** some fields (title, date, organizer) will be read-only because `LocalProtector` blocks identity-field writes on global records. That is correct behavior and itself a finding to document if the UI doesn't communicate it clearly.

---

## Canonical wizard partial — grep evidence (UX-01)

This section preserves the machine-checkable evidence proving that `_wizard_steps_v2.html.erb` is the only wizard partial rendered by `show.html.erb`. Downstream agents can re-run these commands verbatim to re-verify.

### Command 1: all wizard_steps / wizard_step references across app/, config/, test/

```
grep -rn "wizard_steps\|wizard_step" app/ config/ test/
```

Output:

```
app/views/tournaments/_wizard_steps.html.erb:26:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps.html.erb:29:      status: wizard_step_status(tournament, 1),
app/views/tournaments/_wizard_steps.html.erb:31:        text: wizard_step_status(tournament, 1) == :completed ? 'Erneut bearbeiten' : 'Spieler bearbeiten',
app/views/tournaments/_wizard_steps.html.erb:42:    <div class="wizard-step <%= step_class(wizard_step_status(tournament, 2)) %> wizard-step-optional">
app/views/tournaments/_wizard_steps.html.erb:45:          <%= step_icon(wizard_step_status(tournament, 2)) %>
app/views/tournaments/_wizard_steps.html.erb:108:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps.html.erb:111:      status: wizard_step_status(tournament, 3),
app/views/tournaments/_wizard_steps.html.erb:116:        class: wizard_step_status(tournament, 3) != :active ? 'opacity-25' : ''
app/views/tournaments/_wizard_steps.html.erb:119:      warning: wizard_step_status(tournament, 3) == :active,
app/views/tournaments/_wizard_steps.html.erb:124:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps.html.erb:127:      status: wizard_step_status(tournament, 4),
app/views/tournaments/_wizard_steps.html.erb:133:        class: wizard_step_status(tournament, 4) != :active ? 'opacity-25' : ''
app/views/tournaments/_wizard_steps.html.erb:141:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps.html.erb:144:      status: wizard_step_status(tournament, 5),
app/views/tournaments/_wizard_steps.html.erb:149:        class: wizard_step_status(tournament, 5) != :active ? 'opacity-25' : ''
app/views/tournaments/_wizard_steps.html.erb:157:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps.html.erb:160:      status: wizard_step_status(tournament, 6),
app/views/tournaments/_wizard_steps.html.erb:165:        class: "#{wizard_step_status(tournament, 6) != :active ? 'opacity-25' : ''} #{tournament.tournament_started? ? 'btn-success' : ''}"
app/views/tournaments/_wizard_steps.html.erb:168:      warning: wizard_step_status(tournament, 6) == :active && !tournament.tournament_started?,
app/views/tournaments/_wizard_steps.html.erb:175:<% if wizard_step_status(tournament, 2) == :active && tournament.organizer.is_a?(Region) %>
app/views/tournaments/show.html.erb:35:    <%= render 'wizard_steps_v2', tournament: @tournament %>
app/views/tournaments/_wizard_steps_v2.html.erb:29:    <div class="wizard-step <%= step_class(wizard_step_status(tournament, 1)) %> wizard-step-optional">
app/views/tournaments/_wizard_steps_v2.html.erb:32:          <%= step_icon(wizard_step_status(tournament, 1)) %>
app/views/tournaments/_wizard_steps_v2.html.erb:38:            <% if wizard_step_status(tournament, 1) == :completed %>
app/views/tournaments/_wizard_steps_v2.html.erb:140:  <div class="wizard-step <%= step_class(wizard_step_status(tournament, 2)) %>">
app/views/tournaments/_wizard_steps_v2.html.erb:143:        <%= step_icon(wizard_step_status(tournament, 2)) %>
app/views/tournaments/_wizard_steps_v2.html.erb:163:        <% if non_local_seedings_count > 0 && wizard_step_status(tournament, 2) == :active %>
app/views/tournaments/_wizard_steps_v2.html.erb:170:        <% if wizard_step_status(tournament, 2) == :active && !tournament.data['invitation_filename'].present? && non_local_seedings_count == 0 %>
app/views/tournaments/_wizard_steps_v2.html.erb:198:      <% step_2_status = wizard_step_status(tournament, 2) %>
app/views/tournaments/_wizard_steps_v2.html.erb:247:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps_v2.html.erb:250:      status: wizard_step_status(tournament, 3),
app/views/tournaments/_wizard_steps_v2.html.erb:257:      warning: wizard_step_status(tournament, 3) == :active ? "Dieser Schritt bleibt offen bis zur endgültigen Festschreibung in Schritt 4" : false,
app/views/tournaments/_wizard_steps_v2.html.erb:268:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps_v2.html.erb:271:      status: wizard_step_status(tournament, 4),
app/views/tournaments/_wizard_steps_v2.html.erb:277:        class: wizard_step_status(tournament, 4) != :active ? 'opacity-25' : ''
app/views/tournaments/_wizard_steps_v2.html.erb:286:  <%= render 'wizard_step',
app/views/tournaments/_wizard_steps_v2.html.erb:289:      status: wizard_step_status(tournament, 5),
app/views/tournaments/_wizard_steps_v2.html.erb:294:        class: wizard_step_status(tournament, 5) != :active ? 'opacity-25' : ''
app/views/tournaments/_wizard_steps_v2.html.erb:303:  <div class="wizard-step <%= step_class(wizard_step_status(tournament, 6)) %>">
app/views/tournaments/_wizard_steps_v2.html.erb:306:        <%= step_icon(wizard_step_status(tournament, 6)) %>
app/views/tournaments/_wizard_steps_v2.html.erb:317:        <% if wizard_step_status(tournament, 6) == :active && !tournament.tournament_started %>
app/views/tournaments/_wizard_steps_v2.html.erb:350:      <% elsif wizard_step_status(tournament, 6) == :active %>
app/views/tournaments/_wizard_steps_v2.html.erb:355:      <% elsif wizard_step_status(tournament, 6) == :completed %>
app/helpers/tournament_wizard_helper.rb:36:  def wizard_step_status(tournament, step_number)
app/helpers/tournament_wizard_helper.rb:159:    wizard_step_status(tournament, step_number) == :active
```

**Notes on output:**

- `app/views/tournaments/_wizard_steps.html.erb` — this is the retirement-candidate partial file itself. It contains internal `render 'wizard_step'` calls (rendering `_wizard_step.html.erb`) and `wizard_step_status` helper calls. The file **exists** but is **not rendered by `show.html.erb`** — it has no external caller in the codebase (see Command 2 below).
- `app/views/tournaments/_wizard_steps_v2.html.erb` — the canonical partial. Its occurrences are all internal (self-referencing helper calls within the partial body and a `render 'wizard_step'` sub-partial call). The single external entry point is `show.html.erb:35`.
- `app/helpers/tournament_wizard_helper.rb` — helper defining `wizard_step_status` used by both partials.
- No matches in `config/` or `test/`.

### Command 2: render calls targeting wizard partials in show.html.erb and _show.html.erb

```
grep -n "render.*wizard" app/views/tournaments/show.html.erb app/views/tournaments/_show.html.erb
```

Output:

```
app/views/tournaments/show.html.erb:35:    <%= render 'wizard_steps_v2', tournament: @tournament %>
```

**Conclusion (UX-01):** `show.html.erb` contains exactly one render call for a wizard partial, on line 35, and it renders `_wizard_steps_v2.html.erb`. The non-canonical partials `_wizard_steps.html.erb` and `_wizard_step.html.erb` are never rendered from `show.html.erb` or `_show.html.erb`. `_wizard_steps_v2.html.erb` is the canonical wizard partial.

---

## Happy-path action audit

The six sections below correspond to the six wizard actions that comprise the happy path. Plan 02 fills in Intent, Observed, and Screenshot for each, and records findings in the table. Plan 03 assigns stable IDs (F-01, F-02, ...) once all findings are gathered.

---

## new

**Intent:** The tournament director creates a brand-new tournament record — filling in the minimum required fields (title, discipline, date, organizer) so the system can assign it an id and advance it to `new_tournament` state, at which point the wizard becomes visible on the show page. Source: `tournaments_controller.rb:428` — `new` builds a blank `Tournament.new` and renders the form; `create` (line 436) saves it and redirects to the show page.
**Observed:** **Not part of the realistic volunteer workflow.** Walkthrough on carambus_bcw (LOCAL context, NBV region) used synced tournament 17403 "NDM Freie Partie Klasse 1-3" — a global record delivered from the central API. Locally-invented tournaments (`id >= 50_000_000`) are the exception, not the norm; a typical club runs regional/national tournaments that arrive pre-populated via sync. The `/tournaments/new` route was intentionally not walked through because it bypasses the sync code paths the volunteer actually hits.
**Screenshot:** _n/a — not observed per Option A (see walkthrough decision log)_

| ID | Type | Finding | Tier | Gate |
|----|------|---------|------|------|
| F-01 | missing-feature | `/tournaments/new` is exposed as a top-level action but is irrelevant for the typical synced-tournament workflow. Could be hidden behind an admin menu, or moved under a "Locally verwaltetes Turnier" sub-flow so volunteers don't encounter it on their main path. | 2 | open |

---

## create

**Intent:** The tournament director submits the new-tournament form to persist the record and land on the show page with the wizard at Step 1 active. Source: `tournaments_controller.rb:436` — `create` builds `Tournament.new(tournament_params)`, optionally attaches a league, saves, and redirects to `@tournament` (the show page) with a "Tournament was successfully created." notice; on failure it redirects back.
**Observed:** **Not part of the realistic volunteer workflow** — see `## new` above. The create action is the companion to `new`; neither is exercised by the synced-tournament happy path. Synced tournaments arrive from the API already persisted; the volunteer never submits a new-tournament form. Not observed.
**Screenshot:** _n/a — not observed per Option A (see walkthrough decision log)_

| ID | Type | Finding | Tier | Gate |
|----|------|---------|------|------|
| F-02 | missing-feature | `create` has no volunteer-facing use case for the Manager Experience milestone. It exists for completeness and for the rare locally-invented tournament. Consider grouping `new`+`create`+direct-edit of identity fields into an "Admin" path separate from the wizard happy path, so the wizard doesn't need to account for "what if this tournament wasn't synced". | 2 | open |

---

## edit

**Intent:** The tournament director corrects or extends the tournament's basic attributes (title, date, location, discipline settings) after it has been created. Source: `tournaments_controller.rb:433` — `edit` is a bare action (no body beyond implicit `@tournament` set by `before_action`); it renders `edit.html.erb`, which re-presents the same form as `new` but pre-populated.

**Scope note:** The walkthrough did not hit `/tournaments/17403/edit` (the controller-level edit action) because the volunteer never touches identity fields on a synced tournament (LocalProtector blocks those writes anyway). Instead, this section documents the "Schritt 1–3" of the wizard — ClubCloud-Meldeliste laden, Setzliste aus Einladung übernehmen, Teilnehmerliste bearbeiten — which is what the volunteer ACTUALLY does when preparing a synced tournament. The name "edit" is kept per UX-04 but its meaning in context is "wizard participant-list preparation".

**Observed:** The wizard overview page (`01-show-initial.png`) cleanly presents "Turnier-Setup: NDM Freie Partie Klasse 1-3" with a progress bar "Schritt 2 von 6" — good orientation. Step 1 "Meldeliste von ClubCloud laden" was marked GELADEN (green checkmark) automatically; the sync pulled only **1 registration** (Simon, Franzel) even though in practice several players had registered. The wizard presents this as "Es sind bereits 1 Spieler vorhanden — Weiter zu Schritt 3 mit diesen 1 Spielern", a green call-to-action that misleads the volunteer into thinking the data is complete. No warning is shown when the ClubCloud registration count is implausibly low for a carom tournament. The volunteer had to manually recover by navigating to the Teilnehmerliste (`02-edit-seeding.png`, `02c-added-players-edit-seeding.png`) and adding 4 more players via the "Spieler mit DBU-Nummer hinzufügen" field (`02b-add-players-edit-seeding.png`), typing comma-separated DBU numbers "121308, 121291, 121341, 121332". The DBU-number input is itself a well-labeled feature ("Mit DBU-Nummer: Spieler eindeutig identifiziert (empfohlen) | Mehrere durch Komma getrennt möglich") but assumes the volunteer has DBU numbers at hand — no name-based search is visible in this view. Once 5 players were added, the Teilnehmerliste page showed a new panel **"Mögliche Turnierpläne für 5 Teilnehmer — automatisch vorgeschlagen: T04"** with "5 Videos Plan anzeigen" — this is the `tournament_plan_id` assignment target the audit was looking for: it happens inline in the Teilnehmerliste step based on participant count. Good auto-suggest feature with clear labeling. The "Setzliste aus Einladung übernehmen" step (`02a-compare_seedings.png`) is framed PDF-first with ClubCloud as "Alternative", which is backwards for a volunteer who uses ClubCloud exclusively. Helpful meta-message throughout: "Alle Änderungen werden sofort gespeichert" (good feedback on auto-save). The Teilnehmerliste header also offers "Nach Ranking sortieren" as a one-click default ordering for German regional tournaments — smart default.
**Screenshot:** screenshots/01-show-initial.png, screenshots/02-edit-seeding.png, screenshots/02a-compare_seedings.png, screenshots/02b-add-players-edit-seeding.png, screenshots/02c-added-players-edit-seeding.png

| ID | Type | Finding | Tier | Gate |
|----|------|---------|------|------|
| F-03 | bug | ClubCloud sync for tournament 17403 pulled only 1 player registration when the expected count was 5+. Root cause not observed in this audit — could be sync timing, permission, or a silent partial-success path. The wizard does not detect or warn about suspiciously low counts. | 2 | open |
| F-04 | ux | The "Weiter zu Schritt 3 mit diesen 1 Spielern" green button misleads volunteers into thinking the sync is complete. A 1-player carom tournament is almost certainly wrong; the button should be de-emphasised and a warning ("Nur 1 Spieler geladen — erwartet mindestens N?") should surface. | 1 | open |
| F-05 | ux | "Setzliste aus Einladung übernehmen" step frames PDF upload as primary and ClubCloud as "Alternative". For clubs using ClubCloud as their canonical registration source this framing is backwards. | 1 | open |
| F-06 | missing-feature | No player search by name in the Teilnehmerliste view — only DBU-number lookup. Volunteers without DBU numbers at hand have no recovery path. Consider fuzzy name search with DBU disambiguation. | 2 | open |
| F-07 | ux | The `tournament_plan_id` auto-suggest panel ("Mögliche Turnierpläne für 5 Teilnehmer — automatisch vorgeschlagen: T04") is excellent — clear recommendation, clear participant count, "Plan anzeigen" affordance. Keep this as the gold standard for wizard feedback elsewhere. | 1 | open |
| F-08 | ux | "Alle Änderungen werden sofort gespeichert" is a great ambient auto-save cue. Good pattern. | 1 | open |

---

## finish_seeding

**Intent:** The tournament director closes the participant list ("Setzliste abschließen"), locking in the draw order and triggering ranking calculation, so the tournament can advance to `tournament_seeding_finished` state and the next wizard step becomes active. Source: `tournaments_controller.rb:107` — `finish_seeding` calls `@tournament.finish_seeding!` (AASM event, transitions to `tournament_seeding_finished`), then calls `calculate_and_cache_rankings` if rankings are blank, and redirects back to the show page; only permitted on `local_server?`.
**Observed:** Before clicking (`03-finish_seeding-before.png`): the wizard overview shows "Schritt 3 von 6" with the 5 added participants visible in step 3 "Teilnehmerliste bearbeiten (am Turniertag)". Step 3 carries a confusing meta-label "Dieser Schritt ist nicht zu erledigen sondern erledigt sich fortlaufend mit Schritt 4" — the volunteer cannot tell whether this step is something to do, or something to skip. Step 4 "Teilnehmerliste finalisieren" exposes the blue "Teilnehmerliste abschließen" button with **no confirmation dialog** — clicking it advances the wizard irreversibly (per controller: AASM `finish_seeding!` transitions the tournament state, which is a one-way operation). After clicking (`04-finish_seeding-after.png`): the wizard jumps from Schritt 3 directly to Schritt 5 ("Turniermodus festlegen"), skipping visible completion of Schritt 4 — step 4 is apparently auto-completed by the backend when the button is pressed. Steps 1–4 are now green/done, and step 5 presents a new button "Modus auswählen". Status line shows "Modus Auswahl · Schritt 5 von 6". Clicking "Modus auswählen" leads to `04a-mode-selection.png`: a full-page "Abschließende Auswahl des Austragungsmodus" with 3 tournament-plan alternatives (T04, T05, DefaultS) as cards, each showing dense technical info like "Turnier wird im Modus jeder gegen jeden durchgeführt. (5 Teilnehmer, zwei Billards, 5 Spielrunden, 1 Turniertag)" vs "(5 Teilnehmer, zwei Billards, 6 Spielrunden, 2 Turniertage)". Each card has a "Weiter mit T04/T05/DefaultS" button. No help text explains the trade-offs, and selection is applied immediately on click — no confirmation, no preview.
**Screenshot:** screenshots/03-finish_seeding-before.png (before), screenshots/04-finish_seeding-after.png (after), screenshots/04a-mode-selection.png (final mode selection sub-page)

| ID | Type | Finding | Tier | Gate |
|----|------|---------|------|------|
| F-09 | ux | "Teilnehmerliste abschließen" button has no confirmation dialog before triggering an irreversible AASM transition. A volunteer doing this 2–3x/year may click by mistake. Add an `onclick="return confirm(...)"` or a modal listing the consequences. | 1 | open |
| F-10 | ux | Step 3 label "Dieser Schritt ist nicht zu erledigen sondern erledigt sich fortlaufend mit Schritt 4" is confusing — the volunteer cannot tell whether step 3 is actionable or passive. Either collapse step 3 into step 4 in the UI, or rewrite the label to state plainly "Schritt 3 läuft automatisch — siehe Schritt 4 für den Abschluss". | 1 | open |
| F-11 | ux | After clicking "Teilnehmerliste abschließen", the wizard progress skips from Schritt 3 to Schritt 5 without visibly "doing" step 4. This is likely correct behavior (step 4 is atomic with step 3's button), but the jump is disorienting. Consider showing a brief "Schritt 4 erledigt ✓" confirmation before advancing. | 1 | open |
| F-12 | ux | The "Abschließende Auswahl des Austragungsmodus" page (`04a-mode-selection.png`) presents 3 tournament plans as alternatives with dense technical specs but no explanation of trade-offs. For a volunteer making ~3 tournaments a year, the choice between T04/T05/DefaultS is effectively blind. Add a "Warum T04?" tooltip or a recommended-default highlight. | 1 | open |
| F-13 | missing-feature | Tournament plan is applied immediately on button click in the mode-selection page — no confirmation, no "zurück" safety net beyond browser back. A mistake-recovery path (even just "Modus ändern" on the wizard overview) would help. | 1 | open |

---

## start

**Intent:** The tournament director fills in the play parameters (table assignment, innings/balls goals, timeouts, sets, ClubCloud upload preference) and officially starts the tournament, which initialises the TournamentMonitor, fires the `start_tournament!` AASM event (→ `tournament_started_waiting_for_monitors`), and sets up all TableMonitors with the chosen parameters. Source: `tournaments_controller.rb:288` — saves play-param data to `@tournament.data`, calls `initialize_tournament_monitor`, fires `start_tournament!`, updates every TableMonitor, broadcasts teaser frames, then redirects to `tournament_monitor_path` if in `tournament_started_waiting_for_monitors` state, otherwise redirects back to the tournament show page.
**Observed:** The start form (`05-start-form.png`) opens after the mode selection. Top of page shows the chosen mode summary: "Turnier wird im Modus jeder gegen jeden durchgeführt. (5 Teilnehmer, zwei Billards, 5 Spielrunden, 1 Turniertag)". Below that, a "Zuordnung der Tische" section maps Tisch 1 and Tisch 2 to dev-DB placeholder tables ("Tisch 2 Meine Tisch - Vereinsheim BG Hamburg"). Below the table assignment is a dense "Turnier Parameter" form with ~15 fields — and **the vast majority of the labels are in English**, not German, contradicting the v7.0 volunteer-friendly goal. Observed labels include: "Bälle vor" (German, OK), "Aufnahmebegrenzung" (German, OK), "Timeout (sek)", "Timeouts" (German), followed by a long run of English/garbled-German labels: "Tournament manager checks results before acceptance", "Assign games as tables become available", "Gd hat prio ein inter-group comparisons", "Warmup game as tables available", "Warmup same table once", "Der arbeit wechselt zwischen den sätzen" (mangled German), "Bälle einsam nach dritt" (mangled), "Die farblau bleibt gesetzt beim satz" (mangled), "Kein weiteres anstellen des tables waterbefund" (mangled), "Darstellung binauwang" (mangled), "Sätze zum sieg" (OK), "Geschriftsatze" (mangled/unclear). The page has **no grouping or help text** explaining what these parameters mean. There are **no default values** pre-filled for "Bälle vor" and "Aufnahmebegrenzung" — the volunteer must know Freie-Partie rules to configure correctly. Submit button at bottom: "Starte den Turnier Monitor" (German, OK). A "Back to Mode Selection" link appears bottom-left (English, inconsistent).
**Screenshot:** screenshots/05-start-form.png

| ID | Type | Finding | Tier | Gate |
|----|------|---------|------|------|
| F-14 | bug | Severe i18n regression on the start form: the majority of parameter labels are in English or garbled German-English mix. Examples: "Tournament manager checks results before acceptance", "Gd hat prio ein inter-group comparisons", "Der arbeit wechselt zwischen den sätzen", "Bälle einsam nach dritt", "Die farblau bleibt gesetzt beim satz", "Kein weiteres anstellen des tables waterbefund", "Darstellung binauwang". A volunteer at a German carom club cannot realistically configure these. Root cause likely: missing or broken entries in `config/locales/de.yml` for tournament start-form keys. | 1 | open |
| F-15 | ux | "Back to Mode Selection" link (bottom-left of the start form) is in English while the surrounding UI is nominally German. Translate. | 1 | open |
| F-16 | ux | The Turnier-Parameter form lists ~15 fields with no grouping, no help text, and no visible required/optional indicators. For a volunteer making ~3 tournaments a year this is cognitively overwhelming. Group into sections (Spielziele / Timing / Tischwechsel / Darstellung) and collapse advanced parameters behind "Erweiterte Einstellungen". | 1 | open |
| F-17 | missing-feature | No discipline-aware defaults for `Bälle vor` and `Aufnahmebegrenzung`. For a Freie-Partie-klein tournament these values are near-constants in practice; the system could propose sensible defaults (e.g. from the last tournament of the same discipline in the same region) and let the volunteer override. | 2 | open |
| F-18 | ux | "Zuordnung der Tische" section lists dev-DB placeholder names ("Tisch 2 Meine Tisch - Vereinsheim BG Hamburg") — cosmetic, not a production concern, but worth noting that the table dropdown uses raw DB names without formatting. | 1 | open |

---

## tournament_started_waiting_for_monitors

**Intent:** After `start_tournament!` fires, the system is in a transient state waiting for table monitor connections to signal readiness before the tournament is fully live. The controller check at line 415 (`@tournament.tournament_started_waiting_for_monitors?`) determines whether the volunteer is redirected to `tournament_monitor_path` (to oversee monitor setup) rather than back to the tournament show page. Source: `tournament.rb:276–295` — `tournament_started_waiting_for_monitors` is an explicit AASM state entered by `start_tournament!` and exited only by `signal_tournament_monitors_ready` (→ `tournament_started`). The controller at line 415 redirects to `tournament_monitor_path` when this state is active immediately after `#start`.

**Observed (UX-02 — THE LOAD-BEARING FINDING OF PHASE 33):** **No visible UI surfaces during `tournament_started_waiting_for_monitors`.** After clicking "Starte den Turnier Monitor" on the start form, the browser shows the previous page unchanged for **a few seconds** (user-reported — not an instant transition, but no loading indicator, no spinner, no "Turnier wird gestartet..." message, no state-specific intermediate screen), and then the Tournament Monitor landing page (`06-start-transient-state.png` / `07-start-after.png`) appears directly. The volunteer sees nothing happen for those few seconds and could easily double-click the start button or back-button out, both of which are risky during an AASM transition. The attempted screenshot `06-start-transient-state.png` is actually the Tournament Monitor landing page — there was no transient UI to capture because none exists. This directly answers Phase 33 success criterion #2: the transient state **passes invisibly from the volunteer's perspective**.

The post-transition Tournament Monitor landing (`06-start-transient-state.png` / `07-start-after.png`, which are the same screen) shows "Turnier-Monitor · NDM Freie Partie Klasse 1-3", "Turnierphase: playing group" (note: English "playing group", not German), two table cards (Tisch 4-6 and Tisch 1) each showing "warmup · SpielGruppe A · Partie 1-5" with 2 player names (e.g. "Simon, Franzel / Smrcka, Martin" and "Jüde, Philipp / Unger, Dr. Jörg"), an orange/red "edit on" badge next to one player name (meaning unclear without source context), a "Gruppen" section listing all 5 players, and an "Aktuelle Spiele Runde 1" table with 4 match rows, each with Tisch/Gruppe/Partie/Spieler/Bälle/von/Aufnahme/HS/GD/"Aktuelle Aufnahme"/"Bälle Eingeben" columns and a "Spielbeginn" button per row. No explicit "Turnier wurde gestartet" success flash is visible on the landing page.
**Screenshot:** screenshots/06-start-transient-state.png, screenshots/07-start-after.png (identical content — the transient state was invisible, these are the post-transition Tournament Monitor)

| ID | Type | Finding | Tier | Gate |
|----|------|---------|------|------|
| F-19 | bug | `tournament_started_waiting_for_monitors` passes invisibly for several seconds with no UI feedback. The volunteer cannot tell whether the click registered, whether the system is working, or whether they need to retry. This risks double-clicks, page back-navigation, or frustrated page-reloads during a live AASM transition — any of which may leave the tournament in a partially-started state. **This IS the UX-02 answer**: the transient state should either (a) be made visible with a progress/waiting screen, or (b) be eliminated structurally by not advancing the state until monitors are connected. Fixing this requires AASM surface changes. | 3 | blocked-needs-test-plan |
| F-20 | ux | After the transition, the Tournament Monitor landing page shows no explicit success confirmation ("Turnier wurde gestartet ✓"). Absence-of-feedback at a critical state transition for a low-frequency workflow. Add a flash notice or a one-time banner. | 2 | open |
| F-21 | ux | "Turnierphase: playing group" on the Tournament Monitor landing is English. Should be "Turnierphase: Gruppenspiel läuft" or similar German. | 1 | open |
| F-22 | ux | Orange/red "edit on" badge appears next to one player's name on each table card on the Tournament Monitor landing. Meaning is not self-evident from the UI — could be "Spieleingabe aktiv", "Spieler ist am Zug", or a debug badge. Needs clear label or a tooltip. | 1 | open |
| F-23 | missing-feature | The `start` controller action does not appear to surface progress for the TableMonitor setup phase. For a volunteer running a multi-table tournament, knowing "2 of 2 monitors connected, waiting..." would be valuable — today the transient state is opaque. | 2 | open |

---

## retirement

**Intent:** Document the retirement decision for non-canonical wizard partials so Phase 36 has an explicit Tier 1 task. No files are deleted in Phase 33 (D-09). The grep evidence proving these partials are unused is in §Canonical wizard partial — grep evidence (UX-01) above.

| ID | Type | Finding | Tier | Gate |
|----|------|---------|------|------|
| F-24 | ux | Retire non-canonical wizard partials `app/views/tournaments/_wizard_steps.html.erb` and `app/views/tournaments/_wizard_step.html.erb` — canonical is `_wizard_steps_v2.html.erb` per grep evidence in §Canonical wizard partial — grep evidence above. Neither partial is rendered by `show.html.erb` or `_show.html.erb` (Command 2 output shows only one render call: `show.html.erb:35` → `wizard_steps_v2`). Deletion executed in Phase 36. | 1 | open |

---

## Non-happy-path actions (not reviewed)

These actions were deliberately not reviewed in Phase 33. Any UX review of these is out of scope for v7.0 per ROADMAP.md.

- `index`
- `show`
- `edit_games`
- `reset`
- `test_tournament_status_update`
- `order_by_ranking_or_handicap`
- `reload_from_cc`
- `finalize_modus`
- `select_modus`
- `tournament_monitor`
- `placement`
- `update`
- `destroy`
- `define_participants`
- `new_team`
- `add_team`
- `compare_seedings`
- `upload_invitation`
- `parse_invitation`
- `recalculate_groups`
- `add_player_by_dbu`
- `apply_seeding_order`
- `use_clubcloud_as_participants`
- `update_seeding_position`

---

## Tier classification key

Tier classification rules per D-11 and D-12. Every finding in the tables above must be classified by the **highest layer touched** by the change needed to fix it. No judgment — mechanical classification:

**Tier 1** = view / copy / new partial / i18n key / help text only. The fix lives entirely in ERB templates, locale YAML files, or static copy. No controller, route, service, or AASM change required.

**Tier 2** = any controller change, route change, or service object change. The fix requires modifying `tournaments_controller.rb`, `config/routes.rb`, or a service class (even if a view also changes). Tier 2 takes precedence over Tier 1 if both layers are touched.

**Tier 3** = any AASM state machine change. This means a modification to the `aasm` block in `tournament.rb` — adding, removing, or renaming states or events. Tier 3 takes precedence over Tier 2 and Tier 1.

**Ambiguous cases** resolve to the **higher tier**, not the lower one.

**Gating rule (D-12):** Every Tier 3 row has `Gate: blocked-needs-test-plan` instead of `Gate: open`. Phase 36 may only unblock a Tier 3 item by attaching an explicit test-coverage plan in its own `PLAN.md` and referencing the finding ID. This rule exists because AASM state machine changes carry the highest regression risk — the tournament lifecycle is central to the entire application and has no system-level test coverage today.

**Finding type values:** `ux | bug | missing-feature`

**Gate values:** `open` (default) | `blocked-needs-test-plan` (Tier 3 only)
