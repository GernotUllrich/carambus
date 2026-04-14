---
phase: 34-task-first-doc-rewrite
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.de.md
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.en.md
autonomous: true
requirements:
  - DOC-01
  - DOC-02
  - DOC-05
must_haves:
  truths:
    - "Both tournament-management.{de,en}.md open with a task walkthrough H2 within the first 20 lines (no architecture content at the top)"
    - "Both tournament-management.{de,en}.md share an identical H2/H3 heading order and identical anchor slugs"
    - "Both index.{de,en}.md Quick Start sections are replaced with a placeholder Sync-from-ClubCloud skeleton (no 'Turnier anlegen' / 'Create tournament' as step 1)"
    - "All four files are committed in one commit in carambus_master before any prose is written (D-05 hard gate)"
  artifacts:
    - path: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md
      provides: "DE bilingual skeleton with walkthrough / glossary / troubleshooting / architecture-tail H2 sections and placeholder bodies"
      contains: "## Walkthrough"
      contains_extra:
        - "## Glossary"
        - "## Troubleshooting"
        - "<!-- anchor: walkthrough -->"
    - path: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md
      provides: "EN bilingual skeleton with identical H2/H3 structure and identical anchor slugs as DE file"
      contains: "## Walkthrough"
    - path: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.de.md
      provides: "Rewritten DE Quick Start skeleton with 'Turnier aus ClubCloud synchronisieren' as step 1"
      contains: "Turnier aus ClubCloud synchronisieren"
    - path: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.en.md
      provides: "Rewritten EN Quick Start skeleton with 'Sync tournament from ClubCloud' as step 1"
      contains: "Sync tournament from ClubCloud"
  key_links:
    - from: tournament-management.de.md (structure)
      to: tournament-management.en.md (structure)
      via: identical H2/H3 ordering and identical anchor slugs
      pattern: "diff of '^#' lines returns empty"
    - from: both tournament-management files
      to: English anchor slugs (D-05a)
      via: "HTML anchor comments (e.g. <!-- anchor: walkthrough -->) or native mkdocs slug generation from English H2 text"
      pattern: "#walkthrough, #glossary, #troubleshooting, #sync-from-clubcloud"
---

<objective>
Lay down the bilingual H2/H3/anchor skeleton for all four Phase 34 doc targets in a single commit in `carambus_master`, BEFORE any prose is written (D-05 hard gate, DOC-02).

Purpose: Lock the structure so DE and EN prose plans (Wave 2) can work in parallel against a frozen heading order. English-based anchors (D-05a) enable Phase 37 deep-linking.

Output: Four rewritten files with identical H2/H3/anchor skeleton, placeholder bodies only (`_(Walkthrough folgt)_` in DE, `_(walkthrough TBD)_` in EN), one commit in carambus_master.
</objective>

<execution_context>
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/workflows/execute-plan.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/templates/summary.md

## Cross-checkout constraint (MANDATORY — scenario-management skill)

All docs edits in this plan happen in `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/`, NOT in the carambus_api checkout. The git commit for this plan runs from `carambus_master`:

```
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
git add docs/managers/tournament-management.de.md docs/managers/tournament-management.en.md docs/managers/index.de.md docs/managers/index.en.md
git commit -m "docs(34-01): bilingual H2/H3 skeleton gate for task-first rewrite"
git push
```

The GSD SUMMARY.md for this plan lives in carambus_api (`.planning/phases/34-task-first-doc-rewrite/34-01-SUMMARY.md`) and is committed separately via the carambus_api git workflow.

Do NOT edit `.../carambus_api/docs/managers/*.md` directly — that would violate the scenario-management skill. The user syncs api from master via normal `git pull` after master is pushed.
</execution_context>

<context>
@.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md
@.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md
@.agents/skills/scenario-management/SKILL.md

# Current state of target files (to be fully replaced)
@docs/managers/tournament-management.de.md
@docs/managers/tournament-management.en.md
@docs/managers/index.de.md
@docs/managers/index.en.md

# Existing sibling docs (patterns for admonitions, bilingual conventions, anchor style)
@docs/managers/clubcloud-integration.de.md
@docs/managers/single-tournament.de.md
</context>

<interfaces>
<!-- Exact H2 skeleton that BOTH language files must share. Header text is translated; anchor slugs are English-based per D-05a. -->

## tournament-management.{de,en}.md — H2 order (MANDATORY)

```
# Tournament Management / Turnierverwaltung                    (H1)
(intro paragraph — 1–2 sentences, task-first, no architecture)
## Scenario / Szenario                                         (#scenario)
## Walkthrough / Durchführung Schritt für Schritt              (#walkthrough)
  ### Step 1: Receive the NBV invitation / Die NBV-Einladung erhalten           (#step-1-invitation)
  ### Step 2: Load tournament from ClubCloud / Turnier aus ClubCloud laden      (#step-2-load-clubcloud)
  ### Step 3: Seeding list: invitation vs ClubCloud / Setzliste übernehmen      (#step-3-seeding-list)
  ### Step 4: Review and add participants / Teilnehmerliste prüfen und ergänzen (#step-4-participants)
  ### Step 5: Close participant list / Teilnehmerliste abschließen              (#step-5-finish-seeding)
  ### Step 6: Select tournament mode / Turniermodus auswählen                   (#step-6-mode-selection)
  ### Step 7: Fill in start parameters / Start-Parameter ausfüllen              (#step-7-start-form)
  ### Step 8: Assign tables / Tische zuordnen                                   (#step-8-tables)
  ### Step 9: Start the tournament / Turnier starten                            (#step-9-start)
  ### Step 10: Warmup phase / Warmup-Phase                                      (#step-10-warmup)
  ### Step 11: Release each match / Spielbeginn freigeben                       (#step-11-release-match)
  ### Step 12: Monitor results / Ergebnisse verfolgen                           (#step-12-monitor)
  ### Step 13: Finalize the tournament / Turnier finalisieren                   (#step-13-finalize)
  ### Step 14: Post-tournament upload / Ergebnis-Upload nach ClubCloud          (#step-14-upload)
## Glossary / Glossar                                          (#glossary)
  ### Karambol terms / Karambol-Begriffe                       (#glossary-karambol)
  ### Wizard terms / Wizard-Begriffe                           (#glossary-wizard)
  ### System terms / System-Begriffe                           (#glossary-system)
## Troubleshooting / Problembehebung                           (#troubleshooting)
  ### Invitation upload failed / Einladungs-PDF konnte nicht hochgeladen werden (#ts-invitation-upload)
  ### Player not in ClubCloud / Spieler nicht in der ClubCloud-Meldeliste       (#ts-player-not-in-cc)
  ### Wrong mode selected / Falscher Turniermodus gewählt                       (#ts-wrong-mode)
  ### Tournament already started / Turnier wurde bereits gestartet              (#ts-already-started)
## More on the architecture / Mehr zur Technik                 (#architecture)
```

Anchor slugs are set using raw HTML anchor comments immediately above each H2/H3:

```markdown
<!-- anchor: walkthrough -->
## Durchführung Schritt für Schritt
```

and

```markdown
<a id="walkthrough"></a>
## Durchführung Schritt für Schritt
```

Pick ONE convention (prefer `<a id="...">`) and use it consistently across all four files so Phase 37 can deep-link reliably. This is Claude's discretion within D-05a.

## index.{de,en}.md — Quick Start H2 replacement (targeted, not full rewrite)

The rest of `index.{de,en}.md` stays untouched. Only the `## 🚀 Schnellstart: Ihr erstes Turnier in 10 Schritten` / `## 🚀 Quick Start: Your First Tournament in 10 Steps` section is replaced. New skeleton:

```
## 🚀 Quick Start: Sync and Run a Tournament in 10 Steps
     / Schnellstart: Turnier synchronisieren und durchführen in 10 Schritten

1. Sync tournament from ClubCloud   / Turnier aus ClubCloud synchronisieren
2. _(placeholder step 2)_
...
10. _(placeholder step 10)_

➡️ **[Full walkthrough](tournament-management.md#walkthrough)** / **[Zur vollständigen Durchführungs-Anleitung](tournament-management.md#walkthrough)**
```

Step 1 MUST be "Sync tournament from ClubCloud" / "Turnier aus ClubCloud synchronisieren" — NOT "Create tournament" / "Turnier anlegen" (DOC-05 hard requirement).

The 10 steps are a condensed teaser version of the 14-step walkthrough; exact wording is finalized in Wave 2. For this skeleton plan, placeholder text is acceptable for steps 2–10 as long as step 1 is correct.
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Write bilingual tournament-management skeleton (DE + EN)</name>
  <files>
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md,
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md
  </files>
  <read_first>
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md (D-01, D-04, D-05, D-05a)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md (confirms the 14-step walkthrough mirrors the real wizard)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md (current state — to be FULLY replaced)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md (current state — to be FULLY replaced)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.agents/skills/scenario-management/SKILL.md (reminds you to edit in carambus_master, not carambus_api)
  </read_first>
  <action>
    Fully replace the contents of both `tournament-management.de.md` and `tournament-management.en.md` in `carambus_master/docs/managers/` with a parallel skeleton that has the exact H2/H3 structure and anchor slugs defined in the `<interfaces>` block above.

    **First 20 lines rule (DOC-01):** The H1, a 1–2 sentence task-focused intro, and the `## Szenario` / `## Scenario` H2 must all appear within the first 20 lines of each file. No architecture content at the top. Architecture belongs ONLY in the tail `## Mehr zur Technik` / `## More on the architecture` H2.

    **Anchor convention (D-05a):** Use HTML anchor tags `<a id="slug"></a>` immediately above each H2 and each H3, with slug values from the interfaces block (#walkthrough, #glossary, #troubleshooting, #step-1-invitation ... #step-14-upload, #glossary-karambol, #glossary-wizard, #glossary-system, #ts-invitation-upload, #ts-player-not-in-cc, #ts-wrong-mode, #ts-already-started, #architecture, #scenario). Slugs are English-based and IDENTICAL across DE and EN.

    **Placeholder bodies:**
    - For every H2 except the intro: under the header, write a single-line placeholder paragraph.
      - DE: `_(Inhalt folgt in Plan 34-02)_`
      - EN: `_(content TBD in Plan 34-03)_`
    - For every H3 under `## Walkthrough`: same placeholder.
    - For every H3 under `## Glossary`: same placeholder, but list the term names that will appear (mandated 5 + Karambol terms per D-03), one bullet per term, no definitions yet. Example DE under `### Karambol-Begriffe`:
      ```
      - **Freie Partie** — _(Definition folgt)_
      - **Cadre 35/2, 47/1, 47/2, 71/2** — _(Definition folgt)_
      - **Dreiband** — _(Definition folgt)_
      - **Einband** — _(Definition folgt)_
      - **Aufnahme** — _(Definition folgt)_
      - **Bälle-Ziel (innings_goal)** — _(Definition folgt)_
      - **Höchstserie (HS)** — _(Definition folgt)_
      - **Generaldurchschnitt (GD)** — _(Definition folgt)_
      - **Spielrunde** — _(Definition folgt)_
      - **Tisch-Warmup** — _(Definition folgt)_
      ```
      Under `### Wizard-Begriffe`: Setzliste, Turniermodus, Turnierplan-Kürzel (T04, T05, Default5), Scoreboard.
      Under `### System-Begriffe`: ClubCloud, AASM-Status, DBU-Nummer, Rangliste.
    - For every H3 under `## Troubleshooting`: write the three sub-labels as placeholder lines:
      ```
      **Problem / Problem:** _(folgt)_
      **Ursache / Cause:** _(folgt)_
      **Lösung / Fix:** _(folgt)_
      ```

    **Szenario H2 placeholder body:** Write one placeholder sentence. Example DE: `_(Szenario-Einstieg — ausgefüllt in Plan 34-02)_`. Example EN: `_(scenario framing — filled in Plan 34-03)_`.

    **Intro sentence (above ## Szenario, under H1):** Must be a single task-focused sentence, NOT architecture. Example DE: "Diese Seite führt Sie als Turnierleiter Schritt für Schritt durch ein aus der ClubCloud geladenes Karambol-Turnier — vom Eingang der Einladung bis zum Ergebnis-Upload." Example EN: "This page walks you through running a carom tournament synced from ClubCloud, step by step, from the moment you receive the invitation to the final upload of results."

    **Mehr zur Technik tail H2 placeholder body:** DE: `_(Architektur-Kurzüberblick folgt — siehe [Entwickler-Dokumentation](../developers/index.md))_`. EN: `_(Architecture overview TBD — see [developer docs](../developers/index.md))_`.

    **CRITICAL:** Do NOT write any walkthrough prose, glossary definitions, troubleshooting content, or admonition callouts in this task. Those are Wave 2 (plans 34-02 and 34-03). This plan is structure-only. Writing prose here violates the D-05 skeleton gate.

    Use the Write tool (full replace) since both files are being completely rewritten. Confirm that after writing, the first 20 lines of each file contain the H1, the intro sentence, the `<a id="scenario">` anchor, the `## Szenario` / `## Scenario` H2, and the placeholder body — nothing else (DOC-01 compliance check).
  </action>
  <verify>
    <automated>
      cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master && \
      test -f docs/managers/tournament-management.de.md && \
      test -f docs/managers/tournament-management.en.md && \
      head -20 docs/managers/tournament-management.de.md | grep -q '^## ' && \
      head -20 docs/managers/tournament-management.de.md | grep -qiE '(Szenario|Scenario)' && \
      ! head -20 docs/managers/tournament-management.de.md | grep -qiE '(Einführung|Struktur|Carambus API)' && \
      head -20 docs/managers/tournament-management.en.md | grep -q '^## ' && \
      head -20 docs/managers/tournament-management.en.md | grep -qi 'Scenario' && \
      ! head -20 docs/managers/tournament-management.en.md | grep -qiE '(Introduction|Structure|Carambus API)' && \
      diff <(grep -E '^#{1,6} ' docs/managers/tournament-management.de.md | wc -l) <(grep -E '^#{1,6} ' docs/managers/tournament-management.en.md | wc -l) && \
      diff <(grep -E '^<a id=' docs/managers/tournament-management.de.md) <(grep -E '^<a id=' docs/managers/tournament-management.en.md) && \
      grep -c '^## ' docs/managers/tournament-management.de.md | awk '$1>=6{exit 0} {exit 1}' && \
      grep -q 'id="walkthrough"' docs/managers/tournament-management.de.md && \
      grep -q 'id="glossary"' docs/managers/tournament-management.de.md && \
      grep -q 'id="troubleshooting"' docs/managers/tournament-management.de.md && \
      grep -q 'id="architecture"' docs/managers/tournament-management.de.md && \
      grep -c 'id="step-' docs/managers/tournament-management.de.md | awk '$1>=14{exit 0} {exit 1}'
    </automated>
  </verify>
  <acceptance_criteria>
    - Both DE and EN files exist in carambus_master/docs/managers/
    - First 20 lines of each file contain an H2 (Scenario/Szenario); NO architecture-word H2 (Einführung/Struktur/Introduction/Carambus API) appears in those 20 lines
    - H1/H2/H3 line counts match between DE and EN (`grep -cE '^#{1,6} '` produces equal numbers)
    - Every `<a id="...">` anchor line in the DE file has an identical counterpart in the EN file (diff empty)
    - DE file contains all required anchor IDs: walkthrough, glossary, troubleshooting, architecture, scenario, step-1 through step-14, glossary-karambol, glossary-wizard, glossary-system, ts-invitation-upload, ts-player-not-in-cc, ts-wrong-mode, ts-already-started
    - No walkthrough prose, no glossary definitions, no troubleshooting content, no admonition callouts (`!!! tip`/`!!! warning`) are present — placeholders only
    - Both files reference the `_(Inhalt folgt in Plan 34-02)_` / `_(content TBD in Plan 34-03)_` placeholder pattern
  </acceptance_criteria>
  <done>
    Both files exist with identical H2/H3/anchor skeleton, task-first first-20-lines compliance, placeholder bodies. No prose. Structure equality verified by diff.
  </done>
</task>

<task type="auto">
  <name>Task 2: Rewrite index.{de,en}.md Quick Start skeleton (Sync-from-ClubCloud step 1)</name>
  <files>
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.de.md,
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.en.md
  </files>
  <read_first>
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md (D-06, D-06a)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.de.md (current 442-line state)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.en.md (current 442-line state)
  </read_first>
  <action>
    In each index file, locate the existing `## 🚀 Schnellstart: Ihr erstes Turnier in 10 Schritten` / `## 🚀 Quick Start: Your First Tournament in 10 Steps` H2 and replace ONLY that section (from the H2 through the final step line and the `➡️` link that follows) with a new placeholder Quick Start H2.

    **Leave every other section of index.{de,en}.md untouched** (Your Role, Main Topics, etc.). This is a targeted edit, not a full file rewrite.

    **New DE H2 heading and skeleton:**
    ```markdown
    ## 🚀 Schnellstart: Turnier synchronisieren und durchführen in 10 Schritten

    1. **Turnier aus ClubCloud synchronisieren** → _(Inhalt folgt in Plan 34-02)_
    2. _(Schritt 2 — folgt)_
    3. _(Schritt 3 — folgt)_
    4. _(Schritt 4 — folgt)_
    5. _(Schritt 5 — folgt)_
    6. _(Schritt 6 — folgt)_
    7. _(Schritt 7 — folgt)_
    8. _(Schritt 8 — folgt)_
    9. _(Schritt 9 — folgt)_
    10. _(Schritt 10 — folgt)_

    ➡️ **[Zur vollständigen Durchführungs-Anleitung](tournament-management.md#walkthrough)**
    ```

    **New EN H2 heading and skeleton:**
    ```markdown
    ## 🚀 Quick Start: Sync and Run a Tournament in 10 Steps

    1. **Sync tournament from ClubCloud** → _(content TBD in Plan 34-03)_
    2. _(step 2 — TBD)_
    3. _(step 3 — TBD)_
    4. _(step 4 — TBD)_
    5. _(step 5 — TBD)_
    6. _(step 6 — TBD)_
    7. _(step 7 — TBD)_
    8. _(step 8 — TBD)_
    9. _(step 9 — TBD)_
    10. _(step 10 — TBD)_

    ➡️ **[Full walkthrough](tournament-management.md#walkthrough)**
    ```

    **Step 1 wording is NON-NEGOTIABLE (DOC-05):** Must be "Turnier aus ClubCloud synchronisieren" (DE) / "Sync tournament from ClubCloud" (EN). Must NOT contain the words "anlegen" (DE) or "Create" at the start of step 1. The old step 1 was "Turnier anlegen" — that is the exact anti-pattern DOC-05 exists to fix.

    Use the Edit tool for a targeted replacement, OR if the old section is too complex to match reliably, use Read → Write for a full-file rewrite that preserves everything except the Quick Start H2 block.
  </action>
  <verify>
    <automated>
      cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master && \
      grep -q 'Turnier aus ClubCloud synchronisieren' docs/managers/index.de.md && \
      grep -q 'Sync tournament from ClubCloud' docs/managers/index.en.md && \
      ! grep -qE '^\s*1\.\s+\*\*Turnier anlegen\*\*' docs/managers/index.de.md && \
      ! grep -qE '^\s*1\.\s+\*\*Create tournament\*\*' docs/managers/index.en.md && \
      grep -q '## 🚀 Schnellstart' docs/managers/index.de.md && \
      grep -q '## 🚀 Quick Start' docs/managers/index.en.md && \
      grep -q 'tournament-management.md#walkthrough' docs/managers/index.de.md && \
      grep -q 'tournament-management.md#walkthrough' docs/managers/index.en.md
    </automated>
  </verify>
  <acceptance_criteria>
    - `index.de.md` contains a new Quick Start H2 whose step 1 is literally "Turnier aus ClubCloud synchronisieren"
    - `index.en.md` contains a new Quick Start H2 whose step 1 is literally "Sync tournament from ClubCloud"
    - Neither file contains the old `1. **Turnier anlegen**` / `1. **Create tournament**` line
    - Both files link to `tournament-management.md#walkthrough`
    - All other sections of index.{de,en}.md (Your Role, Main Topics, etc.) remain unchanged
  </acceptance_criteria>
  <done>
    Quick Start sections in both index files are replaced with the Sync-from-ClubCloud skeleton; step 1 is correct; the rest of each index file is untouched.
  </done>
</task>

<task type="auto">
  <name>Task 3: Commit the bilingual skeleton gate in carambus_master</name>
  <files>
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md,
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md,
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.de.md,
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.en.md
  </files>
  <read_first>
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.agents/skills/scenario-management/SKILL.md (commit from master, not from api)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md (D-05 hard gate — skeleton commit before any prose)
  </read_first>
  <action>
    Commit all four skeleton files as a SINGLE atomic commit in carambus_master. This commit is the D-05 hard gate: no prose plan (34-02, 34-03) may run until this commit exists.

    ```bash
    cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
    git status docs/managers/tournament-management.de.md docs/managers/tournament-management.en.md docs/managers/index.de.md docs/managers/index.en.md
    git add docs/managers/tournament-management.de.md docs/managers/tournament-management.en.md docs/managers/index.de.md docs/managers/index.en.md
    git commit -m "docs(34-01): bilingual H2/H3 skeleton for task-first rewrite

    Replaces architecture-first intro in tournament-management.{de,en}.md
    with a parallel task-first skeleton: Scenario / Walkthrough (14 steps) /
    Glossary / Troubleshooting / Mehr zur Technik. Anchor slugs are
    English-based (D-05a) so Phase 37 can deep-link from the wizard UI.

    Also replaces the obsolete 'Turnier anlegen' Quick Start in
    index.{de,en}.md with a Sync-from-ClubCloud placeholder (DOC-05).

    Placeholder bodies only — prose content lands in plans 34-02 / 34-03.
    Refs DOC-01, DOC-02, DOC-05."
    git push
    ```

    Run `mkdocs build --strict` from carambus_master BEFORE committing (skeleton is structure-only; should still build cleanly):
    ```bash
    cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
    mkdocs build --strict 2>&1 | tail -20
    ```
    If mkdocs fails with warnings, fix the structure (likely a bad anchor or broken markdown) and rebuild before committing. Common failure: HTML `<a id="...">` tags confusing the slug generator — if so, switch to header-auto-slug convention (no HTML anchors) but keep the English-based anchor slugs achievable via English header text in comments.

    Do NOT commit from carambus_api. Do NOT touch carambus_api/docs/managers/*.md.
  </action>
  <verify>
    <automated>
      cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master && \
      git log -1 --format=%s | grep -q '34-01' && \
      git log -1 --name-only | grep -q 'docs/managers/tournament-management.de.md' && \
      git log -1 --name-only | grep -q 'docs/managers/tournament-management.en.md' && \
      git log -1 --name-only | grep -q 'docs/managers/index.de.md' && \
      git log -1 --name-only | grep -q 'docs/managers/index.en.md' && \
      mkdocs build --strict >/dev/null 2>&1
    </automated>
  </verify>
  <acceptance_criteria>
    - A single commit in carambus_master tip with subject containing "34-01" touches all four skeleton files
    - `mkdocs build --strict` exits 0 after the commit
    - No prose content was added before this commit (verified by grepping the committed files for placeholders)
    - No edits were made to carambus_api/docs/managers/ (verified by `git status` in carambus_api showing no changes under docs/managers/)
  </acceptance_criteria>
  <done>
    Bilingual skeleton committed in carambus_master. mkdocs build strict passes. D-05 gate satisfied.
  </done>
</task>

</tasks>

<threat_model>
Docs-only phase — Markdown rewrites, no new attack surface. N/A.

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-34-01 | N/A | docs/managers/*.md | accept | No code, no user input, no runtime behavior change. mkdocs build is a build-time static-site generator with no secrets. |
</threat_model>

<verification>
- Both tournament-management files have identical heading skeleton (H2/H3 line counts + anchor IDs equal)
- First 20 lines of each tournament-management file are task-focused (contain Scenario H2, no architecture keywords)
- index.{de,en}.md Quick Start step 1 is "Sync tournament from ClubCloud" / "Turnier aus ClubCloud synchronisieren"
- Single commit in carambus_master touches all four files
- `mkdocs build --strict` exits cleanly
</verification>

<success_criteria>
D-05 hard gate satisfied: the bilingual skeleton is committed in carambus_master BEFORE any prose plan starts. Both DE and EN tournament-management files share an identical H2/H3/anchor structure with English-based slugs. Both index files have the corrected Sync-from-ClubCloud Quick Start skeleton. Wave 2 (plans 34-02 and 34-03) is unblocked.
</success_criteria>

<output>
After completion, create `.planning/phases/34-task-first-doc-rewrite/34-01-SUMMARY.md` in carambus_api summarizing:
- Exact anchor slugs committed (list of `id="..."` values)
- Final anchor convention chosen (`<a id="...">` vs header auto-slug)
- mkdocs build --strict result
- Commit SHA in carambus_master
</output>
