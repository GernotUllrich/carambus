---
phase: 34-task-first-doc-rewrite
plan: 04
type: execute
wave: 3
depends_on:
  - 34-01
  - 34-02
  - 34-03
files_modified:
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images/tournament-wizard-overview.png
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images/tournament-wizard-mode-selection.png
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images/tournament-monitor-landing.png
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md
autonomous: true
requirements:
  - DOC-01
  - DOC-02
  - DOC-03
  - DOC-04
  - DOC-05
must_haves:
  truths:
    - "2–3 reused Phase 33 screenshots are embedded in both tournament-management.de.md and tournament-management.en.md at the relevant walkthrough steps"
    - "`mkdocs build --strict` passes with zero warnings after all Phase 34 content is in place"
    - "All 5 Phase 34 success criteria (ROADMAP.md Phase 34 §Success Criteria 1–5) are grep-verifiable as TRUE"
    - "Structural parity between DE and EN tournament-management files holds: identical H2/H3/anchor structure AND equal anchor count"
  artifacts:
    - path: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images/
      provides: "Screenshots directory containing 2–3 reused Phase 33 PNGs"
      min_files: 2
    - path: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md
      provides: "DE walkthrough with embedded screenshot references"
      contains: "images/"
    - path: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md
      provides: "EN walkthrough with embedded screenshot references"
      contains: "images/"
  key_links:
    - from: tournament-management.{de,en}.md walkthrough steps
      to: docs/managers/images/*.png
      via: markdown image references with relative paths
      pattern: "!\\[.*\\]\\(images/"
    - from: all Phase 34 commits (34-01, 34-02, 34-03, 34-04)
      to: mkdocs build --strict passing
      via: clean strict build at HEAD of carambus_master
      pattern: "mkdocs build --strict exit 0"
---

<objective>
Copy 2–3 reused Phase 33 screenshots into `carambus_master/docs/managers/images/`, embed them at the relevant walkthrough steps in both language files, then run the final strict mkdocs build and grep-verify all 5 Phase 34 success criteria end-to-end.

Purpose: Close the phase. This is the "green light" plan — if all checks pass, Phase 34 is shippable.

Output: Screenshots committed; image references added to both language walkthroughs; mkdocs build --strict zero-warning result; grep-validated success criteria report in the SUMMARY.md.
</objective>

<execution_context>
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/workflows/execute-plan.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/templates/summary.md

## Cross-checkout constraint (MANDATORY)

All file operations in this plan target `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/`. Screenshots are copied FROM `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/33-ux-review-wizard-audit/screenshots/` INTO `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images/`.

Commit from carambus_master. GSD SUMMARY.md lands in carambus_api.

## Gate check before starting

This plan depends on 34-01, 34-02, AND 34-03. All three commits must exist in carambus_master:

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
git log --oneline -30 | grep -E '34-01|34-02|34-03' | wc -l  # should be ≥ 3
```

If fewer than 3 prerequisite commits are present, STOP — the prose is incomplete and this validation plan cannot meaningfully run.
</execution_context>

<context>
@.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md
@.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md

# Phase 33 screenshots directory (source of reused images)
@.planning/phases/33-ux-review-wizard-audit/screenshots/

# Current state of files after plans 34-01, 34-02, 34-03
@docs/managers/tournament-management.de.md
@docs/managers/tournament-management.en.md
</context>

<interfaces>
<!-- Screenshot selection (per D-04 Claude's discretion — locked to 3 shots) -->

## Reused screenshots (3 files, consistent target names)

| Source (Phase 33) | Target (Phase 34) | Used at step |
|---|---|---|
| `.planning/phases/33-ux-review-wizard-audit/screenshots/01-show-initial.png` | `docs/managers/images/tournament-wizard-overview.png` | Step 2 — Load tournament from ClubCloud |
| `.planning/phases/33-ux-review-wizard-audit/screenshots/04a-mode-selection.png` | `docs/managers/images/tournament-wizard-mode-selection.png` | Step 6 — Select tournament mode |
| `.planning/phases/33-ux-review-wizard-audit/screenshots/07-start-after.png` | `docs/managers/images/tournament-monitor-landing.png` | Step 10 — Warmup phase |

## Markdown image embed format

Use relative paths from the markdown file to the images directory. Both tournament-management files live in `docs/managers/` and images live in `docs/managers/images/`, so the relative path is `images/<filename>`.

**DE file format:**
```markdown
![Wizard-Übersicht mit Schritt 2 aktiv](images/tournament-wizard-overview.png){ loading=lazy }
*Screenshot: Wizard-Übersicht nach dem ClubCloud-Sync (Phase 33, NDM Freie Partie Klasse 1–3)*
```

**EN file format:**
```markdown
![Wizard overview with Step 2 active](images/tournament-wizard-overview.png){ loading=lazy }
*Screenshot: Wizard overview after ClubCloud sync (Phase 33, NDM Freie Partie Class 1–3)*
```

The `{ loading=lazy }` attribute is part of the mkdocs-material image extension — include it if the theme supports it; drop it if `mkdocs build --strict` complains.

## Success criteria grep recipe (used in Task 3 — end-to-end validation)

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master

# Success criterion 1: First 20 lines are task-first (no architecture keywords)
head -20 docs/managers/tournament-management.de.md | grep -qiE '(Einführung|Struktur|Carambus API)' && echo "FAIL SC1-DE" || echo "OK SC1-DE"
head -20 docs/managers/tournament-management.en.md | grep -qiE '(Introduction|Structure|Carambus API )' && echo "FAIL SC1-EN" || echo "OK SC1-EN"

# Success criterion 2: DE and EN have identical H2/H3/anchor skeleton
diff <(grep -E '^<a id=' docs/managers/tournament-management.de.md) <(grep -E '^<a id=' docs/managers/tournament-management.en.md) >/dev/null && echo "OK SC2" || echo "FAIL SC2"

# Success criterion 3: Glossary has all 5 mandated terms (DE and EN)
for term in ClubCloud Setzliste Turniermodus AASM Scoreboard; do
  grep -q "$term" docs/managers/tournament-management.de.md || echo "FAIL SC3-DE: $term"
done
for term in ClubCloud 'seeding list' 'tournament mode' AASM Scoreboard; do
  grep -qi "$term" docs/managers/tournament-management.en.md || echo "FAIL SC3-EN: $term"
done

# Success criterion 4: Troubleshooting has all 4 mandated cases
for anchor in ts-invitation-upload ts-player-not-in-cc ts-wrong-mode ts-already-started; do
  grep -q "id=\"$anchor\"" docs/managers/tournament-management.de.md || echo "FAIL SC4-DE: $anchor"
  grep -q "id=\"$anchor\"" docs/managers/tournament-management.en.md || echo "FAIL SC4-EN: $anchor"
done

# Success criterion 5: Index Quick Start is Sync-from-ClubCloud workflow
grep -q 'Turnier aus ClubCloud synchronisieren' docs/managers/index.de.md && echo "OK SC5-DE" || echo "FAIL SC5-DE"
grep -q 'Sync tournament from ClubCloud' docs/managers/index.en.md && echo "OK SC5-EN" || echo "FAIL SC5-EN"
! grep -qE '1\.\s+\*\*Turnier anlegen\*\*' docs/managers/index.de.md || echo "FAIL SC5-DE: old step still present"
! grep -qE '1\.\s+\*\*Create tournament\*\*' docs/managers/index.en.md || echo "FAIL SC5-EN: old step still present"

# Bonus: mkdocs build --strict
mkdocs build --strict 2>&1 | tail -5
```
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Copy 3 Phase 33 screenshots into docs/managers/images/</name>
  <files>
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images/tournament-wizard-overview.png,
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images/tournament-wizard-mode-selection.png,
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images/tournament-monitor-landing.png
  </files>
  <read_first>
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md (Claude's discretion on screenshots)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md (screenshot filenames)
  </read_first>
  <action>
    Create the `docs/managers/images/` directory in carambus_master if it does not exist, then copy 3 Phase 33 screenshots with the target filenames from the `<interfaces>` block:

    ```bash
    mkdir -p /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images
    cp /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/33-ux-review-wizard-audit/screenshots/01-show-initial.png \
       /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images/tournament-wizard-overview.png
    cp /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/33-ux-review-wizard-audit/screenshots/04a-mode-selection.png \
       /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images/tournament-wizard-mode-selection.png
    cp /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/33-ux-review-wizard-audit/screenshots/07-start-after.png \
       /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images/tournament-monitor-landing.png
    ```

    Verify each source file exists before copying. If a source file is missing (schema drift from Phase 33), log the gap and either pick a substitute from `.planning/phases/33-ux-review-wizard-audit/screenshots/` that visually matches the intended step OR reduce to 2 screenshots and document the deviation in the SUMMARY.

    Do not modify the original screenshots in carambus_api — those are Phase 33 artifacts.
  </action>
  <verify>
    <automated>
      test -f /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images/tournament-wizard-overview.png && \
      test -f /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images/tournament-wizard-mode-selection.png && \
      test -f /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images/tournament-monitor-landing.png
    </automated>
  </verify>
  <acceptance_criteria>
    - `docs/managers/images/` directory exists in carambus_master
    - Three target PNGs exist with the filenames from the interface block
    - Original Phase 33 screenshots in carambus_api are unchanged
  </acceptance_criteria>
  <done>
    Three screenshots copied into docs/managers/images/ with the correct target filenames.
  </done>
</task>

<task type="auto">
  <name>Task 2: Embed screenshot references at walkthrough Steps 2, 6, 10 (both languages)</name>
  <files>
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md,
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md
  </files>
  <read_first>
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md (post-34-02 state with walkthrough prose)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md (post-34-03 state with walkthrough prose)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md (screenshot placement guidance)
  </read_first>
  <action>
    Add markdown image embeds at three locations in each language file. Use the format from the `<interfaces>` block (DE vs EN captions differ).

    **Placement locations (find by `<a id="step-N-*">` anchor):**
    - `#step-2-load-clubcloud` (Step 2) — embed `tournament-wizard-overview.png`, immediately after the step's closing prose paragraph, before the next H3
    - `#step-6-mode-selection` (Step 6) — embed `tournament-wizard-mode-selection.png`
    - `#step-10-warmup` (Step 10) — embed `tournament-monitor-landing.png`

    **DE embed (example for Step 2):**
    ```markdown
    ![Wizard-Übersicht nach ClubCloud-Sync](images/tournament-wizard-overview.png){ loading=lazy }
    *Abbildung: Turnier-Setup-Wizard direkt nach dem ClubCloud-Sync (Beispiel aus der Phase-33-Audit, NDM Freie Partie Klasse 1–3).*
    ```

    **EN embed (example for Step 2):**
    ```markdown
    ![Wizard overview after ClubCloud sync](images/tournament-wizard-overview.png){ loading=lazy }
    *Figure: Tournament setup wizard right after ClubCloud sync (example from the Phase 33 audit, NDM Freie Partie Class 1–3).*
    ```

    Similarly at Step 6 (mode selection) and Step 10 (tournament monitor landing) with step-appropriate captions.

    **If `{ loading=lazy }` causes mkdocs strict-mode warnings**, drop the attribute and use a plain `![alt](path)` embed. Run `mkdocs build --strict` inside this task to verify image placement doesn't break the build, before moving on to Task 3.

    Use the Edit tool for targeted insertions; find the step's `<a id="step-N-*">` anchor + H3 header as the anchor pattern and insert the image block at the end of the step's body.
  </action>
  <verify>
    <automated>
      cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master && \
      grep -c 'images/tournament-wizard-overview.png' docs/managers/tournament-management.de.md | awk '$1>=1{exit 0} {exit 1}' && \
      grep -c 'images/tournament-wizard-mode-selection.png' docs/managers/tournament-management.de.md | awk '$1>=1{exit 0} {exit 1}' && \
      grep -c 'images/tournament-monitor-landing.png' docs/managers/tournament-management.de.md | awk '$1>=1{exit 0} {exit 1}' && \
      grep -c 'images/tournament-wizard-overview.png' docs/managers/tournament-management.en.md | awk '$1>=1{exit 0} {exit 1}' && \
      grep -c 'images/tournament-wizard-mode-selection.png' docs/managers/tournament-management.en.md | awk '$1>=1{exit 0} {exit 1}' && \
      grep -c 'images/tournament-monitor-landing.png' docs/managers/tournament-management.en.md | awk '$1>=1{exit 0} {exit 1}' && \
      mkdocs build --strict >/dev/null 2>&1
    </automated>
  </verify>
  <acceptance_criteria>
    - Each of the three image paths appears at least once in the DE walkthrough
    - Each of the three image paths appears at least once in the EN walkthrough
    - `mkdocs build --strict` exits 0 after image embeds
  </acceptance_criteria>
  <done>
    All three screenshots are embedded at their designated walkthrough steps in both languages; mkdocs build --strict still passes.
  </done>
</task>

<task type="auto">
  <name>Task 3: End-to-end success-criteria validation + final commit</name>
  <files>
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md,
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md,
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.de.md,
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.en.md,
    /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/images/
  </files>
  <read_first>
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/ROADMAP.md (Phase 34 §Success Criteria — the 5 criteria this plan verifies)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/REQUIREMENTS.md (DOC-01..DOC-05)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md (all locked decisions — verify no silent reductions)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md (final state)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md (final state)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.de.md (final state)
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.en.md (final state)
  </read_first>
  <action>
    Run the full success-criteria validation recipe from the `<interfaces>` block. Produce a validation report as part of the commit message AND as the basis for the SUMMARY.md output.

    **Step 1: Run the 5-criterion validation recipe.**

    Execute each grep command from the `<interfaces>` Success criteria section. Record OK/FAIL for each of SC1-DE, SC1-EN, SC2, SC3-DE, SC3-EN (for each of 5 mandated terms), SC4-DE, SC4-EN (for each of 4 anchors), SC5-DE, SC5-EN.

    **Step 2: Run additional decision-coverage grep checks.**

    Verify every locked decision from CONTEXT.md has an observable footprint:

    ```bash
    cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master

    # D-01: architecture content moved to tail, not at top
    head -20 docs/managers/tournament-management.de.md | grep -qiE '(Einführung|Struktur|Carambus API)' && echo "FAIL D-01-DE top"
    tail -50 docs/managers/tournament-management.de.md | grep -q 'Mehr zur Technik\|id="architecture"' || echo "FAIL D-01-DE tail"
    tail -50 docs/managers/tournament-management.de.md | grep -q 'developers' || echo "FAIL D-01-DE developers link"

    # D-02 / D-02a: 4 mandatory callouts with ref comments
    for ref in F-09 F-12 F-14 F-19; do
      grep -q "<!-- ref: $ref -->" docs/managers/tournament-management.de.md || echo "FAIL D-02a-DE: $ref"
      grep -q "<!-- ref: $ref -->" docs/managers/tournament-management.en.md || echo "FAIL D-02a-EN: $ref"
    done

    # D-03: 5 mandated + Karambol terms (sample)
    for term in 'Freie Partie' Cadre Dreiband Einband Aufnahme 'Höchstserie' 'Generaldurchschnitt' Spielrunde 'Tisch-Warmup'; do
      grep -q "$term" docs/managers/tournament-management.de.md || echo "FAIL D-03-DE: $term"
    done

    # D-04: walkthrough has 14 steps
    grep -c 'id="step-' docs/managers/tournament-management.de.md
    grep -c 'id="step-' docs/managers/tournament-management.en.md

    # D-05: structural parity
    diff <(grep -E '^<a id=' docs/managers/tournament-management.de.md) <(grep -E '^<a id=' docs/managers/tournament-management.en.md)

    # D-06: index Quick Start step 1 = Sync-from-ClubCloud
    grep -q 'Turnier aus ClubCloud synchronisieren' docs/managers/index.de.md || echo "FAIL D-06-DE"
    grep -q 'Sync tournament from ClubCloud' docs/managers/index.en.md || echo "FAIL D-06-EN"

    # D-07: 4 troubleshooting cases in both files
    for anchor in ts-invitation-upload ts-player-not-in-cc ts-wrong-mode ts-already-started; do
      grep -q "id=\"$anchor\"" docs/managers/tournament-management.de.md || echo "FAIL D-07-DE: $anchor"
      grep -q "id=\"$anchor\"" docs/managers/tournament-management.en.md || echo "FAIL D-07-EN: $anchor"
    done
    ```

    If any FAIL lines appear, STOP — return the failures to the orchestrator as a structured error. Do not proceed to commit.

    **Step 3: Final strict mkdocs build.**

    ```bash
    cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
    mkdocs build --strict 2>&1 | tee /tmp/mkdocs-34-final.log
    ```

    Exit code must be 0 and no WARNING lines in the output. If there are warnings, fix them (most likely: broken anchor in a cross-link, missing image alt, or a dangling `[...](link)` that resolves to nothing).

    **Step 4: Commit the screenshot assets + image embeds.**

    ```bash
    cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
    git add docs/managers/images/ \
            docs/managers/tournament-management.de.md \
            docs/managers/tournament-management.en.md
    git commit -m "docs(34-04): reuse Phase 33 screenshots + final validation

    Adds 3 reused Phase 33 screenshots (wizard overview, mode selection,
    tournament monitor landing) under docs/managers/images/, embedded at
    walkthrough steps 2, 6, and 10 in both language files. Runs the full
    Phase 34 success-criteria validation grep-recipe — all 5 criteria
    pass, mkdocs build --strict is clean.

    Closes DOC-01, DOC-02, DOC-03, DOC-04, DOC-05."
    git push
    ```

    **Step 5: Record validation output for the SUMMARY.**

    Capture the full validation-recipe output into the SUMMARY.md under a `## Validation Report` section. The SUMMARY.md file lives in carambus_api (`.planning/phases/34-task-first-doc-rewrite/34-04-SUMMARY.md`), NOT in carambus_master. That file is committed separately via the api git workflow by the orchestrator.
  </action>
  <verify>
    <automated>
      cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master && \
      ! head -20 docs/managers/tournament-management.de.md | grep -qiE '(Einführung|Struktur|Carambus API)' && \
      ! head -20 docs/managers/tournament-management.en.md | grep -qiE '(Introduction|Structure|Carambus API )' && \
      diff <(grep -E '^<a id=' docs/managers/tournament-management.de.md) <(grep -E '^<a id=' docs/managers/tournament-management.en.md) && \
      grep -q 'ClubCloud' docs/managers/tournament-management.de.md && \
      grep -q 'Setzliste' docs/managers/tournament-management.de.md && \
      grep -q 'Turniermodus' docs/managers/tournament-management.de.md && \
      grep -q 'AASM' docs/managers/tournament-management.de.md && \
      grep -q 'Scoreboard' docs/managers/tournament-management.de.md && \
      grep -q 'ClubCloud' docs/managers/tournament-management.en.md && \
      grep -qi 'seeding list' docs/managers/tournament-management.en.md && \
      grep -qi 'tournament mode' docs/managers/tournament-management.en.md && \
      grep -q 'AASM' docs/managers/tournament-management.en.md && \
      grep -q 'Scoreboard' docs/managers/tournament-management.en.md && \
      grep -q 'id="ts-invitation-upload"' docs/managers/tournament-management.de.md && \
      grep -q 'id="ts-player-not-in-cc"' docs/managers/tournament-management.de.md && \
      grep -q 'id="ts-wrong-mode"' docs/managers/tournament-management.de.md && \
      grep -q 'id="ts-already-started"' docs/managers/tournament-management.de.md && \
      grep -q 'id="ts-invitation-upload"' docs/managers/tournament-management.en.md && \
      grep -q 'id="ts-player-not-in-cc"' docs/managers/tournament-management.en.md && \
      grep -q 'id="ts-wrong-mode"' docs/managers/tournament-management.en.md && \
      grep -q 'id="ts-already-started"' docs/managers/tournament-management.en.md && \
      grep -q 'Turnier aus ClubCloud synchronisieren' docs/managers/index.de.md && \
      grep -q 'Sync tournament from ClubCloud' docs/managers/index.en.md && \
      ! grep -qE '1\.\s+\*\*Turnier anlegen\*\*' docs/managers/index.de.md && \
      ! grep -qE '1\.\s+\*\*Create tournament\*\*' docs/managers/index.en.md && \
      mkdocs build --strict 2>&1 | grep -vE '^(INFO|Cleaning|Documentation built)' | grep -iE 'warning|error' | wc -l | awk '$1==0{exit 0} {exit 1}' && \
      git log -1 --format=%s | grep -q '34-04'
    </automated>
  </verify>
  <acceptance_criteria>
    - Success criterion 1 (task-first first 20 lines): passes for both DE and EN
    - Success criterion 2 (identical heading skeleton): diff empty between DE and EN `<a id=` lines
    - Success criterion 3 (glossary 5 mandated terms): all 5 present in both languages
    - Success criterion 4 (troubleshooting 4 cases): all 4 anchor IDs present in both languages
    - Success criterion 5 (index Quick Start Sync-from-ClubCloud): correct step 1 in both; old "Turnier anlegen"/"Create tournament" absent
    - `mkdocs build --strict` output contains zero lines matching `warning|error` (case-insensitive)
    - A single commit in carambus_master with "34-04" in the subject touches images/ and both tournament-management files
  </acceptance_criteria>
  <done>
    All 5 Phase 34 success criteria verified as TRUE via grep recipe. mkdocs build --strict clean. Screenshot assets and embeds committed. Phase 34 is shippable.
  </done>
</task>

</tasks>

<threat_model>
Docs-only phase — Markdown rewrites + static PNG assets copied from an internal planning directory to the docs site. No user input, no network calls, no secrets. N/A.

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-34-04 | N/A | docs/managers/images/*.png | accept | Screenshots are internal Phase 33 audit artifacts — they contain a dev-DB tournament (17403, NDM Freie Partie Klasse 1–3) with player names from the synced ClubCloud. These names are already public via ClubCloud/NBV; no new PII surface. |
</threat_model>

<verification>
- 3 screenshots exist in docs/managers/images/
- 3 image references exist in each of tournament-management.{de,en}.md
- All 5 Phase 34 success criteria from ROADMAP.md Phase 34 §Success Criteria pass grep-verification
- `mkdocs build --strict` produces zero warnings
- Phase 34 commit sequence in carambus_master: 34-01 (skeleton) → 34-02 (DE prose) → 34-03 (EN prose) → 34-04 (screenshots + validate)
</verification>

<success_criteria>
All 5 Phase 34 success criteria from ROADMAP.md hold as TRUE under grep verification. Every locked decision D-01..D-07 has an observable footprint in the committed files. Phase 34 is complete and ready for commit to roadmap status "[x] complete".
</success_criteria>

<output>
After completion, create `.planning/phases/34-task-first-doc-rewrite/34-04-SUMMARY.md` in carambus_api containing:
- Screenshot filenames copied and their source → target mapping
- Full grep validation-recipe output (OK/FAIL per criterion)
- mkdocs build --strict final log (last 20 lines)
- Commit SHA in carambus_master for 34-04
- List of all 4 Phase 34 commits in carambus_master (34-01, 34-02, 34-03, 34-04) with SHAs and subject lines
- Phase 34 completion checklist: every DOC-01..DOC-05 requirement marked complete
</output>
