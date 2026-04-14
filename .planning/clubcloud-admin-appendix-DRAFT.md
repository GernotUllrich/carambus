# DRAFT: ClubCloud Admin-Side Handling — Walkthrough Appendix

**Status:** DRAFT — produced during Phase 36c (2026-04-14, v7.0)
**Intended destination:** `docs/managers/tournament-management.de.md` appendix (and `.en.md` counterpart), section titled "ClubCloud admin-side handling" or similar
**Referenced by:** Phase 36a DOC-ACC-04 — the Phase 36a appendix work identified this as a missing section but deferred the actual writing to Phase 36c because it requires SME-sourced organizational content, not Carambus-sourced technical content.

> **This is a draft.** The content below is what could be inferred
> during Phase 36c from the v7.0 review notes and existing docs. Every
> item marked **[SME-CONFIRM]** needs human verification from the
> Carambus SME before this draft can be promoted to `docs/managers/`.
> Promoting happens during v7.1 Phase F (see
> `.planning/milestones/v7.1-ROADMAP.md`) or as a standalone doc task
> before v7.1 starts, whichever is earlier.

---

## Why this appendix exists

Carambus is a workflow tool for running carom billiards tournaments,
but the authoritative player database and the authoritative ranking
archive live in **ClubCloud** (CC). Every Carambus tournament that
belongs to a recognized league or association eventually produces
data that has to land in CC in a form CC accepts. The walkthrough's
main body describes the Carambus-side actions the Turnierleiter
performs. This appendix describes what happens on the **ClubCloud
side** that the Turnierleiter either triggers indirectly or has to
coordinate with someone else.

The reason this is its own appendix and not scattered through the
main walkthrough: the CC-side operations depend on **ClubCloud roles
and permissions**, not on Carambus state, and the same Turnierleiter
may have full rights for one tournament and restricted rights for
another. Understanding the role model is a prerequisite for
understanding any CC-adjacent workflow.

## The ClubCloud role model

ClubCloud distinguishes several roles that matter for tournament
workflows. **[SME-CONFIRM]** the exact role names and the exact
permission boundaries — the table below is a best-effort
reconstruction from the Phase 36 review notes (F-36-23) and should
not be treated as authoritative.

| Role | Typical holder | CC permissions relevant to tournaments |
|------|----------------|----------------------------------------|
| **Club-Sportwart** | The sports officer of the hosting club | Can add missing players to the CC player database, finalize the Teilnehmerliste, upload game results for the club's own tournaments |
| **Region-Sportwart** | Regional tournament officer | All Club-Sportwart rights across all clubs in the region; can create new tournaments in CC |
| **Turnierleiter** (CC role, not to be confused with the Carambus concept) | Assigned per-tournament | Can view the tournament, record results; may or may not include finalization rights **[SME-CONFIRM]** |
| **Verbands-Sportwart** | Association-level officer | Superset of Region-Sportwart |
| **Member** (default) | Any CC-registered player | Read-only for most tournament data |

The practical consequence: **the person physically running a
Carambus tournament at the venue is not always the same person who
has the CC permissions to finalize the Teilnehmerliste or add a
missing player.** This is the organizational root cause of most
ClubCloud-related confusion during tournaments.

## Common scenarios and their handling

### Scenario 1: Teilnehmerliste needs finalization in CC

**Carambus symptom:** The Turnierleiter uploads game results and gets
an error like "Teilnehmerliste ist noch nicht finalisiert in
ClubCloud". **[SME-CONFIRM]** the exact error text the user sees.

**Root cause:** ClubCloud will not accept per-game or CSV result
uploads until the Teilnehmerliste for that tournament is marked as
"finalized" on the CC side. Finalization is a one-way action that
locks the participant list so CC can trust the identity of every
result it receives.

**Today (v7.0) handling:**
The Turnierleiter opens a second browser tab, logs into ClubCloud,
navigates to the tournament's admin page, clicks the "Finalize
Teilnehmerliste" button (or equivalent — **[SME-CONFIRM]** the exact
CC UI wording), confirms, then returns to Carambus and retries the
upload.

**Handoff when the Turnierleiter lacks the permission:**
If the Turnierleiter does NOT have Club-Sportwart or higher CC
rights, the finalization must be done by someone who does. In
practice this is one of:
1. **Phone call to the Club-Sportwart** — the Turnierleiter calls the
   club's sports officer, asks them to finalize the list, waits for
   confirmation, retries the upload.
2. **Shared CC credentials** **[SME-CONFIRM]** — some venues
   historically maintained a shared Club-Sportwart login that every
   Turnierleiter knew. This practice is brittle (password hygiene,
   audit trail) and should not be documented as a recommendation.
3. **Pre-tournament preparation** — the Club-Sportwart finalizes the
   Teilnehmerliste the day before the tournament, before the
   Turnierleiter even arrives. This requires knowing the final
   participant list 24 hours in advance, which is not always the
   case (walk-ins, substitutions, last-minute withdrawals).

**Planned v7.1 handling:**
Carambus CCI-04 will add a "Finalize Teilnehmerliste" button inside
Carambus that calls the CC API directly. When the current Carambus
user has the required CC role, they click and it's done. When they
don't, Carambus produces a handoff report with the exact person to
call and the exact resume-point to return to after the finalization
completes. See `.planning/milestones/v7.1-REQUIREMENTS.md` CCI-04..08.

### Scenario 2: A participant is not in the CC player database

**Carambus symptom:** The Teilnehmerliste finalization preflight check
(or the upload itself) rejects a participant because they have no
matching CC player record. **[SME-CONFIRM]** whether the preflight
today produces a clear error or a confusing one.

**Root cause:** Every result upload is attributed to a CC player ID.
If a Carambus-known participant has no CC record, CC has nowhere to
attach the result.

**Typical causes:**
1. **New player** — someone playing their first tournament who has
   never been registered in CC. The club is supposed to register them
   before the tournament, but in practice this is often missed.
2. **Player from another club** — the player exists in CC but under
   a different club's roster, and the tournament configuration points
   at a specific club roster.
3. **Typo** — the player's name in Carambus doesn't exactly match the
   CC record due to a spelling or formatting difference.
4. **Guest** — someone playing as a one-off guest who should NOT end
   up in the CC player database. **[SME-CONFIRM]** whether CC has a
   "guest" mechanism at all or whether guests are handled differently
   (e.g., excluded from upload).

**Today (v7.0) handling:**
- Typo case: the Turnierleiter fixes the name in Carambus to match CC.
- New player / other-club / real missing case: someone with
  Club-Sportwart+ rights in CC has to add the player record before
  the upload can proceed. Same handoff flow as Scenario 1.
- Guest case: **[SME-CONFIRM]** — probably excluded from upload
  manually; probably fragile.

**Planned v7.1 handling:**
Carambus CCI-05 (preflight check) + CCI-06 (missing-player flow) will
surface the missing-player situation BEFORE the Turnierleiter tries
to upload, with a clear list of missing names and the options
available depending on the current user's CC role:
- If the user has Club-Sportwart+ rights: one-click add-to-CC.
- If not: handoff report with the missing names, the target CC role,
  and a callback number from the credentials profile (CCI-07).

### Scenario 3: The tournament needs an Endrangliste in CC

**Carambus symptom:** The tournament finishes. Results are in CC via
per-game upload, but the final ranking (Endrangliste) is still empty
because CC never computed it from the game results automatically.
**[SME-CONFIRM]** — does CC compute any ranking automatically, or is
the Endrangliste always a separate manual entry? The v7.0 review
notes suggest the latter (F-36-34).

**Root cause:** ClubCloud does not currently compute a ranking from
uploaded game results. The Endrangliste is a separate data entity
that has to be entered by a human who has the right CC role.

**Today (v7.0) handling:**
The Turnierleiter (or Club-Sportwart, depending on permissions)
looks at the completed games in Carambus or on paper, computes the
final ranking according to the discipline's rules, and enters it
by hand into the CC admin UI. This is error-prone and slow.

**Planned v7.1 handling:**
Carambus CCI-01 will compute the Endrangliste from the game tree in
ruby and present it in a preview screen. CCI-02 lets the Turnierleiter
verify and correct it (especially for ties that required manual
resolution — the Shootout gap from v7.2 is relevant here). CCI-03
uploads the verified Endrangliste via the CC API in one click.

### Scenario 4: Upload fails partway through

**Carambus symptom:** Some game results land in CC, others do not,
and Carambus shows a partial-success state. **[SME-CONFIRM]** whether
this actually happens today or whether uploads are atomic.

**Handling:** **[SME-CONFIRM]** — today's behavior is probably "retry
the upload and hope CC de-duplicates", which is unsafe. The v7.1
CCI-03 upload path should define explicit reconciliation semantics.

## Credential delegation practice

**[SME-CONFIRM all of this section.]** The following is inferred from
the Phase 36 review and from general tournament-organization practice,
not from direct SME statements.

When the Turnierleiter at the venue lacks the CC role required for a
specific operation, the organization has historically used one or
more of these delegation patterns:

1. **Pre-delegation** — the Club-Sportwart gives the Turnierleiter
   temporary elevated rights in CC for the duration of the tournament.
   Whether CC supports this technically **[SME-CONFIRM]**.
2. **On-call delegation** — the Club-Sportwart is reachable by phone
   and performs the CC-side action when requested. This is the most
   common pattern in practice but has no systemic support.
3. **Shared credentials** — a shared login is handed to the
   Turnierleiter. Not recommended for auditability and password
   hygiene reasons but historically common.
4. **Dual-role Turnierleiter** — the person running the tournament
   IS the Club-Sportwart. Works perfectly but is not always feasible.

The v7.1 CCI-09 requirement asks the v7.1 discuss-phase to decide
which delegation patterns Carambus should actively support vs. which
should be deprecated in favor of a Carambus-side workflow (the
handoff-report pattern from CCI-08).

## Things that are NOT in the appendix scope

- The Carambus-side wizard steps for Teilnehmerliste preparation —
  those are in the main walkthrough, not here.
- The ClubCloud UI itself — if CC changes its admin screens, this
  appendix describes the workflow level, not the click-by-click.
- Tournament creation in CC — assumed to be done before the
  Turnierleiter opens Carambus. Documented elsewhere **[SME-CONFIRM
  which doc]** or not at all.
- Non-CC tournament targets — if Carambus ever gains non-CC upload
  paths, they belong in their own appendix.

## Open SME questions (to resolve before promoting this draft)

1. **Exact CC role names and permission boundaries** — the table at
   the top of this appendix needs a factual correction pass.
2. **Does CC today support automatic Endrangliste computation?**
   Implied no by F-36-34, but confirm.
3. **Does CC support temporary role elevation / delegation?** If no,
   the credential-delegation section needs to be honest about it.
4. **What are the exact error messages a Turnierleiter sees today**
   in each scenario? If the messages are bad, the appendix should
   quote the actual (bad) text so users can search for it.
5. **Is there a CC sandbox environment** for testing? This affects
   v7.1 CCI test strategy, not the appendix itself, but the answer
   came up during Phase 36c scoping.
6. **What is the Freilos / Match-Abbruch story in CC?** The Carambus
   seed for this (`.planning/seeds/match-abbruch-freilos-handling.md`)
   needs to know whether CC accepts "game not played" as valid data.

## Related Carambus documents

- `docs/managers/tournament-management.de.md` — main walkthrough;
  Phase 36a made it factually accurate for Carambus-side flows but
  explicitly deferred CC-side content to this appendix.
- `.planning/v7.0-scope-evolution.md` §"Meta-2: ClubCloud-Upload model
  incomplete" — the review finding that triggered this appendix.
- `.planning/milestones/v7.1-REQUIREMENTS.md` — the milestone that
  will make most of this appendix's "today's handling" obsolete.
- `.planning/seeds/match-abbruch-freilos-handling.md` — entangled
  with Scenario 4 above.

---

*Draft produced by Phase 36c (v7.0), 2026-04-14. Promote to
`docs/managers/` only after SME-CONFIRM items are resolved.*
