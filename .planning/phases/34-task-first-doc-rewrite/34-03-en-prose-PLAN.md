---
phase: 34-task-first-doc-rewrite
plan: 03
type: execute
wave: 2
depends_on:
  - 34-01
files_modified:
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.en.md
autonomous: true
requirements:
  - DOC-01
  - DOC-03
  - DOC-04
  - DOC-05
must_haves:
  truths:
    - "An EN volunteer opening tournament-management.en.md sees a task-first walkthrough opening, not architecture (DOC-01)"
    - "All 14 walkthrough steps from D-04 are present as H3 sections in English with concrete click-level prose"
    - "The 4 mandatory admonition callouts (F-09, F-12, F-14, F-19) are present in English with trailing '<!-- ref: F-NN -->' HTML comments"
    - "The glossary contains the 5 mandated terms plus Karambol vocabulary grouped by category in English"
    - "The troubleshooting section contains the 4 mandated cases in D-07 order with Problem/Cause/Fix subsections in English"
    - "index.en.md Quick Start leads with 'Sync tournament from ClubCloud' and the 10 teaser steps match the DE index structure"
  artifacts:
    - path: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md
      provides: "Task-first EN walkthrough with glossary, troubleshooting, architecture tail, admonition callouts"
      min_lines: 300
      contains: "NDM Freie Partie Class 1"
      contains_extra:
        - "<!-- ref: F-09 -->"
        - "<!-- ref: F-12 -->"
        - "<!-- ref: F-14 -->"
        - "<!-- ref: F-19 -->"
        - "!!! warning"
        - "!!! tip"
        - "Straight Rail"
        - "Three-Cushion"
        - "ClubCloud"
        - "seeding list"
        - "More on the architecture"
    - path: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.en.md
      provides: "Rewritten EN Quick Start (10 condensed teaser steps linking into walkthrough anchors)"
      contains: "Sync tournament from ClubCloud"
  key_links:
    - from: walkthrough admonition callouts
      to: 33-UX-FINDINGS.md F-09 / F-12 / F-14 / F-19
      via: "<!-- ref: F-NN --> trailing HTML comments (D-02a)"
      pattern: "<!-- ref: F-[0-9]+ -->"
    - from: EN file H2/H3 structure
      to: DE file H2/H3 structure
      via: identical anchor slugs (English-based per D-05a) — already locked by skeleton plan 34-01
      pattern: "identical id=\"...\" lines in both files"
    - from: index.en.md teaser steps
      to: tournament-management.en.md walkthrough anchors
      via: markdown links with #step-N-slug fragments
      pattern: "tournament-management\\.md#step-"
---

<objective>
Write the full EN prose for the Phase 34 task-first rewrite: walkthrough (14 steps), glossary (15+ terms grouped), troubleshooting (4 cases Problem/Cause/Fix), architecture tail block, and the index.en.md 10-step teaser Quick Start.

Purpose: Deliver the EN volunteer-facing walkthrough that matches the canonical wizard behavior observed in Phase 33, using the same generic NBV NDM Freie Partie Class 1–3 scenario framing (D-04a, D-04a-EN). This plan runs in parallel with 34-02 (DE) — no file overlap.

Output: Two updated EN files in carambus_master (tournament-management.en.md full prose, index.en.md Quick Start teaser) committed as one coherent EN-content commit.
</objective>

<execution_context>
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/workflows/execute-plan.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/templates/summary.md

## Cross-checkout constraint (MANDATORY — scenario-management skill)

All edits in this plan happen in `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/`. The commit is made from carambus_master. GSD SUMMARY.md lands in carambus_api. Do NOT edit `carambus_api/docs/managers/*.md`.

## Gate check before starting

This plan depends on 34-01 (skeleton commit). It can run IN PARALLEL with 34-02 (DE prose) because files_modified has zero overlap with that plan (EN files vs DE files). Before writing any prose, verify the skeleton commit exists:

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
git log --oneline -20 | grep '34-01' || { echo "FAIL: skeleton commit 34-01 missing — plan 34-03 must not run"; exit 1; }
grep -q 'id="walkthrough"' docs/managers/tournament-management.en.md || { echo "FAIL: skeleton anchors missing in EN file"; exit 1; }
```

If the gate check fails, STOP and return the error to the orchestrator.

## Translation workflow (Claude's discretion per CONTEXT.md)

If plan 34-02 has already landed by the time you run, READ the DE file as reference — it already contains the locked scenario framing, the Phase-33 finding alignment, and the structural tone. Translate adaptively (not literally) to idiomatic English while preserving: the 4 callout ref comments, all English-based anchor slugs, and the scenario name "NDM Freie Partie" (keep the German tournament name; DON'T translate "Freie Partie" to "Straight Rail" in the scenario framing since NBV is a German federation).

If plan 34-02 has NOT yet landed (true parallel execution), derive the EN prose directly from 33-UX-FINDINGS.md and the interfaces block in this plan. The DE file is an optional reference, not a hard dependency.

You MAY use `DeeplTranslationService` or `OpenaiTranslationService` (via bin/rails runner in carambus_master) to accelerate first-pass translation — terminology consistency is important for the Karambol terms.
</execution_context>

<context>
@.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md
@.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md
@.planning/phases/33-ux-review-wizard-audit/33-CONTEXT.md
@.agents/skills/scenario-management/SKILL.md

# Target files (skeleton from 34-01 is in place)
@docs/managers/tournament-management.en.md
@docs/managers/index.en.md

# Sibling docs — EN conventions, admonition style
@docs/managers/clubcloud-integration.en.md
@docs/managers/single-tournament.en.md

# DE parallel (optional reference — may not exist yet if plans run truly parallel)
@docs/managers/tournament-management.de.md
</context>

<interfaces>
<!-- Mandatory EN admonition callouts (D-02 equivalents, translated to English with locked intent) -->

## Mandatory admonition callouts (EN)

Each admonition is immediately followed by a trailing HTML comment `<!-- ref: F-NN -->` on its own line.

### At Step 5 (Close participant list — finish_seeding)

```markdown
!!! warning "Closing the participant list is final"
    Clicking **Close participant list** is a one-way action. Double-check
    the participant list carefully before you click — after closing, the
    wizard jumps straight to mode selection, and changing the participant
    list later requires admin intervention.
<!-- ref: F-09 -->
```

### At Step 6 (Select tournament mode)

```markdown
!!! tip "Which tournament plan should I pick?"
    Carambus usually suggests one plan automatically (for example **T04**
    for 5 participants). Accept the suggestion unless you have a specific
    reason to prefer an alternative. The alternatives differ mainly in the
    number of rounds and tournament days — for a typical NDM Freie Partie
    Class 1–3, the suggested plan is almost always correct.
<!-- ref: F-12 -->
```

### At Step 7 (Fill in start parameters)

```markdown
!!! tip "English field labels on the start form"
    A number of fields on the start form are currently labelled in English
    or in garbled German (for example *Tournament manager checks results
    before acceptance* or *Assign games as tables become available*). The
    [Glossary](#glossary) below explains the most important terms. When in
    doubt, keep the default values and review the settings after the
    tournament.
<!-- ref: F-14 -->
```

### At Step 9 (Start the tournament)

```markdown
!!! warning "Wait — do not click again"
    After you click **Starte den Turnier Monitor** the page will appear
    unchanged for several seconds. This is normal — the wizard is
    preparing the table monitors in the background. **Do not click the
    button again** and do not navigate back. The Tournament Monitor will
    open automatically within a few seconds.
<!-- ref: F-19 -->
```

## Mandatory glossary terms (D-03 — grouped by category, EN)

### Karambol terms
- Straight Rail (Freie Partie)
- Balkline (Cadre: 35/2, 47/1, 47/2, 71/2)
- Three-Cushion (Dreiband)
- One-Cushion (Einband)
- Inning (Aufnahme)
- Target balls (Bälle-Ziel / `innings_goal` in the code)
- High run (Höchstserie / HS)
- General average (Generaldurchschnitt / GD)
- Playing round (Spielrunde)
- Table warmup (Tisch-Warmup)

### Wizard terms
- Seeding list (Setzliste)
- Tournament mode / playing mode (Turniermodus)
- Tournament-plan codes (T04, T05, Default5)
- Scoreboard

### System terms
- ClubCloud
- AASM status
- DBU number (Deutsche Billard-Union player ID)
- Ranking

For each entry, keep both the EN term and the DE original in parentheses — this helps bilingual volunteers and makes the glossary searchable in either language. D-03a: 1–2 sentences per entry, wizard-step cross-reference where applicable.

## Mandatory troubleshooting cases (D-07 — order locked, EN)

Use `**Problem:**` / `**Cause:**` / `**Fix:**` as bold labels.

1. Invitation upload failed (id="ts-invitation-upload")
2. Player not in ClubCloud (id="ts-player-not-in-cc") — ground in F-03/F-04
3. Wrong mode selected (id="ts-wrong-mode") — ground in F-12/F-13
4. Tournament already started (id="ts-already-started") — ground in F-19 honestly; no undo in v7.0 scope

## Scenario framing (D-04a, EN)

Opening sentence of `## Scenario`:

> As the tournament director for your club you have received an NBV
> invitation for the **NDM Freie Partie Class 1–3** — a regional carom
> tournament running one Saturday in your club's playing location with
> 5 registered players across two tables. This page walks you through
> running the tournament from the moment the invitation arrives to the
> moment the results are uploaded back to ClubCloud.

Keep "NDM Freie Partie" in German (it is the tournament's proper name); the "Class 1–3" suffix is translated. No concrete tournament ID, no concrete date.

## Tail architecture block (D-01, EN)

Exactly 2 paragraphs under `## More on the architecture`, under 200 words total.

Paragraph 1: Carambus is a hierarchy of web services — a central API server publishes tournaments, regional/local Carambus servers pull synced data, and scoreboards drive match recording in real time. Global records (synced from the API) are read-only for identity fields; your local server handles wizard state transitions and match recording.

Paragraph 2: Link to `../developers/index.md`. "Day-to-day tournament management does not require understanding the architecture — if you followed the walkthrough above, you already know everything you need."
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Write full EN walkthrough prose with callouts (Steps 1–14)</name>
  <files>/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md</files>
  <read_first>
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md (D-01, D-02, D-04, D-04a)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md (F-01..F-24 — authoritative wizard behavior)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md (skeleton from 34-01)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md (DE parallel — may already have prose if 34-02 landed first; use as translation reference if so)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/clubcloud-integration.en.md (existing EN tone)
  </read_first>
  <action>
    Fill in the EN walkthrough prose in `tournament-management.en.md`. The skeleton H2/H3/anchor structure from plan 34-01 is already in place — KEEP ALL ANCHOR TAGS and H2/H3 header text unchanged. Only replace the `_(content TBD in Plan 34-03)_` placeholder bodies with real prose.

    **Tone:** professional, volunteer-friendly, direct. UK or US English is fine — pick one and be consistent. Address the reader as "you" (imperative "Open..." / "Click..." is preferred over "The tournament director opens...").

    **Scenario section (## Scenario):** Use the exact EN scenario framing from the `<interfaces>` block (keeps "NDM Freie Partie" in German, translates "Class 1–3").

    **Walkthrough (## Walkthrough):** 14 H3 sections, each 80–150 words except Step 1 (~40). Follow the same step-content structure as the DE plan 34-02, translated and adapted:

    1. **Step 1 — Receive the NBV invitation:** Scenario entry, no click.
    2. **Step 2 — Load tournament from ClubCloud (Wizard Step 1):** Open the tournament show page; Step 1 is usually auto-completed (GELADEN checkmark). Warn about partial sync (F-03/F-04) and link to troubleshooting case 2.
    3. **Step 3 — Seeding list: invitation vs ClubCloud:** Two paths — PDF upload or ClubCloud as source. Honestly note that the UI frames PDF as primary (F-05). Describe the compare-seedings view.
    4. **Step 4 — Review and add participants:** Use the DBU-Nummer input (comma-separated). Mention "Sort by ranking" default (F-08) and the inline tournament-plan auto-suggest (F-07 — gold standard).
    5. **Step 5 — Close participant list:** **Insert F-09 warning admonition here with trailing `<!-- ref: F-09 -->`.** Explain the jump Step 3 → Step 5 (F-11).
    6. **Step 6 — Select tournament mode:** Mode-selection page with 3 alternative cards. **Insert F-12 tip admonition here with trailing `<!-- ref: F-12 -->`.** Note that selection is applied on click, no back-out (F-13) — link to troubleshooting case 3.
    7. **Step 7 — Fill in start parameters:** **Insert F-14 tip admonition here with trailing `<!-- ref: F-14 -->`.** Acknowledge the English/garbled labels. Point to glossary for Bälle-Ziel / innings_goal, Aufnahme, HS, GD.
    8. **Step 8 — Assign tables:** Brief — pick 2 tables from dropdown (F-18 — dev-DB placeholders are cosmetic).
    9. **Step 9 — Start the tournament:** **Insert F-19 warning admonition here with trailing `<!-- ref: F-19 -->`.** The load-bearing callout.
    10. **Step 10 — Warmup phase:** Tournament Monitor loads, tables in `warmup` state. F-21 note: "Turnierphase: playing group" is English — acknowledge. F-22 note: orange "edit on" badge meaning unclear.
    11. **Step 11 — Release each match:** Click "Spielbeginn" per row (F-20 — no success flash).
    12. **Step 12 — Monitor results:** The Tournament Monitor updates live via ActionCable. Volunteer typically does nothing here.
    13. **Step 13 — Finalize the tournament:** After last round, the Tournament Monitor exposes finalize. Link to single-tournament.en.md for placement-edit details.
    14. **Step 14 — Post-tournament upload:** If `auto_upload_to_cc` is enabled, results push to ClubCloud automatically. Configured on the start form (Step 7), default usually correct.

    **Mehr zur Technik tail (## More on the architecture):** Write the 2-paragraph EN content per the `<interfaces>` block. Link to `../developers/index.md`. Under 200 words.

    **Do NOT modify** the Glossary or Troubleshooting H2 sections — those are Task 2 and Task 3.
  </action>
  <verify>
    <automated>
      cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master && \
      wc -l docs/managers/tournament-management.en.md | awk '{if ($1 < 200) exit 1; else exit 0}' && \
      grep -q '<!-- ref: F-09 -->' docs/managers/tournament-management.en.md && \
      grep -q '<!-- ref: F-12 -->' docs/managers/tournament-management.en.md && \
      grep -q '<!-- ref: F-14 -->' docs/managers/tournament-management.en.md && \
      grep -q '<!-- ref: F-19 -->' docs/managers/tournament-management.en.md && \
      grep -c '!!! warning' docs/managers/tournament-management.en.md | awk '$1>=2{exit 0} {exit 1}' && \
      grep -c '!!! tip' docs/managers/tournament-management.en.md | awk '$1>=2{exit 0} {exit 1}' && \
      grep -qE 'NDM Freie Partie' docs/managers/tournament-management.en.md && \
      grep -c 'id="step-' docs/managers/tournament-management.en.md | awk '$1>=14{exit 0} {exit 1}' && \
      (grep -q 'More on the architecture' docs/managers/tournament-management.en.md || grep -q 'id="architecture"' docs/managers/tournament-management.en.md) && \
      grep -q 'developers' docs/managers/tournament-management.en.md && \
      ! head -20 docs/managers/tournament-management.en.md | grep -qiE '(Introduction|Structure|Carambus API )'
    </automated>
  </verify>
  <acceptance_criteria>
    - File length ≥ 200 lines
    - All 4 `<!-- ref: F-NN -->` comments present
    - At least 2 `!!! warning` and 2 `!!! tip` admonitions
    - Scenario section contains "NDM Freie Partie"
    - All 14 `id="step-..."` anchors preserved
    - Tail architecture block exists and links to `../developers/`
    - First 20 lines contain NO architecture keywords (Introduction/Structure/Carambus API)
    - Glossary and Troubleshooting still contain placeholders (Task 2/3 fill them)
  </acceptance_criteria>
  <done>
    EN walkthrough prose complete with 14 steps, 4 mandatory admonitions, scenario framing, tail architecture block. Task-first compliance holds.
  </done>
</task>

<task type="auto">
  <name>Task 2: Write EN glossary entries (Karambol / Wizard / System)</name>
  <files>/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md</files>
  <read_first>
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md (D-03, D-03a)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md (post-Task-1)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md (DE glossary for parallel — may or may not exist yet)
  </read_first>
  <action>
    Fill in the `## Glossary` section with three H3 subsections: `### Karambol terms`, `### Wizard terms`, `### System terms`. Terms and grouping from the `<interfaces>` block.

    **Format per entry (EN, with DE original in parentheses for bilingual searchability):**

    ```markdown
    - **Straight Rail (Freie Partie)** — The simplest carom discipline: one point per legal carom, no field restrictions. Target balls typically range 50–150 depending on class. *You see this term in the [start form, Step 7](#step-7-start-form).*
    ```

    All 10 Karambol terms, 4 Wizard terms, 4 System terms from the `<interfaces>` block. Each 1–2 sentences plus optional wizard-step cross-reference.

    For the Bälle-Ziel entry, explicitly note the code name `innings_goal` so volunteers recognize the F-14 start-form label.

    For the AASM status entry, note that Phase 36 will make this badge more prominent.

    **Do NOT modify** walkthrough or troubleshooting sections.
  </action>
  <verify>
    <automated>
      cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master && \
      grep -q 'Straight Rail' docs/managers/tournament-management.en.md && \
      grep -q 'Balkline' docs/managers/tournament-management.en.md && \
      grep -q 'Three-Cushion' docs/managers/tournament-management.en.md && \
      grep -q 'One-Cushion' docs/managers/tournament-management.en.md && \
      grep -q 'Inning' docs/managers/tournament-management.en.md && \
      grep -qi 'target balls\|innings_goal' docs/managers/tournament-management.en.md && \
      grep -qi 'high run\|Höchstserie' docs/managers/tournament-management.en.md && \
      grep -qi 'general average\|Generaldurchschnitt' docs/managers/tournament-management.en.md && \
      grep -qi 'playing round' docs/managers/tournament-management.en.md && \
      grep -qi 'table warmup' docs/managers/tournament-management.en.md && \
      grep -q 'seeding list' docs/managers/tournament-management.en.md && \
      grep -qi 'tournament mode\|playing mode' docs/managers/tournament-management.en.md && \
      grep -q 'Scoreboard' docs/managers/tournament-management.en.md && \
      grep -q 'ClubCloud' docs/managers/tournament-management.en.md && \
      grep -q 'AASM' docs/managers/tournament-management.en.md && \
      grep -qi 'DBU number\|DBU-Nummer' docs/managers/tournament-management.en.md && \
      grep -q 'id="glossary-karambol"' docs/managers/tournament-management.en.md && \
      grep -q 'id="glossary-wizard"' docs/managers/tournament-management.en.md && \
      grep -q 'id="glossary-system"' docs/managers/tournament-management.en.md && \
      ! grep -q '_(Definition TBD)_' docs/managers/tournament-management.en.md
    </automated>
  </verify>
  <acceptance_criteria>
    - All 5 mandated terms present: ClubCloud, seeding list, tournament mode, AASM, Scoreboard
    - All 10 Karambol terms present (Straight Rail, Balkline, Three-Cushion, One-Cushion, Inning, Target balls, High run, General average, Playing round, Table warmup)
    - Three glossary anchor IDs preserved
    - No placeholder text remains in glossary
    - At least one entry links to a walkthrough step anchor
  </acceptance_criteria>
  <done>
    EN glossary complete with all mandated terms plus Karambol vocabulary, each entry includes the DE original for bilingual searchability.
  </done>
</task>

<task type="auto">
  <name>Task 3: Write EN troubleshooting section + index.en.md Quick Start teaser + commit</name>
  <files>
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md,
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.en.md
  </files>
  <read_first>
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md (D-07, D-07a, D-06, D-06a)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md (F-03/F-04 for case 2, F-12/F-13 for case 3, F-19 for case 4)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md (post-Task-2 state)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.en.md (skeleton from 34-01)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md (DE parallel — for index teaser step wording alignment if 34-02 already landed)
  </read_first>
  <action>
    **Part A: Fill in the EN troubleshooting section** in `tournament-management.en.md`. The `## Troubleshooting` H2 has 4 H3 placeholders from the skeleton.

    For each H3, write three bold-labeled lines:

    ```markdown
    **Problem:** [what the volunteer sees]

    **Cause:** [root cause grounded in Phase 33 findings]

    **Fix:** [concrete recovery step]
    ```

    **Case 1 — Invitation upload failed:**
    - Problem: Upload dialog shows an error or infinite spinner; parsing fails.
    - Cause: The PDF parser cannot read certain NBV/DBU layouts; OCR failed; scan resolution too low.
    - Fix: Use ClubCloud as the seeding-list source instead (the alternative in Step 3). Link to walkthrough Step 3.

    **Case 2 — Player not in ClubCloud:**
    - Problem: ClubCloud sync returned fewer players than expected (as seen in F-03/F-04).
    - Cause: Partial sync result from ClubCloud; the wizard's green "Continue with N players" button is misleading (F-04).
    - Fix: Go to Step 4 (Review and add participants) and use the DBU number input (comma-separated) to add missing players. Link walkthrough Step 4.

    **Case 3 — Wrong mode selected:**
    - Problem: After clicking one of the 3 mode cards (T04/T05/DefaultN), the wrong plan is active and the start form is already loading.
    - Cause: Mode selection is applied immediately on click with no confirmation (F-13).
    - Fix: Browser back is RISKY once the participant list has been closed. The only safe recovery is via "Change mode" on the wizard overview, and only while the tournament has not yet been started. If `start_tournament!` has already fired, see Case 4.

    **Case 4 — Tournament already started:**
    - Problem: You need to change participants, mode, or start parameters, but the wizard is already showing the Tournament Monitor.
    - Cause: The `start_tournament!` AASM event is irreversible (F-19 / Tier 3 finding); there is no undo path in the v7.0 scope.
    - Fix: Contact a Carambus admin with database access. A typical recovery is to copy the tournament into a new instance and mark the old one. This is not a volunteer-friendly operation — the vast majority of errors at this point can be avoided by careful review in Steps 5 and 6. Link to the F-19 callout in Step 9.

    **Part B: Write the 10 condensed EN Quick Start teaser steps** in `index.en.md`. Replace the placeholder steps 2–10 (step 1 is already "Sync tournament from ClubCloud" from 34-01). Match the DE structure from 34-02 so the two indexes line up step-by-step.

    Target wording (1 line per step, link to walkthrough anchors, step 1 wording LOCKED):

    ```markdown
    1. **Sync tournament from ClubCloud** → [Step 2](tournament-management.md#step-2-load-clubcloud)
    2. **Apply the seeding list** → [Step 3](tournament-management.md#step-3-seeding-list)
    3. **Review and add participants** → [Step 4](tournament-management.md#step-4-participants)
    4. **Close the participant list** → [Step 5](tournament-management.md#step-5-finish-seeding)
    5. **Select tournament mode** → [Step 6](tournament-management.md#step-6-mode-selection)
    6. **Fill in start parameters** → [Step 7](tournament-management.md#step-7-start-form)
    7. **Assign tables and start the tournament** → [Steps 8–9](tournament-management.md#step-8-tables)
    8. **Warmup and match release** → [Steps 10–11](tournament-management.md#step-10-warmup)
    9. **Monitor and finalize results** → [Steps 12–13](tournament-management.md#step-12-monitor)
    10. **Upload results to ClubCloud** → [Step 14](tournament-management.md#step-14-upload)
    ```

    Step 1 MUST be literally "Sync tournament from ClubCloud" — not "Create tournament".

    **Part C: Run `mkdocs build --strict` and commit.**

    ```bash
    cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
    mkdocs build --strict 2>&1 | tail -20
    ```

    If warnings: fix broken anchors (grep `id="step-"` in tournament-management.en.md and verify all index.en.md links match). Then commit:

    ```bash
    cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
    git add docs/managers/tournament-management.en.md docs/managers/index.en.md
    git commit -m "docs(34-03): EN prose — walkthrough, glossary, troubleshooting, Quick Start teaser

    Fills in the 14-step task-first walkthrough with 4 mandatory Phase 33
    callouts (F-09, F-12, F-14, F-19), a 15+ term glossary grouped by
    category, and a 4-case Problem/Cause/Fix troubleshooting section.
    Also rewrites the index.en.md Quick Start as a 10-step teaser
    linking into walkthrough anchors.

    Scenario framing: generic NBV NDM Freie Partie Class 1–3 (D-04a).
    Refs DOC-01, DOC-03, DOC-04, DOC-05."
    git push
    ```
  </action>
  <verify>
    <automated>
      cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master && \
      grep -q 'id="ts-invitation-upload"' docs/managers/tournament-management.en.md && \
      grep -q 'id="ts-player-not-in-cc"' docs/managers/tournament-management.en.md && \
      grep -q 'id="ts-wrong-mode"' docs/managers/tournament-management.en.md && \
      grep -q 'id="ts-already-started"' docs/managers/tournament-management.en.md && \
      grep -c '\*\*Problem:\*\*' docs/managers/tournament-management.en.md | awk '$1>=4{exit 0} {exit 1}' && \
      grep -c '\*\*Cause:\*\*' docs/managers/tournament-management.en.md | awk '$1>=4{exit 0} {exit 1}' && \
      grep -c '\*\*Fix:\*\*' docs/managers/tournament-management.en.md | awk '$1>=4{exit 0} {exit 1}' && \
      ! grep -q '_(content TBD in Plan 34-03)_' docs/managers/tournament-management.en.md && \
      ! grep -q '_(TBD)_' docs/managers/tournament-management.en.md && \
      grep -q 'Sync tournament from ClubCloud' docs/managers/index.en.md && \
      ! grep -qE '^\s*1\.\s+\*\*Create tournament\*\*' docs/managers/index.en.md && \
      grep -cE 'tournament-management\.md#step-' docs/managers/index.en.md | awk '$1>=5{exit 0} {exit 1}' && \
      mkdocs build --strict >/dev/null 2>&1 && \
      git log -1 --format=%s | grep -q '34-03'
    </automated>
  </verify>
  <acceptance_criteria>
    - 4 troubleshooting H3 sections with their anchor IDs intact
    - Each of the 4 cases has at least one `**Problem:**`, `**Cause:**`, `**Fix:**` line
    - No `_(content TBD in Plan 34-03)_` or `_(TBD)_` placeholders remain
    - index.en.md Quick Start has at least 5 links with `#step-` anchors into tournament-management.md
    - index.en.md does NOT contain `1. **Create tournament**`
    - `mkdocs build --strict` exits 0
    - A single commit in carambus_master with "34-03" in the subject touches tournament-management.en.md and index.en.md
  </acceptance_criteria>
  <done>
    EN troubleshooting complete; index.en.md Quick Start teaser complete; mkdocs strict build passes; EN prose commit landed in carambus_master.
  </done>
</task>

</tasks>

<threat_model>
Docs-only phase — Markdown rewrites, no new attack surface. N/A.

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-34-03 | N/A | docs/managers/*.en.md | accept | Volunteer-facing docs, no code, no secrets, no user input. mkdocs build is static. |
</threat_model>

<verification>
- tournament-management.en.md has all 14 walkthrough steps with EN prose
- All 4 mandatory admonitions present with ref comments
- Glossary has all mandated 5 + Karambol terms (15+ entries)
- Troubleshooting has 4 cases in D-07 order with Problem/Cause/Fix subsections
- index.en.md Quick Start leads with "Sync tournament from ClubCloud"
- `mkdocs build --strict` passes
- One commit with "34-03" in subject in carambus_master
</verification>

<success_criteria>
DOC-01, DOC-03, DOC-04, DOC-05 satisfied for the EN language file. Structural parity with the DE file is guaranteed because both were built from the same skeleton in plan 34-01.
</success_criteria>

<output>
After completion, create `.planning/phases/34-task-first-doc-rewrite/34-03-SUMMARY.md` in carambus_api summarizing:
- Line count of tournament-management.en.md before and after
- Translation workflow used (DeepL / manual / hybrid)
- Commit SHA in carambus_master
- mkdocs build --strict result
- Any structural drift from the DE file (should be zero; if nonzero, justify)
</output>
