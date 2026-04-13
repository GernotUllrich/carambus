# Tournament Management

This page walks you through running a carom tournament synced from ClubCloud, step by step, from the moment you receive the invitation to the final upload of results.

<a id="scenario"></a>
## Scenario

As the tournament director for your club you have received an NBV invitation for the **NDM Freie Partie Class 1–3** — a regional carom tournament running one Saturday in your club's playing location with 5 registered players across two tables. This page walks you through running the tournament from the moment the invitation arrives to the moment the results are uploaded back to ClubCloud.

<a id="walkthrough"></a>
## Walkthrough

The following guide follows the actual flow of the Carambus wizard — as it works in practice. Where the interface uses unfamiliar labels or shows unexpected behaviour, you will find a coloured callout box explaining what to expect.

<a id="step-1-invitation"></a>
### Step 1: Receive the NBV invitation

You receive a PDF invitation from the regional sports officer by email for the NDM. The invitation contains the official tournament plan, the participant list (seeding list), and the start times. You do not need to click anything in the system yet — open the invitation, keep the PDF handy, and then open the tournament detail page in Carambus.

<a id="step-2-load-clubcloud"></a>
### Step 2: Load tournament from ClubCloud (Wizard Step 1)

Open the tournament detail page in Carambus. At the top of the page you see the wizard progress bar "Tournament Setup". Step 1 "Load registration list from ClubCloud" is usually already completed automatically — a green tick (LOADED) indicates that Carambus has already synchronised the registration list.

**Note:** ClubCloud sometimes delivers fewer players than expected — in practice, a 5-player tournament initially showed only 1–2 registrations. The wizard displays a green "Continue to Step 3 with these N players" button even when N is suspiciously low. Check the number carefully before proceeding. If players are missing, fix this in [Step 4](#step-4-participants). See also [Player not in ClubCloud](#ts-player-not-in-cc) in the troubleshooting section.

![Wizard overview after ClubCloud sync](images/tournament-wizard-overview.png){ loading=lazy }
*Figure: Tournament setup wizard right after ClubCloud sync (example from the Phase 33 audit, NDM Freie Partie Class 1–3).*

<a id="step-3-seeding-list"></a>
### Step 3: Seeding list — invitation vs ClubCloud

In Wizard Step 2 you can import the seeding list (the ordered participant list) from two sources: either by **uploading the PDF invitation** or by using the **ClubCloud registration list** as an alternative.

The current interface presents the PDF upload as the primary option and ClubCloud as the "alternative" — for clubs that use ClubCloud as their official registration source, the logic is the reverse. If you upload the NBV invitation PDF, Carambus shows a side-by-side comparison of both seeding lists so you can spot any discrepancies. If the PDF upload fails (common with certain print templates), use the ClubCloud list directly — see [Invitation upload failed](#ts-invitation-upload) for details.

<a id="step-4-participants"></a>
### Step 4: Review and add participants (Wizard Step 3)

In Wizard Step 3 "Edit participant list" you see the currently registered participants. If players are missing, add them using the **"Add player by DBU number"** field. You can enter multiple [DBU numbers](#glossary-system) comma-separated (example: `121308, 121291, 121341, 121332`).

Click **"Sort by ranking"** at the top to automatically order the participant list by the current [ranking](#glossary-system) — this is almost always the correct order for an NDM Freie Partie.

Once the number of participants matches a predefined [tournament plan](#glossary-wizard), a gold-highlighted panel **"Possible tournament plans for N participants — automatically suggested: T04"** appears below the participant list. With 5 participants, T04 is suggested. This is the best indicator that the participant count is correct — if no plan is suggested, check your participant count. The final mode selection happens in Step 6.

All changes are saved immediately; no confirmation click is required.

<a id="step-5-finish-seeding"></a>
### Step 5: Close participant list (Wizard Step 4)

When the participant list is complete, click the blue **"Close participant list"** button in Wizard Step 4. This locks the [seeding list](#glossary-wizard) and transitions the tournament to `tournament_seeding_finished` status.

!!! warning "Closing the participant list is final"
    Clicking **Close participant list** is a one-way action. Double-check
    the participant list carefully before you click — after closing, the
    wizard jumps straight to mode selection, and changing the participant
    list later requires admin intervention.
<!-- ref: F-09 -->

After clicking, the wizard progress bar jumps from Step 3 directly to Step 5 — Step 4 is handled automatically in the background and appears as completed. This jump in the display is confusing but correct. The next active step is mode selection.

<a id="step-6-mode-selection"></a>
### Step 6: Select tournament mode

Wizard Step 5 opens a separate page "Final selection of playing mode". You see three cards with the available [tournament plans](#glossary-wizard): typically **T04**, **T05**, and **DefaultS**. Each card shows the number of rounds and tournament days. With 5 participants the suggestion is usually T04 (5 rounds, 1 tournament day, 2 tables).

!!! tip "Which tournament plan should I pick?"
    Carambus usually suggests one plan automatically (for example **T04**
    for 5 participants). Accept the suggestion unless you have a specific
    reason to prefer an alternative. The alternatives differ mainly in the
    number of rounds and tournament days — for a typical NDM Freie Partie
    Class 1–3, the suggested plan is almost always correct.
<!-- ref: F-12 -->

Click **"Continue with T04"** (or the suggested plan). The selection is applied **immediately and without a confirmation dialog**. If you accidentally chose the wrong plan, see [Wrong mode selected](#ts-wrong-mode).

![Mode selection with T04 suggestion](images/tournament-wizard-mode-selection.png){ loading=lazy }
*Figure: Mode selection showing the three tournament plans with automatic T04 suggestion for 5 participants (example from the Phase 33 audit).*

<a id="step-7-start-form"></a>
### Step 7: Fill in start parameters

After mode selection the start form opens. At the top you see a summary of the selected mode, followed by the **"Table assignment"** section and a **"Tournament Parameters"** form with approximately 15 fields.

!!! tip "English field labels on the start form"
    A number of fields on the start form are currently labelled in English
    or in garbled German (for example *Tournament manager checks results
    before acceptance* or *Assign games as tables become available*). The
    [Glossary](#glossary) below explains the most important terms. When in
    doubt, keep the default values and review the settings after the
    tournament.
<!-- ref: F-14 -->

The most important fields for an NDM Freie Partie:

- **Target balls** / **innings_goal** ([Target balls / innings_goal](#glossary-karambol)): The number of points (caroms) a player must score to win a match. For Freie Partie Class 1–3, typical values range from 50 to 150 — check the invitation.
- **Inning limit** ([Inning](#glossary-karambol)): Maximum number of innings per match. 0 = unlimited.
- **Tournament manager checks results before acceptance**: When enabled, you must manually confirm each result before it is recorded. For small tournaments with reliable scoreboard operators you can disable this.

Fill in the fields and proceed to [Step 8](#step-8-tables) for table assignment.

<a id="step-8-tables"></a>
### Step 8: Assign tables

In the **"Table assignment"** section you assign the physical tables to the tournament rounds. Select the two tables in your playing location from the drop-down list. The table names correspond to the table records set up in Carambus. For our NDM scenario, select Table 1 and Table 2.

The assignment is not critical — you cannot swap tables in the Tournament Monitor after starting, but the scoreboard connection works independently of this assignment (scoreboards connect to their assigned table automatically after start).

<a id="step-9-start"></a>
### Step 9: Start the tournament

When the table assignment and tournament parameters are complete, click **"Starte den Turnier Monitor"** at the bottom of the page.

!!! warning "Wait — do not click again"
    After you click **Starte den Turnier Monitor** the page will appear
    unchanged for several seconds. This is normal — the wizard is
    preparing the table monitors in the background. **Do not click the
    button again** and do not navigate back. The Tournament Monitor will
    open automatically within a few seconds.
<!-- ref: F-19 -->

In the background Carambus fires the AASM event `start_tournament!` (transitioning to `tournament_started_waiting_for_monitors`), initialises all TableMonitors, and then automatically redirects you to the Tournament Monitor page. If the page does not change after 30 seconds, check that Redis and the ActionCable service are running.

<a id="step-10-warmup"></a>
### Step 10: Warmup phase

Once the Tournament Monitor has opened, you see the overview page "Tournament Monitor · NDM Freie Partie Class 1–3". Each of the two tables shows a **"warmup"** status badge and the assigned player pairs for Match 1 (for example "Simon, Franzel / Smrcka, Martin" on Table 1).

Note: The label "Turnierphase: playing group" in the monitor header is an untranslated EN/DE mix — this is a known cosmetic issue and does not affect functionality.

During the warmup phase, players can try out the tables and balls. The scoreboards are already active, but points do not count yet. In the "Current matches Round 1" section you see all matches in the first round with columns Table / Group / Match / Players and a **"Spielbeginn"** button per row.

You do not need to do anything actively here — check that all scoreboards are connected (green status) and wait for the signal to start.

![Tournament Monitor landing page during warmup](images/tournament-monitor-landing.png){ loading=lazy }
*Figure: Tournament Monitor right after start — both tables show "warmup" status and the pairings for Round 1 (example from the Phase 33 audit).*

<a id="step-11-release-match"></a>
### Step 11: Release each match

When warmup is complete and all players are ready, click **"Spielbeginn"** for each match in the "Current matches Round 1" table. This click starts the time-keeping and activates ball entry on the [Scoreboard](#glossary-wizard).

Note: There is no success flash or confirmation after clicking "Spielbeginn" — the button simply disappears from the row. This is normal behaviour.

In our scenario with 5 participants and 2 tables, 2 matches run simultaneously in Round 1 — click two "Spielbeginn" buttons in succession. The fifth player sits out Round 1 (bye, depending on the tournament plan).

<a id="step-12-monitor"></a>
### Step 12: Monitor results

After match release, players handle score entry on the scoreboards. The Tournament Monitor updates in real time via ActionCable — you do not need to reload the page.

Watch the column values **Balls** / **Inning** / **HS** ([High run](#glossary-karambol)) / **GD** ([General average](#glossary-karambol)) in the matches table. When a match is finished, the table card automatically advances to the next match in the round. After all matches in a [playing round](#glossary-karambol) are complete, the Monitor switches to Round 2 and the next pairings appear.

As tournament director you normally do not intervene actively — unless a player contests a result or a scoreboard problem arises. If you enabled "Tournament manager checks results before acceptance", a confirmation button appears for you after each match.

<a id="step-13-finalize"></a>
### Step 13: Finalize the tournament

After all rounds are complete, a finalize button appears in the Tournament Monitor. Click it to calculate the final rankings and move the tournament to its completed status.

If placements still need adjusting (for example because of a play-off or a manual correction), see [Single Tournament Management](single-tournament.md) for the full placement workflow.

After finalising, the tournament is closed — changes to results are only possible via admin intervention.

<a id="step-14-upload"></a>
### Step 14: Post-tournament upload to ClubCloud

If the **"auto_upload_to_cc"** option was enabled in the start form (Step 7), Carambus automatically pushes the results back to ClubCloud on finalisation. You will see a confirmation that the upload was successful.

If the automatic upload is disabled or fails, you can trigger the upload manually from the tournament detail page (button "Upload results to ClubCloud"). Verify in ClubCloud that the results have arrived — they are normally visible within a few minutes.

---

<a id="glossary"></a>
## Glossary

<a id="glossary-karambol"></a>
### Karambol terms

- **Straight Rail (Freie Partie)** — The simplest carom discipline: one point per legal carom (the cue ball must contact both object balls), with no zone restrictions. Target balls for NDM classes typically range from 50 to 150 depending on class. *You configure this value in the [start form, Step 7](#step-7-start-form).*

- **Balkline / Cadre (35/2, 47/1, 47/2, 71/2)** — Carom disciplines with zone restrictions drawn on the table cloth (cadre = French for "frame"). The first number is the zone size in centimetres, the second is the maximum number of consecutive points allowed within a zone. Cadre tournaments use the same wizard steps as Straight Rail but with different standard target-ball values.

- **Three-Cushion (Dreiband)** — Carom discipline in which the cue ball must contact at least three cushions before touching the second object ball. No zone restrictions. *You see the discipline name on the tournament detail page.*

- **One-Cushion (Einband)** — Carom discipline in which the cue ball must contact at least one cushion before hitting the second object ball.

- **Inning (Aufnahme)** — One inning is one turn at the table: the player continues shooting until they fail to score or reach the target. The **inning limit** on the start form sets the maximum number of innings per match (0 = unlimited). *You see this term in the [start form, Step 7](#step-7-start-form).*

- **Target balls / innings_goal (Bälle-Ziel)** — The number of points (caroms) a player must score to win a match. The database field is called `innings_goal` in the code; the start form labels it "Bälle vor" or "Bälle-Ziel". *You configure this in the [start form, Step 7](#step-7-start-form). See the callout in that step for notes on the English labels.*

- **High run / HS (Höchstserie)** — The longest consecutive scoring run in a single match or across the whole tournament. Displayed in real time in the [Tournament Monitor, Step 12](#step-12-monitor).

- **General average / GD (Generaldurchschnitt)** — Points scored divided by the number of innings played. A key measure of playing strength across a tournament. Displayed in the [Tournament Monitor, Step 12](#step-12-monitor).

- **Playing round (Spielrunde)** — One complete round of the tournament in which each player (or pair) competes once. A T04 plan has 5 playing rounds. After each round the Tournament Monitor automatically updates the standings table.

- **Table warmup (Tisch-Warmup)** — The phase after [starting the tournament](#step-9-start) in which tables carry `warmup` status and players can try out the balls and cloth without points counting. Ends when you [release each match](#step-11-release-match).

<a id="glossary-wizard"></a>
### Wizard terms

- **Seeding list (Setzliste)** — The ordered participant list with seeding positions (position 1 = top seed, position N = lowest seed). Imported in [Step 3](#step-3-seeding-list) from the invitation or ClubCloud, extended in [Step 4](#step-4-participants). Closing the seeding list in [Step 5](#step-5-finish-seeding) is irreversible.

- **Tournament mode (Turniermodus)** — The playing format of the tournament (for example round-robin, knockout). Selected in [Step 6](#step-6-mode-selection). The mode determines the underlying tournament plan (T04, T05, DefaultS) and thus the number of rounds and days.

- **Tournament-plan codes (T04, T05, Default5)** — Internal labels for predefined tournament plans. **T** stands for Turnierplan (tournament plan), the number is the plan code. T04 and T05 are the common plans for 5-player round-robin tournaments — they differ mainly in the number of rounds. Default5 is a more flexible format. *You select the plan in [Step 6](#step-6-mode-selection).*

- **Scoreboard** — The touch-enabled input device at each table, used by players or an assistant to enter points live during a match. Scoreboards connect automatically to the Tournament Monitor after [starting the tournament](#step-9-start). Without an active scoreboard connection, points cannot be recorded.

<a id="glossary-system"></a>
### System terms

- **ClubCloud** — The regional registration platform of the DBU (Deutscher Billard-Union / German Billiards Union). ClubCloud is the authoritative source for player registrations and entry lists. Carambus synchronises the participant list from ClubCloud in [Step 2](#step-2-load-clubcloud). See the [ClubCloud Integration guide](clubcloud-integration.md) for further details.

- **AASM status (AASM-Status)** — The internal state of the tournament managed by the AASM state machine (Acts As State Machine). Possible states include `new_tournament`, `tournament_seeding_finished`, `tournament_started_waiting_for_monitors`, `tournament_started`, and others. The wizard step display mirrors this status — Step 4 complete = `tournament_seeding_finished`, tournament started = `tournament_started`. *Phase 36 will make this status badge more prominent in the wizard.*

- **DBU number (DBU-Nummer)** — The national player ID issued by the Deutscher Billard-Union. Every licensed player has a unique DBU number. In [Step 4](#step-4-participants) you can add players who are not in the ClubCloud registration list by entering their DBU number (comma-separated) in the input field.

- **Ranking (Rangliste)** — The regional player ranking sourced from the ClubCloud database. In [Step 4](#step-4-participants) you can use "Sort by ranking" to automatically order the participant list by ranking position — this matches the official seeding order for most NBV tournaments.

<a id="troubleshooting"></a>
## Troubleshooting

<a id="ts-invitation-upload"></a>
### Invitation upload failed

**Problem:** The upload dialog in Step 3 shows an error, spins indefinitely, or the PDF is uploaded but the seeding list remains empty.

**Cause:** The Carambus PDF parser cannot reliably read all NBV and DBU print templates — particularly when the PDF is a scanned image (no machine-readable text), has a very low scan resolution, or uses a non-standard page format. OCR failures are common with invitations that exist only as image scans.

**Fix:** Use the **ClubCloud registration list as the source** instead — that is the "alternative" in Step 3. Click "Use ClubCloud registration list" to import participants directly from the ClubCloud sync. Then go to [Step 4](#step-4-participants) to add any missing players by DBU number. The ClubCloud route is more reliable in practice for NBV tournaments than the PDF upload.

<a id="ts-player-not-in-cc"></a>
### Player not in ClubCloud

**Problem:** After the ClubCloud sync in Step 2, fewer players were loaded than expected. The wizard shows a green "Continue to Step 3 with these N players" button even though N is too low (for example 1 instead of 5).

**Cause:** The ClubCloud synchronisation sometimes delivers incomplete results — a known behaviour (F-03/F-04) that can occur when registrations in ClubCloud have not yet been fully confirmed, or when the sync connection returns a partial response. The green button appears to indicate completeness even when the data is incomplete.

**Fix:** Do **not** click "Continue" if the player count is too low. Instead, go to [Step 4](#step-4-participants) and add the missing players manually using the "Add player by DBU number" field (enter multiple DBU numbers comma-separated). The invitation PDF typically lists all DBU numbers for registered participants.

<a id="ts-wrong-mode"></a>
### Wrong mode selected

**Problem:** In Step 6 you clicked one of the three mode cards (T04, T05, DefaultS) and the wrong plan is now active. The start form has already opened.

**Cause:** Mode selection is applied immediately on click — there is no confirmation dialog (F-13). There is no "Back" button that safely reverts the mode.

**Fix:** If the tournament has **not yet been started** (Step 9 not yet executed), navigate to the wizard overview (tournament detail page) and use the "Change mode" button to select a different plan. If **`start_tournament!` has already fired**, the mode can no longer be changed through the normal interface — see [Tournament already started](#ts-already-started). Using browser Back in this state is risky and should be avoided.

<a id="ts-already-started"></a>
### Tournament already started

**Problem:** You need to change participants, the tournament mode, or start parameters, but the wizard is already showing the Tournament Monitor and the detail page shows "Tournament running".

**Cause:** The AASM event `start_tournament!` (triggered in [Step 9](#step-9-start)) is irreversible — there is **no undo path** for started tournaments in the current version (v7.0 scope, F-19 / Tier 3 finding). This is a deliberate design decision to ensure data consistency with running scoreboards.

**Fix:** Contact a **Carambus admin with database access**. A typical recovery is to mark the running tournament as erroneous, create a new tournament instance with the correct parameters, and manually transfer any already-recorded results. This is not a volunteer-friendly operation — the vast majority of errors at this point can be avoided by careful review in [Step 5](#step-5-finish-seeding) (participant list) and [Step 6](#step-6-mode-selection) (tournament mode). The warning callout in [Step 9](#step-9-start) explicitly advises against clicking again or navigating back.

---

<a id="architecture"></a>
## More on the architecture

Carambus is a distributed system of web services: a central API server publishes tournaments and player data (for example NBV tournaments via carambus.net); regional and club-owned Carambus servers synchronise this data and handle on-site tournament management. Global records — tournaments synced from the API server — are read-only for identity fields such as title, date, and organiser (LocalProtector); your local server manages wizard state transitions, the participant list, and match results.

Day-to-day tournament management does not require understanding the architecture — if you followed the walkthrough above, you already know everything you need. For further technical details — database structure, ActionCable configuration, deployment — read the [Developer Documentation](../developers/index.md).
