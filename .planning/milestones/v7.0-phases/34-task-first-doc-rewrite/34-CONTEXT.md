# Phase 34: Task-First Doc Rewrite - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Rewrite `docs/managers/tournament-management.{de,en}.md` from architecture-first to task-first — a volunteer club officer opening either language file must see a concrete, followable walkthrough of running a synced Karambol tournament from ClubCloud-Meldeliste to final results, not an explanation of Carambus's webservice hierarchy. Both language files share an identical H2/H3/anchor skeleton that is committed BEFORE any prose is written in either. A glossary and a troubleshooting section are added to each language file. The `docs/managers/index.{de,en}.md` Quick Start is corrected from "create a tournament from scratch" (wrong) to "sync a tournament from ClubCloud" (the actual realistic workflow confirmed in Phase 33).

**Out of scope for this phase:** Code changes to the wizard itself (Phase 36), printable quick-reference card (Phase 35), in-app doc links (Phase 37), architecture rewrite in `docs/developers/`. This phase ships MARKDOWN ONLY.

</domain>

<decisions>
## Implementation Decisions

### Architektur-Inhalt (aktuelle ~40 Zeilen Einführung / Struktur / Carambus API)

- **D-01:** The existing architecture sections (`## Einführung`, `## Struktur`, `## Carambus API`) are REMOVED from the opening of `tournament-management.{de,en}.md`. A condensed 2-paragraph "Mehr zur Technik" / "More on the architecture" block is retained at the END of the file (after Walkthrough / Glossary / Troubleshooting) with a link out to `docs/developers/` for volunteers who want to dig deeper. The new opening of the file is the task walkthrough within the first 20 lines, per DOC-01.

### Umgang mit Phase-33 UX-Bugs im Doku-Text

- **D-02:** The walkthrough describes the CURRENT wizard behavior as-is, honestly. Where Phase 33 found a load-bearing UX problem, an inline `!!! tip` or `!!! warning` callout (mkdocs admonition syntax) tells the volunteer what to expect and how to handle it. **Mandatory callouts** (at minimum):
  - **F-19 (invisible transient state):** `!!! warning "Warten, nicht erneut klicken"` — "Nach dem Klick auf **Starte den Turnier Monitor** sieht die Seite mehrere Sekunden lang unverändert aus. Das ist normal — der Wizard bereitet die Tisch-Monitore vor. Klicken Sie nicht erneut."
  - **F-14 (English / garbled labels on start form):** `!!! tip "Englische Feldbezeichnungen"` — "Einige Parameter im Start-Formular heißen derzeit auf Englisch oder sind unklar beschriftet. Das Glossar unten erklärt die wichtigsten Begriffe. Im Zweifel die Standardwerte übernehmen und nach dem Turnier die Einstellungen kontrollieren."
  - **F-09 (no confirmation on finish_seeding):** `!!! warning "Teilnehmerliste abschließen ist endgültig"` — "Der Klick auf **Teilnehmerliste abschließen** ist einmalig und nicht rückgängig zu machen. Prüfen Sie vorher die Teilnehmerliste."
  - **F-12 (mode-selection without explanations):** `!!! tip "Welchen Turnierplan wählen?"` — "Bei der Modus-Auswahl schlägt Carambus meist einen Plan automatisch vor (z.B. T04 bei 5 Teilnehmern). Übernehmen Sie den Vorschlag, wenn Sie nicht bewusst eine Alternative bevorzugen."
- **D-02a:** Every callout in the walkthrough references the corresponding finding ID from `33-UX-FINDINGS.md` in a trailing comment (HTML comment `<!-- ref: F-19 -->`) so that Phase 36, when it fixes the underlying bug, can grep for the callout and remove or update it atomically.

### Glossar-Umfang

- **D-03:** The glossary in both language files contains the **mandated 5** plus **Karambol-Grundwortschatz**:
  - **Mandated (per DOC-03):** ClubCloud, Setzliste (DE) / seeding list (EN), Turniermodus / tournament mode, AASM-Status / tournament status, Scoreboard
  - **Karambol terms:** Freie Partie / Straight Rail, Cadre (35/2, 47/1, 47/2, 71/2) / Balkline, Dreiband / Three-Cushion, Einband / One-Cushion, Aufnahme / inning, Bälle-Ziel / target balls (aka `innings_goal` in the code), Höchstserie (HS) / high run, Generaldurchschnitt (GD) / general average, Spielrunde / playing round, Tisch-Warmup / table warmup
  - **Optional (if space permits):** DBU-Nummer / DBU number, Rangliste / ranking, Turnierplan-Kürzel (T04, T05, Default5) / tournament-plan codes
- **D-03a:** Each glossary entry is 1–2 sentences max, explains the term in volunteer-friendly language, and — where relevant — notes which wizard step the term appears on so the volunteer can cross-reference.

### Walkthrough-Struktur

- **D-04:** The walkthrough follows the ACTUAL Wizard-Schritte at **fine granularity** (10–14 steps mapped 1:1 to the wizard UI), NOT the 6 H2 sections from Phase 33 findings. Target step list (may be refined during planning):
  1. Sie bekommen eine NBV-Einladung (Szenario-Einstieg, keine Klick-Aktion)
  2. Turnier aus der ClubCloud-Meldeliste laden (Schritt 1)
  3. Setzliste aus der offiziellen Einladung übernehmen oder ClubCloud-Meldeliste benutzen (Schritt 2)
  4. Teilnehmerliste prüfen und fehlende Spieler per DBU-Nummer nachtragen (Schritt 3)
  5. Teilnehmerliste abschließen (Schritt 4, mit F-09 callout)
  6. Turniermodus endgültig auswählen (T04/T05/DefaultN, mit F-12 callout)
  7. Turnier-Parameter im Start-Formular ausfüllen (mit F-14 callout)
  8. Tische zuordnen
  9. Turnier starten (mit F-19 callout)
  10. Warmup-Phase beobachten
  11. Spielbeginn für jede Partie freigeben
  12. Ergebnisse während des Turniers mitverfolgen
  13. Turnier nach Abschluss der letzten Runde finalisieren
  14. Nach dem Turnier: Ergebnis-Upload nach ClubCloud (falls aktiviert)
- **D-04a:** The walkthrough is embedded in a **generic NBV scenario framing**: "Sie haben eine NBV-Einladung für eine NDM Freie Partie Klasse 1–3 erhalten — so führen Sie das Turnier von A bis Z durch." No specific tournament ID, no specific date in the prose. Generic example data only. (Phase 33's concrete tournament 17403 stays in the CONTEXT.md / UX-FINDINGS.md, not in the user-facing docs.)

### Bilingual Skeleton Gate (from DOC-02)

- **D-05:** The plan MUST deliver the bilingual H2/H3/anchor skeleton as its FIRST commit — before any prose is written in either language. Skeleton commit contains identical H2/H3 structure and identical anchor slugs in both DE and EN files, with placeholder bodies (e.g., `_(Walkthrough folgt)_` / `_(walkthrough TBD)_`). Content commits happen AFTER the skeleton is locked. This is a hard gate: any plan that writes prose before the skeleton is committed violates DOC-02.
- **D-05a:** Anchor slugs are **English-based** in both files (e.g., `#walkthrough`, `#glossary`, `#troubleshooting`, `#sync-from-clubcloud`) so that Phase 37 (`LINK-04`) can deep-link from the wizard UI without needing per-locale anchor maps. Header text is translated; anchors are not.

### Index Quick Start Rewrite (DOC-05)

- **D-06:** `docs/managers/index.{de,en}.md` "Schnellstart: 10 Schritte" / "Quick Start: 10 steps" is rewritten to match the walkthrough from D-04. New Quick Start leads with **"Turnier aus ClubCloud synchronisieren"** / **"Sync tournament from ClubCloud"** as step 1 — NOT "Turnier anlegen" / "Create tournament". The 10 steps in the index are a condensed teaser version of the walkthrough (links to the full walkthrough anchors).
- **D-06a:** Both DE and EN index files must match in step count and wording pattern. The current 10-step list in `index.de.md` is entirely replaced; `index.en.md` receives the translation.

### Troubleshooting Section (DOC-04)

- **D-07:** The troubleshooting section uses a **Problem / Ursache / Lösung** (Problem / Cause / Fix) subsection format, one H3 per failure case. The 4 mandated cases (in order):
  1. Einladungs-PDF konnte nicht hochgeladen werden / Invitation upload failed
  2. Spieler ist nicht in der ClubCloud-Meldeliste / Player not in ClubCloud
  3. Falscher Turniermodus ausgewählt / Wrong mode selected
  4. Turnier wurde bereits gestartet / Tournament already started
- **D-07a:** Each case includes the symptom the volunteer sees, the likely root cause grounded in Phase 33 findings (e.g., "ClubCloud sync delivered only 1 player — siehe F-03/F-04"), and a concrete recovery step. Where the fix requires a feature that doesn't exist yet, the doc says so honestly and points to the backlog.

### Claude's Discretion

- Exact prose tone (formal "Sie" vs "Du"). **Guidance:** prefer "Sie" for DE — matches the 2-3x/year volunteer persona and German administrative norms.
- Bilingual translation workflow. **Guidance:** use `DeeplTranslationService` for first-pass EN draft from DE source, then human polish (or vice-versa). Project already has `AiTranslationService` and `OpenaiTranslationService` for terminology consistency.
- Whether to include any screenshots in the docs. **Guidance:** reuse 2–3 key screenshots from `.planning/phases/33-ux-review-wizard-audit/screenshots/` (specifically the wizard overview, the mode selection page, and the post-start Tournament Monitor landing) — don't capture fresh ones for this phase. Copy into `docs/managers/images/` or similar.
- Exact anchor slug wording within the agreed English-based convention.
- Whether the troubleshooting section lives as part of `tournament-management.{de,en}.md` or as a separate file. **Guidance:** same file, per DOC-04 which says "A troubleshooting section exists in both language files" — implies in-file.
- Whether the glossary is alphabetical or grouped by category (Karambol vs Wizard vs System). **Guidance:** grouped — easier to scan for a 2-3x/year user.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements

- `.planning/ROADMAP.md` — Phase 34 section: goal, success criteria, DOC-01..DOC-05 mapping
- `.planning/REQUIREMENTS.md` — DOC-01 (task-first rewrite), DOC-02 (bilingual skeleton gate), DOC-03 (glossary), DOC-04 (troubleshooting), DOC-05 (index Quick Start correction)
- `.planning/PROJECT.md` — v7.0 Manager Experience milestone framing, volunteer persona filter, "Code and docs stay in sync" Core Value

### Phase 33 output — THE authoritative spec for wizard behavior

- `.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md` — 24 classified findings (F-01..F-24), canonical wizard partial (UX-01), transient state behavior (UX-02), tier classification (UX-03), happy-path action list (UX-04). The walkthrough in Phase 34 is the prose version of this file.
- `.planning/phases/33-ux-review-wizard-audit/33-CONTEXT.md` — Phase 33 locked decisions about scenario (`carambus_bcw`, LOCAL context, global/synced carom tournament), LocalProtector carve-outs
- `.planning/phases/33-ux-review-wizard-audit/screenshots/` — 11 PNGs including `01-show-initial.png` (wizard overview), `02c-added-players-edit-seeding.png` (Teilnehmerliste with auto-suggest), `04a-mode-selection.png` (mode alternatives), `05-start-form.png` (start parameters), `07-start-after.png` (Tournament Monitor landing). Reuse 2–3 per D-04 Claude's Discretion.

### Existing docs to be rewritten

- `docs/managers/tournament-management.de.md` — 316 lines, current architecture-first state; target of full rewrite
- `docs/managers/tournament-management.en.md` — 316 lines, current architecture-first state; target of full rewrite
- `docs/managers/index.de.md` — 442 lines, Quick Start at §"Schnellstart: Ihr erstes Turnier in 10 Schritten" (~line 15–27); Quick Start targeted by DOC-05
- `docs/managers/index.en.md` — 442 lines, same structure; Quick Start targeted by DOC-05

### Related existing docs (for cross-linking and context, not rewrite targets)

- `docs/managers/clubcloud-integration.de.md` — ClubCloud sync context, link target from new Quick Start
- `docs/managers/clubcloud-integration.en.md`
- `docs/managers/single-tournament.de.md` — existing single-tournament guide; check for overlap with new walkthrough
- `docs/managers/single-tournament.en.md`
- `mkdocs.yml` — nav structure, `nav_translations` for DE labels; no structural changes expected for Phase 34 but must still pass `mkdocs build --strict`

### Code the walkthrough describes (read-only for Phase 34 — no modifications)

- `app/views/tournaments/show.html.erb` §line 35 — canonical `render 'wizard_steps_v2'` call
- `app/views/tournaments/_wizard_steps_v2.html.erb` — canonical wizard partial (confirmed Phase 33)
- `app/controllers/tournaments_controller.rb` — happy-path actions at lines 107 (finish_seeding), 288 (start), 415 (transient check), 428 (new), 433 (edit), 436 (create)
- `app/models/tournament.rb` §lines 276–295 — `tournament_started_waiting_for_monitors` AASM state

### Translation / i18n

- `app/services/deepl_translation_service.rb` — DeepL integration, available for parallel DE/EN authoring
- `app/services/ai_translation_service.rb` — AI-backed translation with terminology guidance
- `config/locales/de.yml` — DE locale (NOT rewritten in Phase 34; referenced only because F-14 documents missing/broken keys on the start form)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Phase 33 findings file** is the primary input — 24 findings with Tier/Gate already classified. The planner doesn't need to re-derive what the wizard does; it just needs to translate the findings into prose and attach callouts.
- **Phase 33 screenshots** are ready-to-use. Reuse 2–3 key shots in the docs under `docs/managers/images/` (or similar mkdocs-compatible path).
- **`DeeplTranslationService` / `AiTranslationService`** enable automated first-draft translation between DE and EN, which keeps the bilingual skeleton + prose in sync without duplicate authoring effort.
- **mkdocs admonition syntax** (`!!! tip`, `!!! warning`) is already used elsewhere in `docs/managers/` — volunteer-friendly callout pattern is established.

### Established Patterns

- **Bilingual file convention:** `**/foo.{de,en}.md` with mkdocs-multilang plugin. Anchors are typically English-based across both locales for deep-linking consistency.
- **Documentation lives in carambus_master, not carambus_api:** per the scenario-management skill, code and docs changes both go through carambus_master. Phase 34's commits happen in carambus_api's `.planning/` (GSD artifacts) but the actual docs changes must be made in carambus_master/docs/ and pulled into carambus_api via the normal sync workflow. **Heads-up for the planner: this is a cross-checkout change.**
- **v6.0 just shipped documentation repair:** 75 broken links fixed, 8 namespace overview pages, 35-service developer guide, zero mkdocs strict warnings. Phase 34 must not regress `mkdocs build --strict`.
- **mkdocs.yml nav_translations** already configured for DE labels. No nav changes expected for Phase 34 (existing files are being rewritten, not added).

### Integration Points

- **Phase 35 (Quick Reference Card)** will create new files `docs/managers/tournament-quick-reference.{de,en}.md` with a Before/During/After checklist — its content is a condensed version of Phase 34's walkthrough. Phase 35 depends on Phase 34's anchors being stable.
- **Phase 36 (Small UX Fixes)** will fix some of the UX problems that Phase 34's callouts document (F-09, F-14, F-19, F-12). When Phase 36 ships, the corresponding callouts in Phase 34's docs become obsolete and should be removed. D-02a enforces the `<!-- ref: F-NN -->` comment convention so Phase 36 can grep for them.
- **Phase 37 (In-App Doc Links)** will make wizard UI steps deep-link into this phase's walkthrough anchors. D-05a (English anchor slugs) enables this.

</code_context>

<specifics>
## Specific Ideas

- The walkthrough should feel like "I'm sitting next to a volunteer on tournament day, telling them what to click and what to watch for" — not "here's a formal manual."
- Use `!!! tip` for helpful hints and `!!! warning` for irreversible or confusing moments. Match admonition style to existing docs in `docs/managers/`.
- The scenario framing (NBV Freie Partie Klasse 1–3) is meant to feel familiar to a BCW-type volunteer without being so specific that it becomes outdated.
- The glossary entries should say "Sie sehen diesen Begriff in Schritt N" where applicable, so a volunteer reading a callout can jump to the glossary and back to context.

</specifics>

<deferred>
## Deferred Ideas

- **Fresh screenshots or screen recordings** — reuse Phase 33's shots (D-04 discretion). A separate "visual refresh" phase can revisit later.
- **Phase 36 UX fixes that obsolete the callouts** — Phase 36 scope, not Phase 34.
- **In-app deep-linking from wizard steps to docs anchors** — Phase 37 (LINK-01..LINK-04).
- **Printable quick-reference card (A4, before/during/after checklist)** — Phase 35 (QREF-01..QREF-03).
- **Docs versioning** for multi-version Carambus installs (older scenarios running older Carambus) — out of v7.0 scope.
- **Video walkthrough / onboarding tour** — project-level Out of Scope per PROJECT.md.
- **Undo on finish_seeding** (Phase 33 F-09 suggests a confirmation dialog; an undo would be stronger but is explicitly Out of Scope per REQUIREMENTS.md "Undo-on-finalize" in v7.0 Out of Scope).
- **Rewrite of `docs/managers/single-tournament.{de,en}.md`** — potentially overlaps with the new walkthrough. If overlap is heavy, a later phase can deduplicate. Phase 34 leaves it alone.
- **Rewrite of `docs/managers/league-management.{de,en}.md`** — league workflow is different and not in v7.0 scope.

</deferred>

---

*Phase: 34-task-first-doc-rewrite*
*Context gathered: 2026-04-13*
