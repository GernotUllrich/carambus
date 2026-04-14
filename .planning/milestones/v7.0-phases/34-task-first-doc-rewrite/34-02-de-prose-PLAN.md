---
phase: 34-task-first-doc-rewrite
plan: 02
type: execute
wave: 2
depends_on:
  - 34-01
files_modified:
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.de.md
autonomous: true
requirements:
  - DOC-01
  - DOC-03
  - DOC-04
  - DOC-05
must_haves:
  truths:
    - "A DE volunteer opening tournament-management.de.md sees a task-first walkthrough opening, not architecture (DOC-01)"
    - "All 14 walkthrough steps from D-04 are present as H3 sections with concrete click-level prose"
    - "The 4 mandated admonition callouts (F-09, F-12, F-14, F-19) are present with their exact wording from D-02, each with a trailing '<!-- ref: F-NN -->' HTML comment"
    - "The glossary contains the 5 mandated terms (ClubCloud, Setzliste, Turniermodus, AASM-Status, Scoreboard) plus Karambol terms grouped by category (DOC-03)"
    - "The troubleshooting section contains the 4 mandated cases in D-07 order with Problem/Ursache/Lösung subsections (DOC-04)"
    - "The 2-paragraph 'Mehr zur Technik' tail-block is present at the END of the file with link to docs/developers/ (D-01)"
    - "index.de.md Quick Start leads with 'Turnier aus ClubCloud synchronisieren' and condenses the 14-step walkthrough into 10 linked teaser steps (DOC-05)"
  artifacts:
    - path: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md
      provides: "Task-first DE walkthrough with glossary, troubleshooting, architecture tail, admonition callouts"
      min_lines: 300
      contains: "NDM Freie Partie Klasse 1"
      contains_extra:
        - "<!-- ref: F-09 -->"
        - "<!-- ref: F-12 -->"
        - "<!-- ref: F-14 -->"
        - "<!-- ref: F-19 -->"
        - "!!! warning"
        - "!!! tip"
        - "Freie Partie"
        - "Dreiband"
        - "Höchstserie"
        - "ClubCloud"
        - "Setzliste"
        - "Mehr zur Technik"
    - path: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.de.md
      provides: "Rewritten DE Quick Start (10 condensed teaser steps linking into walkthrough anchors)"
      contains: "Turnier aus ClubCloud synchronisieren"
  key_links:
    - from: walkthrough admonition callouts
      to: 33-UX-FINDINGS.md F-09 / F-12 / F-14 / F-19
      via: "<!-- ref: F-NN --> trailing HTML comments (D-02a)"
      pattern: "<!-- ref: F-[0-9]+ -->"
    - from: index.de.md Quick Start teaser steps
      to: tournament-management.de.md walkthrough anchors
      via: markdown links with #step-N-slug fragments
      pattern: "tournament-management\\.md#step-"
    - from: Mehr zur Technik tail block
      to: docs/developers/
      via: relative markdown link
      pattern: "\\[.*\\]\\(\\.\\./developers/"
---

<objective>
Write the full DE prose for the Phase 34 task-first rewrite: walkthrough (14 steps), glossary (15+ terms grouped), troubleshooting (4 cases Problem/Ursache/Lösung), architecture tail block, and the index.de.md 10-step teaser Quick Start.

Purpose: Deliver the DE volunteer-facing walkthrough that matches the canonical wizard behavior observed in Phase 33. This is the prose realization of 33-UX-FINDINGS.md, embedded in a generic NBV NDM Freie Partie Klasse 1-3 scenario framing (D-04a).

Output: Two updated DE files in carambus_master (tournament-management.de.md full prose, index.de.md Quick Start teaser) committed as one coherent DE-content commit.
</objective>

<execution_context>
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/workflows/execute-plan.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/templates/summary.md

## Cross-checkout constraint (MANDATORY — scenario-management skill)

All edits in this plan happen in `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/`. The commit is made from carambus_master. GSD SUMMARY.md lands in carambus_api via the normal planning commit workflow. Do NOT edit `carambus_api/docs/managers/*.md`.

## Gate check before starting

This plan depends on 34-01. Before writing any prose, verify the skeleton commit exists and the skeleton anchors are in place:

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
git log --oneline -20 | grep '34-01' || { echo "FAIL: skeleton commit 34-01 missing — plan 34-02 must not run"; exit 1; }
grep -c '^## ' docs/managers/tournament-management.de.md  # should be ≥ 6
grep -q 'id="walkthrough"' docs/managers/tournament-management.de.md || { echo "FAIL: skeleton anchors missing"; exit 1; }
```

If the gate check fails, STOP and return the error to the orchestrator. Do not attempt to write prose before the skeleton is committed.
</execution_context>

<context>
@.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md
@.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md
@.planning/phases/33-ux-review-wizard-audit/33-CONTEXT.md
@.agents/skills/scenario-management/SKILL.md

# Target files (skeleton from 34-01 is in place)
@docs/managers/tournament-management.de.md
@docs/managers/index.de.md

# Sibling docs — for tone, admonition style, ClubCloud linking patterns
@docs/managers/clubcloud-integration.de.md
@docs/managers/single-tournament.de.md
</context>

<interfaces>
<!-- Mandatory callout texts (D-02 — exact wording locked) -->

## Mandatory admonition callouts

These four admonitions MUST appear in the walkthrough at the steps noted below. Each admonition is immediately followed by a trailing HTML comment `<!-- ref: F-NN -->` on its own line so Phase 36 can grep and remove them atomically (D-02a).

### At Step 5 (Teilnehmerliste abschließen — finish_seeding)

```markdown
!!! warning "Teilnehmerliste abschließen ist endgültig"
    Der Klick auf **Teilnehmerliste abschließen** ist einmalig und nicht
    rückgängig zu machen. Prüfen Sie vorher die Teilnehmerliste sorgfältig —
    nach dem Abschließen springt der Wizard direkt zur Modus-Auswahl, und
    eine spätere Änderung der Teilnehmerliste ist nur noch über Admin-Eingriff
    möglich.
<!-- ref: F-09 -->
```

### At Step 6 (Turniermodus auswählen)

```markdown
!!! tip "Welchen Turnierplan wählen?"
    Bei der Modus-Auswahl schlägt Carambus meist einen Plan automatisch vor
    (zum Beispiel **T04** bei 5 Teilnehmern). Übernehmen Sie den Vorschlag,
    wenn Sie nicht bewusst eine Alternative bevorzugen. Die Alternativen
    unterscheiden sich vor allem in der Zahl der Spielrunden und Turniertage
    — für eine typische NDM Freie Partie Klasse 1–3 ist der Vorschlag fast
    immer der richtige.
<!-- ref: F-12 -->
```

### At Step 7 (Start-Parameter ausfüllen)

```markdown
!!! tip "Englische Feldbezeichnungen im Start-Formular"
    Einige Parameter im Start-Formular heißen derzeit auf Englisch oder sind
    unklar beschriftet (zum Beispiel *Tournament manager checks results before
    acceptance* oder *Assign games as tables become available*). Das
    [Glossar](#glossary) unten erklärt die wichtigsten Begriffe. Im Zweifel
    übernehmen Sie die Standardwerte und kontrollieren Sie die Einstellungen
    nach dem Turnier.
<!-- ref: F-14 -->
```

### At Step 9 (Turnier starten)

```markdown
!!! warning "Warten, nicht erneut klicken"
    Nach dem Klick auf **Starte den Turnier Monitor** sieht die Seite mehrere
    Sekunden lang unverändert aus. Das ist normal — der Wizard bereitet im
    Hintergrund die Tisch-Monitore vor. **Klicken Sie den Button nicht erneut**
    und navigieren Sie nicht zurück. Nach wenigen Sekunden öffnet sich der
    Turnier-Monitor automatisch.
<!-- ref: F-19 -->
```

## Mandatory glossary terms (D-03 — grouped by category)

### Karambol-Begriffe
- Freie Partie
- Cadre (35/2, 47/1, 47/2, 71/2)
- Dreiband
- Einband
- Aufnahme
- Bälle-Ziel (innings_goal)
- Höchstserie (HS)
- Generaldurchschnitt (GD)
- Spielrunde
- Tisch-Warmup

### Wizard-Begriffe
- Setzliste
- Turniermodus / Austragungsmodus
- Turnierplan-Kürzel (T04, T05, Default5)
- Scoreboard

### System-Begriffe
- ClubCloud
- AASM-Status
- DBU-Nummer
- Rangliste

Each entry is 1–2 sentences in volunteer-friendly language and — where relevant — notes which wizard step the term appears on (e.g. "Sie sehen diesen Begriff in Schritt 6"). D-03a.

## Mandatory troubleshooting cases (D-07 — order locked)

Each case uses three bold labels: **Problem:** / **Ursache:** / **Lösung:**. Order:

1. Einladungs-PDF konnte nicht hochgeladen werden
2. Spieler ist nicht in der ClubCloud-Meldeliste (ground cause in F-03/F-04)
3. Falscher Turniermodus ausgewählt (ground cause in F-12/F-13)
4. Turnier wurde bereits gestartet (ground cause in F-19, explicitly mention that undo is NOT available and currently requires admin intervention)

## Scenario framing (D-04a)

Opening sentence of the `## Szenario` section, exact wording target:

> Sie haben als Turnierleiter Ihres Vereins vom NBV eine Einladung zur **NDM
> Freie Partie Klasse 1–3** erhalten. Das Turnier läuft an einem Samstag in
> Ihrem Spiellokal mit 5 gemeldeten Teilnehmern auf zwei Tischen. Diese
> Seite begleitet Sie Schritt für Schritt vom Eingang der Einladung bis zum
> Ergebnis-Upload zurück in die ClubCloud.

No concrete tournament ID (17403), no concrete date — generic only (D-04a).

## Tail architecture block (D-01)

Exactly 2 paragraphs under `## Mehr zur Technik` at the END of the file (after Troubleshooting). Target content:

Paragraph 1: Carambus is a hierarchy of web services — a central API server publishes tournaments, regional/local Carambus servers pull synced data, and scoreboards drive match recording in real time. Global records (synced from the API) are read-only for identity fields; your local server handles wizard state transitions and match recording.

Paragraph 2: Link to `../developers/index.md` for the full architecture documentation. Mention that day-to-day tournament management does not require understanding the architecture — if you followed the walkthrough above, you already know everything you need.

Keep it under 200 words total. No deep dive. This is the "curious volunteer" safety net, not the developer manual.
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Write full DE walkthrough prose with callouts (Steps 1–14)</name>
  <files>/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md</files>
  <read_first>
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md (D-01, D-02, D-04, D-04a — scenario framing; D-02a — ref comment convention)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md (full findings F-01 to F-24 — the walkthrough is the prose version of this; in particular F-03..F-08 for steps 2–4, F-09..F-13 for steps 5–6, F-14..F-18 for steps 7–8, F-19..F-23 for steps 9–12)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md (skeleton from 34-01 — preserves H2/H3/anchor structure)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/clubcloud-integration.de.md (for tone, ClubCloud linking patterns, existing admonition style)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/single-tournament.de.md (overlap check — do not duplicate; cross-link where relevant)
  </read_first>
  <action>
    Fill in the DE walkthrough prose in `tournament-management.de.md`. The skeleton H2/H3/anchor structure from plan 34-01 is already in place — KEEP ALL ANCHOR TAGS (`<a id="...">`) and H2/H3 header text unchanged. Only replace the `_(Inhalt folgt in Plan 34-02)_` placeholder bodies with real prose.

    **Tone:** formal "Sie" throughout. 2–3x/year volunteer audience — plain language, no jargon without explanation, cross-reference glossary entries via `[Begriff](#glossary-karambol)` style anchors where Karambol terms appear.

    **Scenario section (## Szenario):** Use the exact scenario framing text from the `<interfaces>` block. One paragraph, no more. Mention the 5 participants / 2 tables context that drives the T04 mode suggestion at Step 6.

    **Walkthrough steps (## Durchführung Schritt für Schritt):** 14 H3 sections, each following this structure:

    1. Opening sentence: what the volunteer is doing in this step, from their perspective (not from the code's perspective)
    2. What to click / what to look at on screen (concrete — "Sie klicken oben rechts auf X" not "die Aktion wird ausgelöst")
    3. What to expect to see happen (matched to Phase 33 observed behavior — do not describe aspirational behavior)
    4. Gotchas or edge cases grounded in findings, with cross-references to the troubleshooting section where applicable
    5. If the step has a mandatory admonition (Step 5 = F-09, Step 6 = F-12, Step 7 = F-14, Step 9 = F-19), insert the admonition block with the EXACT wording from the `<interfaces>` section of this plan, immediately followed by the trailing `<!-- ref: F-NN -->` HTML comment on its own line.

    **Step-by-step content targets (rough length: 80–150 words per step, except Step 1 which is ~40 words — it is a scenario-entry, no click):**

    - **Step 1 — Die NBV-Einladung erhalten:** The volunteer receives an email from the Landessportwart with the PDF invitation. No click action yet; frame the scene.
    - **Step 2 — Turnier aus ClubCloud laden (Wizard Schritt 1):** Open the tournament's show page; Step 1 "Meldeliste von ClubCloud laden" is normally auto-completed (GELADEN checkmark). Mention the F-03/F-04 risk (ClubCloud may deliver fewer players than expected) and cross-link to troubleshooting case #2. Keep the prose accurate to the wizard — do NOT pretend the sync always works.
    - **Step 3 — Setzliste übernehmen (Wizard Schritt 2):** Two options: upload the invitation PDF or use ClubCloud as source (F-05: framing is currently PDF-first, mention this honestly). One paragraph describing the compare-seedings view from Phase 33 screenshot `02a-compare_seedings.png`.
    - **Step 4 — Teilnehmerliste ergänzen (Wizard Schritt 3):** Use the DBU-Nummer field (comma-separated) to add missing players. Mention the "Nach Ranking sortieren" default ordering convenience (F-08). Note that the auto-suggest panel for tournament plans appears inline once participant count reaches a matching plan (F-07 — the gold standard).
    - **Step 5 — Teilnehmerliste abschließen (Wizard Schritt 4):** The "Teilnehmerliste abschließen" button finalizes the draw. **Insert F-09 warning admonition here with trailing `<!-- ref: F-09 -->`.** Explain the jump from Schritt 3 → Schritt 5 after clicking (F-11 — disorienting but correct).
    - **Step 6 — Turniermodus auswählen:** Describe the mode-selection page with 3 alternative cards (T04, T05, DefaultN). **Insert F-12 tip admonition here with trailing `<!-- ref: F-12 -->`.** Mention that selection is applied immediately on click, no back-out (F-13) — point to troubleshooting case #3.
    - **Step 7 — Start-Parameter ausfüllen:** The start form. **Insert F-14 tip admonition here with trailing `<!-- ref: F-14 -->`.** Acknowledge the English/garbled labels honestly. Point volunteers to the glossary for the critical terms they need to recognize (Bälle-Ziel / innings_goal, Aufnahme, Aufnahmebegrenzung, HS, GD).
    - **Step 8 — Tische zuordnen:** The "Zuordnung der Tische" section. Straightforward — pick the 2 tables from the dropdown. Brief.
    - **Step 9 — Turnier starten:** Click "Starte den Turnier Monitor". **Insert F-19 warning admonition here with trailing `<!-- ref: F-19 -->`.** This is the load-bearing callout of the whole phase.
    - **Step 10 — Warmup-Phase beobachten:** Once the Tournament Monitor landing page loads, tables show status `warmup` with player pairs assigned to Partie 1. Describe the page from Phase 33 screenshot `07-start-after.png`.
    - **Step 11 — Spielbeginn freigeben:** For each match in the "Aktuelle Spiele Runde 1" row, click "Spielbeginn". This transitions the match from warmup to active play. The scoreboards take over ball entry once Spielbeginn is pressed.
    - **Step 12 — Ergebnisse verfolgen:** The Tournament Monitor updates live via ActionCable. Describe what the volunteer should watch for: completed matches, Runde N → Runde N+1 transitions, the Gruppen section refreshing. Mention that the volunteer typically does nothing here — the players drive the scoreboards.
    - **Step 13 — Turnier finalisieren:** After the last round, the Tournament Monitor surfaces a finalize action. Note honestly that the exact finalize button is in the current wizard UI and may vary — point to single-tournament.de.md for the placement protocol details if the volunteer needs to edit placements.
    - **Step 14 — Ergebnis-Upload nach ClubCloud:** If `auto_upload_to_cc` is enabled, results push back to ClubCloud automatically at tournament finalize. Mention this is configured on the start form and that the default is usually correct.

    **Mehr zur Technik tail (## Mehr zur Technik):** Write the 2-paragraph content per the `<interfaces>` block. Link to `../developers/index.md`. Keep under 200 words.

    **Do NOT modify** the Glossary or Troubleshooting H2 sections in this task — those are Task 2 and Task 3. Preserve the placeholder bodies there, then Task 2/3 will fill them in.

    Use the Edit tool for targeted replacements of placeholder strings (one per H2/H3 block), OR use Read → Write for a single full-file rewrite if that is cleaner given the volume. Full rewrite is acceptable here as long as the anchor tags and H2/H3 headers are preserved verbatim.
  </action>
  <verify>
    <automated>
      cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master && \
      wc -l docs/managers/tournament-management.de.md | awk '{if ($1 < 200) exit 1; else exit 0}' && \
      grep -q '<!-- ref: F-09 -->' docs/managers/tournament-management.de.md && \
      grep -q '<!-- ref: F-12 -->' docs/managers/tournament-management.de.md && \
      grep -q '<!-- ref: F-14 -->' docs/managers/tournament-management.de.md && \
      grep -q '<!-- ref: F-19 -->' docs/managers/tournament-management.de.md && \
      grep -c '!!! warning' docs/managers/tournament-management.de.md | awk '$1>=2{exit 0} {exit 1}' && \
      grep -c '!!! tip' docs/managers/tournament-management.de.md | awk '$1>=2{exit 0} {exit 1}' && \
      grep -q 'NDM Freie Partie Klasse 1' docs/managers/tournament-management.de.md && \
      grep -c 'id="step-' docs/managers/tournament-management.de.md | awk '$1>=14{exit 0} {exit 1}' && \
      grep -q '## Mehr zur Technik\|id="architecture"' docs/managers/tournament-management.de.md && \
      grep -q 'developers' docs/managers/tournament-management.de.md && \
      ! head -20 docs/managers/tournament-management.de.md | grep -qiE '(Einführung|Struktur|Carambus API)'
    </automated>
  </verify>
  <acceptance_criteria>
    - File length ≥ 200 lines (14 steps of prose + callouts + intro + tail block)
    - All 4 `<!-- ref: F-NN -->` comments present (F-09, F-12, F-14, F-19)
    - At least 2 `!!! warning` and at least 2 `!!! tip` admonitions present
    - Scenario sentence contains "NDM Freie Partie Klasse 1" (matches D-04a scenario framing)
    - All 14 `id="step-..."` anchors still present (preserved from skeleton)
    - Tail architecture block exists and links to `../developers/`
    - First 20 lines contain NO architecture keywords (Einführung/Struktur/Carambus API)
    - Glossary and Troubleshooting H2 bodies still contain placeholders (they are Task 2/3)
  </acceptance_criteria>
  <done>
    DE walkthrough is complete with 14-step prose, 4 mandatory admonition callouts with ref comments, scenario framing, and the tail architecture block. First-20-line task-first rule holds. Glossary and Troubleshooting are still placeholders (filled in next tasks).
  </done>
</task>

<task type="auto">
  <name>Task 2: Write DE glossary entries (Karambol / Wizard / System)</name>
  <files>/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md</files>
  <read_first>
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md (D-03, D-03a)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md (post-Task-1 state with walkthrough prose)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md (for verifying where each term appears in the wizard UI)
  </read_first>
  <action>
    Fill in the `## Glossar` section with three H3 subsections: `### Karambol-Begriffe`, `### Wizard-Begriffe`, `### System-Begriffe`. Use the term list from the `<interfaces>` block (mandatory 5 + Karambol terms, D-03).

    **Format per entry** (D-03a — 1–2 sentences, volunteer-friendly, wizard cross-reference where relevant):

    ```markdown
    - **Freie Partie** — Die einfachste Karambol-Disziplin: Ein Punkt pro korrektem Karambolage, keine Feldbeschränkung. Typische Bälle-Ziele liegen bei 50–150 Bällen je nach Klasse. *Sie sehen diesen Begriff im [Start-Formular, Schritt 7](#step-7-start-form).*
    ```

    Write entries for every mandated term. Keep each entry to 1–2 sentences plus the optional wizard cross-reference. Use `[anchor](#step-N-slug)` links to cross-reference walkthrough steps.

    **Karambol-Begriffe target entries (all required):**
    - Freie Partie
    - Cadre (35/2, 47/1, 47/2, 71/2) — brief note on balkline geometry
    - Dreiband
    - Einband
    - Aufnahme
    - Bälle-Ziel (innings_goal) — clarify the `innings_goal` name appears in English in the code/start-form (tie to F-14 callout)
    - Höchstserie (HS)
    - Generaldurchschnitt (GD)
    - Spielrunde
    - Tisch-Warmup

    **Wizard-Begriffe target entries:**
    - Setzliste — the ordered participant list; mention Step 3 and Step 5 cross-references
    - Turniermodus / Austragungsmodus — cross-reference Step 6
    - Turnierplan-Kürzel (T04, T05, Default5) — explain the naming convention (T = Turnierplan, number = code)
    - Scoreboard — the touch-enabled ball-entry device at each table

    **System-Begriffe target entries:**
    - ClubCloud — the regional registration platform; source of truth for participant lists
    - AASM-Status — the tournament's internal state (new_tournament, tournament_seeding_finished, tournament_started, etc.); note that this is what the wizard step indicators reflect, and that Phase 36 makes this badge more prominent
    - DBU-Nummer — the player's national ID; used in Step 4 to add players not in ClubCloud
    - Rangliste — the regional ranking used as default ordering in Step 4 ("Nach Ranking sortieren")

    **Do NOT modify** the Walkthrough prose from Task 1 or the Troubleshooting placeholders. Only the Glossar section is touched here.
  </action>
  <verify>
    <automated>
      cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master && \
      grep -q 'Freie Partie' docs/managers/tournament-management.de.md && \
      grep -q 'Cadre' docs/managers/tournament-management.de.md && \
      grep -q 'Dreiband' docs/managers/tournament-management.de.md && \
      grep -q 'Einband' docs/managers/tournament-management.de.md && \
      grep -q 'Aufnahme' docs/managers/tournament-management.de.md && \
      grep -q 'Bälle-Ziel' docs/managers/tournament-management.de.md && \
      grep -q 'Höchstserie' docs/managers/tournament-management.de.md && \
      grep -q 'Generaldurchschnitt' docs/managers/tournament-management.de.md && \
      grep -q 'Spielrunde' docs/managers/tournament-management.de.md && \
      grep -q 'Tisch-Warmup' docs/managers/tournament-management.de.md && \
      grep -q 'Setzliste' docs/managers/tournament-management.de.md && \
      grep -q 'Turniermodus' docs/managers/tournament-management.de.md && \
      grep -q 'Scoreboard' docs/managers/tournament-management.de.md && \
      grep -q 'ClubCloud' docs/managers/tournament-management.de.md && \
      grep -q 'AASM' docs/managers/tournament-management.de.md && \
      grep -q 'DBU-Nummer' docs/managers/tournament-management.de.md && \
      grep -q 'id="glossary-karambol"' docs/managers/tournament-management.de.md && \
      grep -q 'id="glossary-wizard"' docs/managers/tournament-management.de.md && \
      grep -q 'id="glossary-system"' docs/managers/tournament-management.de.md && \
      ! grep -q '_(Definition folgt)_' docs/managers/tournament-management.de.md
    </automated>
  </verify>
  <acceptance_criteria>
    - All 5 mandated terms present: ClubCloud, Setzliste, Turniermodus, AASM (status), Scoreboard
    - All 10 Karambol terms present: Freie Partie, Cadre, Dreiband, Einband, Aufnahme, Bälle-Ziel, Höchstserie, Generaldurchschnitt, Spielrunde, Tisch-Warmup
    - Three glossary anchor IDs preserved (glossary-karambol, glossary-wizard, glossary-system)
    - No `_(Definition folgt)_` placeholders remain in the glossary
    - At least one glossary entry cross-references a walkthrough step via `#step-N-...` link
  </acceptance_criteria>
  <done>
    DE glossary is complete with all mandated terms plus the Karambol vocabulary, grouped by category, each entry 1–2 sentences, with wizard-step cross-references where applicable.
  </done>
</task>

<task type="auto">
  <name>Task 3: Write DE troubleshooting section (4 cases Problem/Ursache/Lösung) + commit</name>
  <files>
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md,
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.de.md
  </files>
  <read_first>
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md (D-07, D-07a, D-06)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md (F-03/F-04 for case 2, F-12/F-13 for case 3, F-19 for case 4)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md (post-Task-2 state with walkthrough + glossary)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.de.md (skeleton from 34-01 with Sync-from-ClubCloud Quick Start placeholder)
  </read_first>
  <action>
    **Part A: Fill in the DE troubleshooting section** in `tournament-management.de.md`. The `## Problembehebung` H2 already exists with 4 H3 placeholders from the skeleton.

    For each H3, write three bold-labeled subsections on separate lines (D-07 format):

    ```markdown
    **Problem:** [symptom the volunteer sees]

    **Ursache:** [root cause, grounded in Phase 33 findings]

    **Lösung:** [concrete recovery step]
    ```

    **Case 1 — Einladungs-PDF konnte nicht hochgeladen werden (id="ts-invitation-upload"):**
    - Problem: Upload dialog shows error / infinite spinner / parsing fails.
    - Ursache: PDF-parser kann bestimmte NBV/DBU-Vorlagen nicht lesen; OCR fehlgeschlagen; Scan zu niedrig aufgelöst.
    - Lösung: Use the ClubCloud-Meldeliste as source (Alternative in Schritt 3) — D-07a honest alternative. Cross-link to walkthrough Step 3.

    **Case 2 — Spieler ist nicht in der ClubCloud-Meldeliste (id="ts-player-not-in-cc"):**
    - Problem: ClubCloud sync only returned N players though you expected more (as observed in F-03/F-04).
    - Ursache: ClubCloud sync delivered a partial result; the "Weiter mit diesen N Spielern" button is misleadingly green (F-04).
    - Lösung: Go to Schritt 4 (Teilnehmerliste ergänzen), use the DBU-Nummer input to add missing players (comma-separated). Reference walkthrough Step 4 via anchor link.

    **Case 3 — Falscher Turniermodus ausgewählt (id="ts-wrong-mode"):**
    - Problem: Nach dem Klick auf einen der 3 Modus-Cards (T04/T05/DefaultN) wurde der falsche Plan aktiviert, und der Start-Formular lädt bereits.
    - Ursache: Die Modus-Auswahl wird unmittelbar beim Klick angewendet, ohne Bestätigungsdialog (F-13).
    - Lösung: Browser-Back ist RISKANT wenn Teilnehmerliste bereits abgeschlossen ist — die einzige sichere Wiederherstellung ist über "Modus ändern" auf der Wizard-Übersicht, solange das Turnier noch nicht gestartet ist. Wenn `start_tournament!` bereits gefeuert hat, ist eine Änderung nur noch mit Admin-Eingriff möglich — siehe Case 4.

    **Case 4 — Turnier wurde bereits gestartet (id="ts-already-started"):**
    - Problem: Sie möchten Teilnehmer, Modus oder Start-Parameter ändern, aber der Wizard zeigt bereits den Turnier-Monitor.
    - Ursache: Der `start_tournament!` AASM-Event ist irreversibel (F-19 / Tier 3 Finding); es gibt aktuell keinen Undo-Pfad im v7.0 Scope.
    - Lösung: Wenden Sie sich an einen Carambus-Admin mit DB-Zugang. Eine typische Recovery ist: Turnier in neuer Instanz kopieren, alte Instanz markieren. Diese Operation ist nicht volunteer-freundlich und die GROSS MAJORITY von Fehlern an diesem Punkt lassen sich durch sorgfältiges Prüfen in Schritt 5 und Schritt 6 vermeiden. Cross-link to the F-19 callout in Step 9.

    **Part B: Write the 10 condensed DE Quick Start teaser steps** in `index.de.md`. Replace the placeholder steps 2–10 (step 1 is already "Turnier aus ClubCloud synchronisieren" from 34-01). Each teaser step is 1 line, links to the corresponding walkthrough anchor, and collapses the 14 walkthrough steps into 10 (combine by natural grouping — e.g. "Tische zuordnen & Turnier starten" as one teaser step that links to `#step-8-tables` or `#step-9-start`).

    Suggested mapping (final wording at executor's discretion, but step 1 is locked):

    ```markdown
    1. **Turnier aus ClubCloud synchronisieren** → [Schritt 2](tournament-management.md#step-2-load-clubcloud)
    2. **Setzliste übernehmen** → [Schritt 3](tournament-management.md#step-3-seeding-list)
    3. **Teilnehmerliste prüfen und ergänzen** → [Schritt 4](tournament-management.md#step-4-participants)
    4. **Teilnehmerliste abschließen** → [Schritt 5](tournament-management.md#step-5-finish-seeding)
    5. **Turniermodus auswählen** → [Schritt 6](tournament-management.md#step-6-mode-selection)
    6. **Start-Parameter ausfüllen** → [Schritt 7](tournament-management.md#step-7-start-form)
    7. **Tische zuordnen und Turnier starten** → [Schritt 8–9](tournament-management.md#step-8-tables)
    8. **Warmup und Spielbeginn** → [Schritt 10–11](tournament-management.md#step-10-warmup)
    9. **Ergebnisse verfolgen und finalisieren** → [Schritt 12–13](tournament-management.md#step-12-monitor)
    10. **Ergebnis-Upload nach ClubCloud** → [Schritt 14](tournament-management.md#step-14-upload)
    ```

    **Part C: Run `mkdocs build --strict` and commit.**

    ```bash
    cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
    mkdocs build --strict 2>&1 | tail -20
    ```

    If warnings appear (broken anchor, malformed admonition, missing image), fix them before committing. Likely sources of failure: the `#step-N-*` anchors in the index Quick Start links must match the actual IDs in tournament-management.de.md — verify with `grep 'id="step-'`.

    Then commit from carambus_master:
    ```bash
    cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
    git add docs/managers/tournament-management.de.md docs/managers/index.de.md
    git commit -m "docs(34-02): DE prose — walkthrough, glossary, troubleshooting, Quick Start teaser

    Fills in the 14-step task-first walkthrough with 4 mandatory Phase 33
    callouts (F-09, F-12, F-14, F-19), a 15+ term glossary grouped by
    category (Karambol / Wizard / System), and a 4-case Problem/Ursache/
    Lösung troubleshooting section. Also rewrites the index.de.md Quick
    Start as a 10-step teaser linking into walkthrough anchors.

    Scenario framing: generic NBV NDM Freie Partie Klasse 1–3 (D-04a).
    Refs DOC-01, DOC-03, DOC-04, DOC-05."
    git push
    ```
  </action>
  <verify>
    <automated>
      cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master && \
      grep -q 'id="ts-invitation-upload"' docs/managers/tournament-management.de.md && \
      grep -q 'id="ts-player-not-in-cc"' docs/managers/tournament-management.de.md && \
      grep -q 'id="ts-wrong-mode"' docs/managers/tournament-management.de.md && \
      grep -q 'id="ts-already-started"' docs/managers/tournament-management.de.md && \
      grep -c '\*\*Problem:\*\*' docs/managers/tournament-management.de.md | awk '$1>=4{exit 0} {exit 1}' && \
      grep -c '\*\*Ursache:\*\*' docs/managers/tournament-management.de.md | awk '$1>=4{exit 0} {exit 1}' && \
      grep -c '\*\*Lösung:\*\*' docs/managers/tournament-management.de.md | awk '$1>=4{exit 0} {exit 1}' && \
      ! grep -q '_(Inhalt folgt in Plan 34-02)_' docs/managers/tournament-management.de.md && \
      ! grep -q '_(folgt)_' docs/managers/tournament-management.de.md && \
      grep -q 'Turnier aus ClubCloud synchronisieren' docs/managers/index.de.md && \
      grep -cE 'tournament-management\.md#step-' docs/managers/index.de.md | awk '$1>=5{exit 0} {exit 1}' && \
      mkdocs build --strict >/dev/null 2>&1 && \
      git log -1 --format=%s | grep -q '34-02'
    </automated>
  </verify>
  <acceptance_criteria>
    - 4 troubleshooting H3 sections present with their anchor IDs intact
    - Each of the 4 cases has at least one `**Problem:**`, `**Ursache:**`, `**Lösung:**` line
    - No `_(Inhalt folgt in Plan 34-02)_` or `_(folgt)_` placeholders remain anywhere in tournament-management.de.md
    - index.de.md Quick Start has at least 5 links with `#step-` anchor fragments into tournament-management.md
    - `mkdocs build --strict` exits 0 (zero warnings)
    - A single commit in carambus_master with "34-02" in the subject touches tournament-management.de.md and index.de.md
  </acceptance_criteria>
  <done>
    DE troubleshooting complete; index.de.md Quick Start teaser complete; mkdocs strict build passes; DE prose commit landed in carambus_master.
  </done>
</task>

</tasks>

<threat_model>
Docs-only phase — Markdown rewrites, no new attack surface. N/A.

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-34-02 | N/A | docs/managers/*.de.md | accept | Volunteer-facing docs, no code, no secrets, no user input. mkdocs build is static. |
</threat_model>

<verification>
- tournament-management.de.md has all 14 walkthrough steps with prose (no placeholders)
- All 4 mandatory admonitions present with ref comments
- Glossary has all mandated 5 + Karambol terms (15+ entries)
- Troubleshooting has all 4 cases in D-07 order with Problem/Ursache/Lösung subsections
- index.de.md Quick Start leads with "Turnier aus ClubCloud synchronisieren" and links into walkthrough anchors
- `mkdocs build --strict` zero-warning
- One commit with "34-02" in subject in carambus_master
</verification>

<success_criteria>
DOC-01 (task-first rewrite), DOC-03 (glossary), DOC-04 (troubleshooting), DOC-05 (index Quick Start) satisfied for the DE language file. Parallel plan 34-03 (EN prose) can land independently — no file overlap.
</success_criteria>

<output>
After completion, create `.planning/phases/34-task-first-doc-rewrite/34-02-SUMMARY.md` in carambus_api summarizing:
- Line count of tournament-management.de.md before and after
- List of all admonitions added (quoted with ref)
- List of all glossary terms defined
- Commit SHA in carambus_master
- mkdocs build --strict result
- Any deviations from the interface block (and why)
</output>
