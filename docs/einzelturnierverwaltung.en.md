# Individual Tournament Management - Wizard System

## Overview

The new **Wizard System** for tournament management guides you step-by-step through the entire tournament preparation process. Each step is clearly structured and provides context-sensitive help, making it easy for tournament directors to use the system safely, even without technical expertise.

## Access

A Carambus tournament management account with **admin rights** on the Carambus Location Server is required. This can be set up by the club chairman or [Carambus developer](mailto:gernot.ullrich@gmx.de).

The URL can be derived from the scoreboard URLs, e.g., in Wedel: `http://192.168.2.143:3131`

## The Wizard Workflow

The new wizard system consists of **6 main steps** that visually guide you through the entire process:

### Step 1: Load Registration List from ClubCloud

**Goal:** Fetch the participant list from the API server.

**What happens here?**
- The system synchronizes the registration list from ClubCloud
- Players are automatically recognized and assigned
- New players are added to the database

**When is this step needed?**
- When the tournament is loaded for the first time
- When the registration list has changed after the registration deadline
- When new players have been registered late

**Quick Load:**
- ⚡ **"Load Upcoming Tournaments"** button: Loads only tournaments for the next 30 days (faster than full synchronization)
- Available on the regional association page: `Regional Associations → [Your Association] → "⚡ Quick Update"`

**Manual Synchronization:**
- `Tournament → "Synchronize Now"`: Full synchronization of all data
- `Tournament → "📊 Load Results from ClubCloud"`: Only for archiving after tournament end (deletes local data!)

### Step 2: Import Seeding List from Invitation

**Goal:** Import the official seeding list from the invitation sent by the tournament director, or proceed directly with the registration list.

**What happens here?**
- **Option 1:** You upload a PDF file or screenshot of the invitation
- The system automatically extracts:
  - Player names and positions
  - **Handicap points** for handicap tournaments
  - **Group assignments** (if present in the invitation)
  - **Tournament mode** (e.g., "T21 - Tournament will be played in mode...")
- **Option 2 (Alternative):** If no invitation is available, proceed directly with the registration list to Step 3
  - Players are automatically sorted by **Carambus ranking** for the discipline
  - Sorting is based on effective rankings (newest available season from the last 2-3 years)

**How does it work?**
1. Click **"Upload Invitation"**
2. Select a PDF file or screenshot (PNG/JPG) of the invitation
3. The system automatically analyzes the document
4. Review the **Extracted Seeding List**:
   - ✅ Players correctly recognized?
   - ✅ Positions correct?
   - ✅ Handicaps present (for handicap tournaments)?
5. Correct manually if needed:
   - Player incorrectly recognized → Click **"Change Player"**
   - Position incorrect → Correct in the list
   - Handicap missing → Enter manually
6. Click **"Import Seeding List"**

**Supported Formats:**
- ✅ PDF files (with text)
- ✅ Screenshots (PNG, JPG)
- ✅ Single and two-column tables
- ✅ Tables with handicap column ("Pkt")

**What is extracted?**
- Player names (first and last name)
- Positions in the seeding list
- Handicaps (for handicap tournaments)
- Group assignments (if present)
- Tournament mode suggestion (e.g., "T21")

### Step 3: Edit Participant List

**Goal:** Create and adjust the final participant list.

**What happens here?**
- You see the current participant list with the following information:
  - Position (seeding order)
  - Player name and club
  - **Carambus ranking** for the discipline (with link to ranking table)
  - Handicap (for handicap tournaments)
- You can:
  - Mark **No-Shows** (player doesn't appear)
  - **Correct handicaps** (for handicap tournaments)
  - **Adjust positions** using ↑↓ buttons or direct input
  - **Add late registrations** (with DBU number)

**New Features in Step 3:**

**1. Ranking Display:**
- Each player shows their **effective Carambus ranking** for the discipline
- Based on the last 2-3 seasons (newest available)
- Clickable: Link leads to the complete ranking table of the region with anchor to the discipline

**2. Position Changes:**
- **↑↓ Buttons:** Move player one position up/down
- **Direct Input:** Enter new position directly (e.g., enter "5" and press Enter)
- Changes are saved immediately
- Group assignments in the tournament plan preview update automatically

**3. Tournament Plan Preview:**
- Shows **possible tournament plans** for the current number of participants
- **Group assignments** are dynamically calculated and displayed
- Updates automatically when the participant list changes
- Shows number of rounds for each plan
- **Proposed plan:** From invitation (if available) or automatically calculated
- **Alternative plans:** Same discipline, other disciplines, "Round Robin" (for ≤6 participants)

**Add Late Registration:**
1. Scroll to the **"➕ Late Registration?"** section
2. Enter the player's **DBU number**
3. Click **"Add Player"**
4. The player is automatically added to the list (at the end)

**⚠️ Important:**
- Players **without DBU number** cannot be added as late registrations
- Reason: Only players with DBU number can be entered in ClubCloud
- Solution: Player must apply for DBU number, or register as guest (contact tournament director)

**Auto-Save:**
- All changes (checkboxes, handicaps) are **saved immediately**
- You can return here at any time

**Continue to Next Step:**
- After completion: Click **"← Back to Wizard"**
- Then continue to **Step 4: Finalize Participant List**

### Step 4: Finalize Participant List

**Goal:** Complete the participant list and prepare it for group assignment.

**What happens here?**
- The participant list is finalized
- No-shows are removed from the list
- The list is locked for group assignment

**⚠️ Important:**
- This step is **irreversible**
- After finalization, players can no longer be added or removed
- Positions can no longer be changed

### Step 5: Select Tournament Mode

**Goal:** Select the appropriate tournament mode and review group assignments.

**What happens here?**
- The system automatically suggests a tournament mode:
  - Based on the number of participants
  - Based on the discipline
  - Based on the **extracted tournament mode from the invitation**

**Suggestions from Invitation:**
- If an invitation was uploaded, the **extracted tournament mode** is preferred
- Example: "T21 - Tournament will be played in mode..."
- This suggestion comes directly from the tournament director

**Group Assignment:**
- The system shows the **calculated group assignment** according to NBV standard
- If an invitation was uploaded, the **extracted group assignment** is also shown

**Three Possible Scenarios:**

1. **✅ Group Assignment from Invitation Matches Algorithm**
   - Green banner: "✅ Group Assignment from Invitation Imported"
   - The assignment is identical to the NBV standard algorithm
   - **Recommendation:** Use invitation (prescribed by tournament director)

2. **⚠️ Group Assignment from Invitation Differs from Algorithm**
   - Red banner: "⚠️ WARNING: Deviation from NBV Standard Detected!"
   - Comparison is shown: Invitation vs. calculated
   - **Recommendation:** Use invitation (prescribed by tournament director)
   - **Alternative:** Use algorithm (if you are sure the algorithm is correct)

3. **🤖 No Invitation Available**
   - Blue banner: "🤖 Group Assignment Automatically Calculated (NBV-Compliant)"
   - Standard algorithm is used

**Select Tournament Mode:**
1. Review the **suggested option** (highlighted in green)
2. Review **alternatives** (if available):
   - Same discipline with different player counts
   - Other disciplines with same player count
3. Click **"Continue with [Mode Name]"**

**Manual Adjustment:**
- ⚠️ **"🔄 Recalculate"**: Discards extracted group assignment and recalculates
- ⚠️ **"✏️ Manual Adjustment"**: (In development) Drag-and-drop for group assignment

### Step 6: Start Tournament

**Goal:** Initialize the tournament and activate scoreboards.

**What happens here?**
- You configure tournament parameters:
  - **Assign tables** (mapping internal table name to external name)
  - **Ball goal** (possibly already predefined for tournament)
  - **Innings limit** (possibly already predefined for tournament)
  - **Timeout** in seconds (0 or empty if no timeouts)
  - **Timeouts** (maximum number of timeout extensions)
  - **Checkbox:** "Tournament manager checks results before acceptance"
  - **Warm-up time** (standard and shortened when switching tables)

**Tournament Parameters:**
- Many parameters can be taken from the **invitation**
- Example: "The target score is 80 points in 20 innings"
- This information is automatically extracted (if available)

**Start Tournament:**
1. Review all parameters and adjust if needed
2. Click **"Start Tournament"**
3. The system:
   - Initializes the Tournament Monitor
   - Creates all games according to tournament mode
   - Assigns tables
   - Starts scoreboards

**After Start:**
- New game pairings appear automatically on scoreboards
- The **Tournament Monitor** shows the current status
- Players can start games and enter results

## During the Tournament: Tournament Status

After the tournament starts, the **Wizard is hidden** and replaced by the **Tournament Status** view.

**What does Tournament Status show?**

**1. Tournament Overview:**
- Current tournament phase (e.g., "Group Phase", "Final Round")
- Progress bar (completed vs. planned games)
- Number of finished games

**2. Current Games:**
- Shows up to 6 running games simultaneously
- Live scores with current inning results
- Status indicator: "▶️ Running" or "Waiting"
- Assigned tables

**3. Group Assignments:**
- Overview of all groups
- Players per group
- NBV-compliant assignment

**4. Seeding List:**
- Final participant list with positions
- **Carambus rankings** for each player
- Club affiliation
- For handicap tournaments: Ball goals
- **Link to ranking table:** Leads to complete regional ranking table

**5. Current Standings:**
- Intermediate standings after group phases
- Final placements after tournament completion
- General average, highest series, etc.

**Visible only to tournament director:**
- **🎮 Open Tournament Monitor** button
- Access to game management and table assignment
- Result control and approval

**For spectators:**
- Clear view of tournament status
- Live updates on game progress
- No editing options

## Troubleshooting

### Problem: "No Seedings Found"

**Cause:** The registration list has not been synchronized yet.

**Solution:**
1. Go to **Step 1**
2. Click **"Synchronize Now"**
3. Wait for synchronization
4. Check if seedings are present

### Problem: "Player Not Recognized" (when uploading invitation)

**Cause:** The name in the document was not correctly recognized.

**Solution:**
1. Find the player in the **Extracted Seeding List**
2. Click **"Change Player"**
3. Search for the correct player
4. Select the correct one

### Problem: "Group Assignment Incorrect"

**Cause:** The extraction from the invitation was incorrect, or the algorithm doesn't match.

**Solution:**
1. Review the **Extracted Group Assignment** vs. **Calculated**
2. If invitation available: Click **"✅ Use Invitation"** (prescribed by tournament director)
3. If no invitation: Click **"🔄 Recalculate"**
4. If still incorrect: Call **Step 3** again and adjust positions

### Problem: "Late Registration Cannot Be Added"

**Cause:** Player has no DBU number.

**Solution:**
1. Player must apply for DBU number, or
2. Tournament director registers player as guest (contact tournament director)

### Problem: "Tournament Cannot Be Started"

**Cause:** TournamentPlan doesn't match the number of players.

**Solution:**
1. Check the **error message** in Tournament Monitor
2. Go back to **Step 5**
3. Select the **correct TournamentPlan**:
   - Example: 11 players → T21 (not T22!)
   - Check the number of players in Step 3

### Problem: "Seedings Deleted After Synchronization"

**Cause:** Old "destroy" version records on the API server.

**Solution:**
1. Run on API server: `rake tournament:check_seeding_versions[TOURNAMENT_ID]`
2. If destroy version records found: `rake tournament:cleanup_seeding_versions[TOURNAMENT_ID]`
3. Synchronize again

## After the Tournament

### Export Results

After the tournament ends, you automatically receive an **email** with a CSV file containing the results in the format required for uploading to ClubCloud.

The file is also saved locally: `{carambus}/tmp/result-{ba_id}.csv`

### Upload Results to ClubCloud

The tournament director can upload the CSV file directly to ClubCloud.

### Final Synchronization

As a final step, a **synchronization with ClubCloud** can be performed:
- `Tournament → "📊 Load Results from ClubCloud"` (only for archiving!)

The downloaded data forms the basis for later calculated rankings.

## Important Differences: Registration List vs. Seeding List vs. Participant List

**Registration List:**
- All players who registered for the tournament
- Comes from ClubCloud
- Updated daily

**Seeding List:**
- The **order** according to effective ranking
- Best players first (lowest ranking number = Position 1)
- **Effective Ranking:** Based on the newest available season from the last 2-3 years
- Comes from the **invitation** from the tournament director OR is automatically sorted by Carambus rankings
- Imported or calculated in **Step 2**

**Participant List:**
- The players who **actually appear at the tournament**
- Can have more or fewer players than the registration list
- No-shows are removed
- Late registrations are added
- Created in **Step 3** and finalized in **Step 4**

## Technical Details

### Automatic Extraction

The system uses **OCR (Optical Character Recognition)** and **PDF text extraction** to extract information from invitations:

- **PDF:** Text is extracted directly
- **Screenshots:** Tesseract OCR recognizes text
- **Tables:** Single and two-column layouts are recognized
- **Handicaps:** Extracted from "Pkt" columns
- **Group Assignment:** Extracted from "Group Assignment" tables

### NBV-Compliant Group Assignment

The system uses **official NBV algorithms** for group assignment:

- **2 Groups:** Zig-Zag/Serpentine pattern
- **3+ Groups:** Round-Robin pattern
- **Unequal Group Sizes:** Special algorithm (e.g., T21: 3+4+4)

Group sizes are extracted from the TournamentPlan's `executor_params`.

### Synchronization

- **Setup Phase:** Seedings are not deleted (only local seedings are reset)
- **Archiving Phase:** All seedings are deleted and reloaded (for result import)

The `reload_games` parameter controls whether seedings are deleted:
- `false` (default): Setup phase (seedings remain)
- `true`: Archiving phase (seedings are deleted)

## Support

For problems or questions:
- **Email:** [gernot.ullrich@gmx.de](mailto:gernot.ullrich@gmx.de)
- **Documentation:** This page and the inline help in the wizard
