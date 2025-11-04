# Scoreboard User Guide

## Overview

The Carambus Scoreboard is a complete display system for billiards games that can be used for both tournaments and training games. The operation is identical in both cases.

## Main Features

- **Score Display** - Real-time display of scores for both players
- **Timer Function** - Time measurement for innings and shot clocks
- **Warm-up Period** - Guided warm-up phase before the game
- **Shootout** - Determination of break rights
- **Discipline Support** - Carom, Pool, Snooker and other disciplines
- **Dark Mode** - Eye-friendly display for different lighting conditions

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Scoreboard Main View](#scoreboard-main-view)
3. [Key Bindings](#key-bindings)
4. [Game Flow](#game-flow)
5. [Display Modes](#display-modes)
6. [Appendix: Setting up Training Games](#appendix-setting-up-training-games)

---

## Getting Started

### Starting the Scoreboard

1. **Raspberry Pi Setup**: The scoreboard starts automatically when the Raspberry Pi boots
2. **Manual Start**: Open a browser and navigate to:
   ```
   http://[server-address]:3000/locations/[location-id]/scoreboard?sb_state=welcome
   ```
3. **From Location Page**: Click on the "scoreboard" link

### Welcome Screen

![Welcome Screen](screenshots/scoreboard_welcome.png)

The welcome screen is the starting point for all scoreboard activities. From here you can:

- **Select Tournament** - For official tournaments
- **Select Table** - For training games
- **Show Scores** - Overview of running games

---

## Scoreboard Main View

### Layout Overview

The scoreboard displays the following information:

```
┌─────────────────────────────────────────────────────┐
│  [Dark Mode] [Info] [Home] [Exit]                   │
│                                                       │
│  Player A                           Player B         │
│  ┌─────────────────┐              ┌─────────────────┐│
│  │  Current        │              │  Current        ││
│  │  Inning: 5      │              │  Inning: --     ││
│  │                 │              │                 ││
│  │  Goal: 50       │              │  Goal: 50       ││
│  │  GD: 1.250      │              │  GD: 0.800      ││
│  │  HS: 8          │              │  HS: 12         ││
│  │                 │              │                 ││
│  │      45         │              │      38         ││
│  │                 │              │                 ││
│  │  Sets: 1        │              │  Sets: 0        ││
│  └─────────────────┘              └─────────────────┘│
│                                                       │
│  [Input Area]                                        │
└─────────────────────────────────────────────────────┘
```

### Display Elements

#### Player Information (per side)

1. **Player Name** - Full name or short name
2. **Current Inning** - Points in the current inning
3. **Goal** - Target score (or "no limit")
4. **GD (General Average)** - Average points per inning
5. **HS (High Series)** - Best single inning in the game
6. **Total Score** - Large score display in the center
7. **Sets** - Number of sets won (if set mode is active)

#### Timer Display

When a timer is active, a progress bar display appears:

```
⏱ 00:45  IIIIIIIIIIIIIIII------
        (Green)     (Red)
```

- **Green**: Remaining time in normal range
- **Red**: Warning time expiring

#### Active Player

The active player is indicated by a **green border** (8px wide). The waiting player has a thin gray border.

---

## Key Bindings

The scoreboard can be completely controlled via keyboard or remote control:

### Main Keys

| Key | Function | Description |
|-----|----------|-------------|
| **Arrow Left** | Player A Points | Point for left player (in pointer mode) |
| **Arrow Right** | Player B Points | Point for right player (in pointer mode) |
| **Arrow Up** | Next Element | Navigate right/forward |
| **Arrow Down** | Execute Action | Activate/confirm element |
| **Page Up** | Player A Points | Alternative key for Player A |
| **Page Down** | Player B Points | Alternative key for Player B |
| **B** | Back/Forward | Back (Escape) in menu, Forward (right) in input fields |
| **Esc** | Back/Exit | Back to previous screen |
| **Enter** | Confirm | Confirm current selection |

### Special Keys

| Key | Function |
|-----|----------|
| **F5** | Restart | Reload scoreboard |
| **F11** | Fullscreen | Toggle fullscreen mode |
| **F12** | Exit | Exit scoreboard (kiosk mode) |

### Quick Input in Pointer Mode

In **Pointer Mode** (main mode during the game):

- **Left/Right Key**: Adds 1 point for the corresponding player
- **B Key**: Switches to **Timer Area**
- **B Key** (in Timer): Switches to **Input Area**
- **Down Key**: Confirms the input

---

## Game Flow

### 1. Prepare Game Start

After selecting a table or tournament, the **Setup Screen** appears.

#### For Tournament Games

Parameters are automatically taken from the tournament:
- Player A and B
- Discipline (e.g. Straight Rail, 3-Cushion, Pool)
- Target points/balls
- Innings limit
- Sets
- Timeout settings

#### For Training Games

See [Appendix: Setting up Training Games](#appendix-setting-up-training-games)

### 2. Warm-up Period

![Warm-up](screenshots/scoreboard_warmup.png)

Both players have time for warm-up:

1. **Start Warm-up** (Player A) - Click to start 5 minutes for Player A
2. **Timer Running** - Green bars show remaining time
3. **Halt** - Stop timer if needed
4. **Start Warm-up** (Player B) - Then 5 minutes for Player B
5. **Continue to Shootout** - When both are finished

**Keys:**
- **Enter/Down**: Start/Stop warm-up time
- **B**: Switch between Player A and B

### 3. Shootout

![Shootout](screenshots/scoreboard_shootout.png)

Determine who starts the game:

1. Both players lag from the head rail
2. Select the winner:
   - **Left Key** or Button **"Player A"**: Player A wins the lag
   - **Right Key** or Button **"Player B"**: Player B wins the lag
3. **Start Game** - Click to begin the actual game

**Alternative:**
- **Switch**: Change the active player

### 4. Game Running

![Game Running](screenshots/scoreboard_playing.png)

The scoreboard switches to **Game Mode**.

#### Entering Points

**Method 1: Keyboard Input (recommended for simple point entries)**

- **Left Key**: +1 point for the active player (left)
- **Right Key**: +1 point for the active player (right, after player switch)
- Points are **accumulated** and automatically saved after a short delay
- When the goal is reached, immediate validation occurs

**Method 2: Number Field (for larger scores)**

1. Press **Down Key** multiple times until "numbers" is focused
2. Enter the score via the number field:
   - Keys **1-9, 0** for digits
   - **Del**: Delete last digit
   - **Esc**: Cancel
   - **Enter**: Confirm score

#### Input Buttons

The input elements are arranged in **horizontal order**:

```
[Undo] [-1] [-5] [-10] [Next] [+10] [+5] [+1] [Numbers]
```

- **Undo**: Edit innings list (see detailed explanation below)
- **-1, -5, -10**: Subtract points
- **+1, +5, +10**: Add points
- **Next**: Player switch
- **Numbers**: Open number field for direct input

**Navigation:**
- **B Key**: Moves right through the buttons
- **Down Key**: Activates the focused button

#### The Undo/Edit Function (IMPORTANT!)

⚠️ **Frequently misunderstood:** The "Undo" button is **not** a simple undo function, but a powerful **editing tool** for the innings list!

**Exception:** For Pool billiards, Undo actually works as a true undo function.

##### How the Innings List Works

Below the main scores of both players, you see the **innings list**:

```
Player A                     Player B
   45                           38
┌─────────────┐            ┌─────────────┐
│ [5][8][12][│20│]         │ [6][7][10][│15│] │  ← Innings
└─────────────┘            └─────────────┘
   ▲                          ▲
   First                      Currently editable
   Inning                     (framed = Cursor)
```

- **First inning** is on the left
- **Current inning** is on the right and marked by a frame (cursor)
- Each number shows the points in that inning

##### Cursor Navigation

**With Undo (cursor left):**

1. Press **Undo**
2. The cursor jumps to the **previous inning** of the current player
3. The point values remain **unchanged**

**With Next/Switch (cursor right):**

1. Press **Next**
2. The cursor jumps to the **next inning** (alternating A/B)
3. When at the last inning, a player switch is executed

##### Editing Points

When the cursor is on an inning:

1. Use **-1, -5, -10** to reduce points
2. Use **+1, +5, +10** to increase points
3. The total score is **automatically recalculated**

##### Step-by-Step Example 1: Correct Error in Previous Inning

**Situation:**
- Player A just made 8 points
- You notice that the inning before had 12 instead of 10 points entered

**Solution:**

```
Starting situation:
Player A: [5][10][│8│]  (Cursor on current inning)
Total score: 23

Step 1: Press Undo
Player A: [5][│10│][8]  (Cursor on previous inning)

Step 2: Press "-1" twice
Player A: [5][│8│][8]   (10 → 8)
Total score: 21 ✓       (automatically corrected)

Step 3: Press "Next"
Player A: [5][8][│8│]   (Cursor back to current inning)
```

**Important:** After editing, you **MUST** navigate back to the current inning with "Next"!

##### Step-by-Step Example 2: Multiple Innings Back

**Situation:**
- Player A: [6][8][10][│12│]
- You want to correct the second inning (8) to 7

**Solution:**

```
Starting situation:
Player A: [6][8][10][│12│]  (Cursor at position 4)
Total score: 36

Step 1: Press Undo (1x)
Player A: [6][8][│10│][12]  (Cursor at position 3)

Step 2: Press Undo (2x)
Player A: [6][│8│][10][12]  (Cursor at position 2)

Step 3: Press "-1"
Player A: [6][│7│][10][12]  (8 → 7)
Total score: 35 ✓

Step 4: Press "Next" (1x)
Player A: [6][7][│10│][12]  (Cursor at position 3)

Step 5: Press "Next" (2x)
Player A: [6][7][10][│12│]  (Cursor back at position 4)
```

##### Step-by-Step Example 3: Editing Both Players

**Situation:**
- Player A just played: [5][│8│]
- Player B should play now: [6][│--│]
- You need to correct Player A's first inning from 5 to 6

**Solution:**

```
Starting situation:
Player A: [5][│8│]  (Cursor here)
Player B: [6][--]

Step 1: Press Undo
Player A: [│5│][8]  (Cursor at position 1)

Step 2: Press "+1"
Player A: [│6│][8]  (5 → 6)

Step 3: Press "Next" (1x)
Player A: [6][│8│]  (back to position 2)

Step 4: Press "Next" (2x) - executes player switch
Player A: [6][8]
Player B: [6][│--│]  ✓ (ready for new inning)
```

##### Important Notes

**✅ DO:**
- Navigate cursor consciously
- **Always** return to current inning after editing
- Visually verify changes (total score)

**❌ DON'T:**
- Leave cursor somewhere
- Continue playing without navigation
- Blindly press "Undo" multiple times

##### Common Errors

**Error 1: "I pressed Undo, but nothing happened"**

→ You didn't change the points! Undo **only moves the cursor**, points stay the same.

**Solution:** After Undo, adjust points with +/- buttons.

**Error 2: "After Undo, the score shows wrong values"**

→ The cursor is still on an old inning, not the current one.

**Solution:** Navigate back to current inning with "Next".

**Error 3: "I can't get back"**

→ You've lost track of where the cursor is.

**Solution:** 
1. Look at the innings list - the framed number shows the cursor
2. Press "Next" until you're back at the last inning
3. In emergency: Press F5 (reload page)

##### When to Use?

**Typical Use Cases:**

✅ **Correct typos**
- You accidentally entered 8 instead of 6

✅ **Change points retroactively**
- Referee decision corrects an earlier inning

✅ **Resolve discussions**
- Players disagree about an earlier inning
- You can go back and correct

**Don't use for:**

❌ **Change current inning**
- Use +/- buttons instead

❌ **Switch players**
- Use the "Next" button

##### Summary

| Key | Function | Effect on Cursor | Effect on Points |
|-----|----------|-----------------|------------------|
| **Undo** | Cursor back | ← One position back | None |
| **Next** | Cursor forward / Player switch | → One position forward | None |
| **+1, +5, +10** | Add points | None | Increases value at cursor position |
| **-1, -5, -10** | Subtract points | None | Decreases value at cursor position |

**Remember:** 
> Undo = Move cursor, +/- = Change points, Next = back to current inning

#### Player Switch

The player switch occurs either:
1. **Automatically** - When the active player scores 0 points
2. **Manually** - With the **"Next"** button or by keyboard input

After the switch:
- The green border switches to the new active player
- The current inning is reset
- The timer restarts (if active)

#### Timer Control

When timers are enabled:

- **Pause** ⏸: Pause timer
- **Play** ▶: Resume timer
- **Stop** ⏹: Reset timer
- **Timeout** ⏰: Take timeout (limited number per player, see timeout icons ⏱)

### 5. End of Set

When a player reaches the target score:

1. **Set Win Message** appears
2. Statistics are updated
3. For multi-set games:
   - New set begins automatically
   - Set score is updated
   - Break rights switch (depending on settings)

### 6. End of Game

When the required number of sets is won or the game is ended:

1. **Final Result** is displayed
2. Game statistics are saved
3. Options:
   - **Back to Overview**
   - **Start New Game**

---

## Display Modes

### Fullscreen Mode

**Activation:**
- Press **F11** or start via the corresponding link
- The scoreboard fills the entire screen

**Deactivation:**
- Press **F11** again

Fullscreen mode is ideal for:
- Spectator displays
- Competition situations
- Raspberry Pi kiosk mode

### Dark Mode

![Dark Mode](screenshots/scoreboard_dark.png)

**Toggle:**
- Click on the **Dark Mode Icon** 🌓 in the menu bar
- Or open the menu and select "Dark Mode"

**Benefits:**
- Reduces eye strain in dark rooms
- Saves energy on OLED displays
- Better readability in low light

The Dark Mode setting is saved in the user profile.

### Display-Only Mode

For pure display purposes without input capability:

```
/locations/[id]/scoreboard?sb_state=welcome&display_only=true
```

In this mode:
- No input elements visible
- Score display only
- Ideal for audience screens

---

## Menu and Navigation

### Main Menu Icons

The menu bar at the top right contains:

| Icon | Function | Description |
|------|----------|-------------|
| 🌓 | Dark Mode | Toggle light/dark mode |
| ℹ️ | Info | Switch to table overview |
| 🏠 | Home | Back to welcome screen |
| ⌫ | Exit | End game (with confirmation) |

### Ending a Game

1. Click on the **Exit Icon** ⌫ or press **B Key** in pointer mode
2. **Confirmation Dialog** appears:
   ```
   ┌─────────────────────────────────┐
   │  Really end game?               │
   │                                 │
   │  [OK]  [Cancel]                 │
   └─────────────────────────────────┘
   ```
3. Choose:
   - **OK**: Game ends, back to overview
   - **Cancel**: Back to game

**For Tournament Games:**
- The game is marked as "not played"
- Can be restarted by tournament director

**For Training Games:**
- The game is deleted
- Statistics are not saved

---

## Troubleshooting

### Scoreboard Not Responding

**Solution:**
1. Press **F5** to reload the page
2. If that doesn't help, press **B** to return to pointer mode
3. In emergency: Close browser and restart

### Points Not Being Saved

**Cause:** Network connection interrupted

**Solution:**
1. Check network connection
2. Points are buffered locally and transferred on next sync
3. For longer interruptions: Note the score and correct manually after restoration

### Timer Not Running

**Check:**
1. Is the timer enabled for this game? (Timeout setting > 0)
2. Was the timer started? (Press Play button)
3. Browser tab active? (Some browsers pause timers in background)

### Keyboard Not Working

**Solution:**
1. Click once in the scoreboard window to set focus
2. Check if keyboard is properly connected
3. For remote control: Check batteries

### Display Is Distorted

**Solution:**
1. Press **F11** to activate/deactivate fullscreen
2. Reset browser zoom (Ctrl+0 / Cmd+0)
3. Check screen resolution (minimum 1024x768 recommended)

---

## Appendix: Setting up Training Games

This section explains how to quickly and easily set up training games for free practice.

### Prerequisites

- You have access to the scoreboard (as scoreboard user or administrator)
- A table is available and not occupied by a tournament

### Step-by-Step Guide

#### 1. Select Table

![Table Selection](screenshots/scoreboard_tables.png)

1. From the **Welcome Screen** select **"Tables"**
2. An overview of all tables at the location appears
3. Select a **free table** (marked green):
   - **Green**: Table is free
   - **Yellow**: Table has a reservation but no active game
   - **Red**: Table is occupied with active game
4. Click on the desired table

#### 2. Choose Game Type

![Choose Game Type](screenshots/scoreboard_game_choice.png)

After selecting the table, a dialog for game type selection appears:

**Carom:**
- **Quick Game** - Predefined quick games (Straight Rail, Cadre, etc.)
- **New Carom Game** - Individual configuration

**Pool:**
- **Pool Game** - 8-Ball, 9-Ball, 10-Ball, 14.1 Continuous

**Select the appropriate category.**

#### 3. Select Players

![Player Selection](screenshots/scoreboard_player_selection.png)

##### Player A

1. Click on the **"Player A"** field
2. A dropdown with all players appears
3. Search for the player:
   - **Type** the name for quick search
   - Or **scroll** through the list
4. Select the player

##### Player B

Repeat the process for **"Player B"**.

**Note:** For training games you can also:
- Choose the same player for both sides (solo training)
- Create a dummy player (e.g. "Training")

#### 4. Configure Game Parameters

Depending on the chosen game type, different parameters are available:

##### Carom - Straight Rail

![Straight Rail Setup](screenshots/scoreboard_free_game_setup.png)

**Basic Settings:**

| Parameter | Description | Example |
|-----------|-------------|---------|
| **Discipline** | Game type (Straight Rail, Cadre, Three-Cushion, etc.) | "Straight Rail" |
| **Target Points** | Points to win | 50, 100, 200 |
| **Innings Limit** | Maximum innings (optional) | 50, 100, "no limit" |
| **Sets** | Number of sets to play | 1, 3, 5 |

**Advanced Settings:**

| Parameter | Description | Default |
|-----------|-------------|---------|
| **Timeout** | Shot clock per inning (seconds) | 45 |
| **Timeouts per Set** | Number of allowed timeouts | 1 |
| **Warning Time** | Warning before expiry (seconds) | 10 |
| **Break Switches With** | When does break right switch? | "Set" |
| **Color Remains With Set** | Player colors remain at set change? | No |
| **Fixed Display Left** | Left player stays left? | No |
| **Allow Overflow** | Count beyond target points? | No |
| **Allow Follow-Up** | Follow-up shot on object ball contact? | Yes |

##### Carom - Quick Game (Quick Start)

![Quick Game](screenshots/scoreboard_quick_game.png)

For quick start without many settings:

1. **Select a Preset:**
   - **Straight Rail 50** - Classic to 50 points
   - **Straight Rail 100** - Standard training game
   - **Cadre 47/2 100** - Cadre training
   - **Three-Cushion 50** - 3-Cushion to 50
   - **One-Cushion 100** - 1-Cushion to 100

2. Parameters are preconfigured but can still be adjusted

3. **Start Game** - Go directly

##### Pool Billiards

![Pool Setup](screenshots/scoreboard_pool_setup.png)

**Disciplines:**
- **8-Ball** - Classic 8-Ball
- **9-Ball** - 9-Ball
- **10-Ball** - 10-Ball
- **14.1 Continuous** - Straight Pool

**Parameters:**

| Parameter | Description | Example |
|-----------|-------------|---------|
| **Discipline** | Pool variant | "9-Ball" |
| **Sets to Win** | Race to X | 3, 5, 7 |
| **Points/Balls** | Target balls (14.1) or Sets | 100 (14.1) |
| **First Break** | Who breaks first? | "Lag" |
| **Next Break** | Who breaks after set? | "Winner", "Loser", "Alternating" |

#### 5. Start Game

After all parameters are set:

1. Review the settings once more
2. Click on **"Start Game"** or **"Continue"**
3. The scoreboard switches to **Warm-up**

#### 6. Warm-up and Shootout

See [Game Flow - Warm-up](#2-warm-up-period) and [Shootout](#3-shootout)

### Quick Tips for Training Games

**Tip 1: Create Standard Player**

Create a dummy player "Training" for quick setup:
1. Go to **Players** > **New**
2. Name: "Training"
3. First Name: "Solo"
4. Club: Your club

**Tip 2: Favorite Setups**

Frequently used configurations:
- **Straight Rail 100**: Standard practice game
- **Three-Cushion 50**: Short 3-Cushion training
- **Cadre 47/2**: Position play training

**Tip 3: Disable Timer**

For relaxed training:
- Set **Timeout to 0**
- No time limit

**Tip 4: Allow Overflow**

For continuous training:
- Enable **"Allow Overflow"**
- Play beyond target points

**Tip 5: Quickly End Game**

After training:
1. **B Key** or **Exit Icon** ⌫
2. Confirm **OK**
3. Table is immediately free again

### Differences: Training vs. Tournament

| Aspect | Training | Tournament |
|--------|----------|-----------|
| **Player Selection** | Freely selectable | Predetermined by match schedule |
| **Parameters** | Freely configurable | Predetermined by tournament rules |
| **Game Termination** | Possible at any time | Only after game end |
| **Statistics** | Not saved | Fully recorded |
| **Break Rights** | Freely selectable | According to tournament mode |

### Frequently Asked Questions (FAQ)

**Q: Can I pause a training game?**

A: Yes, click on the **Home Icon** 🏠. The game remains active in the background. Select the table again to continue.

**Q: Are training statistics saved?**

A: No, training games are not included in official statistics. For statistical recording, you should create an official game or tournament.

**Q: Can I change parameters during a training session?**

A: No, parameters are fixed after game start. You must end the game and start new to make changes.

**Q: What happens if I close the browser?**

A: The game continues running on the server. Open the browser again and navigate to the table to continue. Points saved in the meantime are retained.

**Q: Can I run two training games simultaneously on different tables?**

A: Yes, each table can have its own game. Simply start a separate game for each table.

---

## Keyboard Reference (Overview)

### Main Keyboard Functions

| Mode | Key | Action |
|------|-----|--------|
| **Pointer** | ← / PgUp | Player A +1 point |
| **Pointer** | → / PgDn | Player B +1 point |
| **Pointer** | B | Timer area |
| **Pointer** | ↓ / Enter | Activate pointer element |
| **Timer** | B | Input area |
| **Timer** | ↓ / Enter | Timer action |
| **Input** | B | Next element (→) |
| **Input** | ← | Previous element (←) |
| **Input** | ↓ / Enter | Activate element |
| **Numbers** | 0-9 | Enter digit |
| **Numbers** | Del | Delete last digit |
| **Numbers** | Esc | Cancel |
| **Numbers** | ↓ / Enter | Confirm |
| **All** | Esc / B | Back / Exit |
| **All** | F5 | Reload |
| **All** | F11 | Fullscreen |
| **All** | F12 | Exit (Kiosk) |

### Undo/Edit Functions (Edit Innings List)

| Button | Function | Description |
|--------|----------|-------------|
| **Undo** | Cursor ← | Move cursor one inning back (points remain unchanged) |
| **Next** | Cursor → | Move cursor one inning forward (at last position: player switch) |
| **+1, +5, +10** | Points + | Increase points at current cursor position |
| **-1, -5, -10** | Points - | Decrease points at current cursor position |

**Important:** After editing with Undo, always return to current inning with "Next"!

---

## Appendix B: Undo/Edit Function (Edit Innings List)

⚠️ **Frequently misunderstood:** The "Undo" button is **not** a simple undo function, but a powerful **editing tool** for the innings list!

**Exception:** For Pool billiards, Undo actually works as a true undo function.

### How the Innings List Works

Below the main scores of both players, you see the **innings list**:

```
Player A                     Player B
   45                           38
┌─────────────┐            ┌─────────────┐
│ [5][8][12][│20│]         │ [6][7][10][│15│] │  ← Innings
└─────────────┘            └─────────────┘
   ▲                          ▲
   First                      Currently editable
   Inning                     (framed = Cursor)
```

- **First inning** is on the left
- **Current inning** is on the right and marked by a frame (cursor)
- Each number shows the points in that inning

### Cursor Navigation

**With Undo (cursor left):**

1. Press **Undo**
2. The cursor jumps to the **previous inning** of the current player
3. The point values remain **unchanged**

**With Next/Switch (cursor right):**

1. Press **Next**
2. The cursor jumps to the **next inning** (alternating A/B)
3. When at the last inning, a player switch is executed

### Editing Points

When the cursor is on an inning:

1. Use **-1, -5, -10** to reduce points
2. Use **+1, +5, +10** to increase points
3. The total score is **automatically recalculated**

### Step-by-Step Example 1: Correct Error in Previous Inning

**Situation:**
- Player A just made 8 points
- You notice that the inning before had 12 instead of 10 points entered

**Solution:**

```
Starting situation:
Player A: [5][10][│8│]  (Cursor on current inning)
Total score: 23

Step 1: Press Undo
Player A: [5][│10│][8]  (Cursor on previous inning)

Step 2: Press "-1" twice
Player A: [5][│8│][8]   (10 → 8)
Total score: 21 ✓       (automatically corrected)

Step 3: Press "Next"
Player A: [5][8][│8│]   (Cursor back to current inning)
```

**Important:** After editing, you **MUST** navigate back to the current inning with "Next"!

### Step-by-Step Example 2: Multiple Innings Back

**Situation:**
- Player A: [6][8][10][│12│]
- You want to correct the second inning (8) to 7

**Solution:**

```
Starting situation:
Player A: [6][8][10][│12│]  (Cursor at position 4)
Total score: 36

Step 1: Press Undo (1x)
Player A: [6][8][│10│][12]  (Cursor at position 3)

Step 2: Press Undo (2x)
Player A: [6][│8│][10][12]  (Cursor at position 2)

Step 3: Press "-1"
Player A: [6][│7│][10][12]  (8 → 7)
Total score: 35 ✓

Step 4: Press "Next" (1x)
Player A: [6][7][│10│][12]  (Cursor at position 3)

Step 5: Press "Next" (2x)
Player A: [6][7][10][│12│]  (Cursor back at position 4)
```

### Step-by-Step Example 3: Editing Both Players

**Situation:**
- Player A just played: [5][│8│]
- Player B should play now: [6][│--│]
- You need to correct Player A's first inning from 5 to 6

**Solution:**

```
Starting situation:
Player A: [5][│8│]  (Cursor here)
Player B: [6][--]

Step 1: Press Undo
Player A: [│5│][8]  (Cursor at position 1)

Step 2: Press "+1"
Player A: [│6│][8]  (5 → 6)

Step 3: Press "Next" (1x)
Player A: [6][│8│]  (back to position 2)

Step 4: Press "Next" (2x) - executes player switch
Player A: [6][8]
Player B: [6][│--│]  ✓ (ready for new inning)
```

### Important Notes

**✅ DO:**
- Navigate cursor consciously
- **Always** return to current inning after editing
- Visually verify changes (total score)

**❌ DON'T:**
- Leave cursor somewhere
- Continue playing without navigation
- Blindly press "Undo" multiple times

### Common Errors

**Error 1: "I pressed Undo, but nothing happened"**

→ You didn't change the points! Undo **only moves the cursor**, points stay the same.

**Solution:** After Undo, adjust points with +/- buttons.

**Error 2: "After Undo, the score shows wrong values"**

→ The cursor is still on an old inning, not the current one.

**Solution:** Navigate back to current inning with "Next".

**Error 3: "I can't get back"**

→ You've lost track of where the cursor is.

**Solution:** 
1. Look at the innings list - the framed number shows the cursor
2. Press "Next" until you're back at the last inning
3. In emergency: Press F5 (reload page)

### When to Use?

**Typical Use Cases:**

✅ **Correct typos**
- You accidentally entered 8 instead of 6

✅ **Change points retroactively**
- Referee decision corrects an earlier inning

✅ **Resolve discussions**
- Players disagree about an earlier inning
- You can go back and correct

**Don't use for:**

❌ **Change current inning**
- Use +/- buttons instead

❌ **Switch players**
- Use the "Next" button

### Summary

| Key | Function | Effect on Cursor | Effect on Points |
|-----|----------|-----------------|------------------|
| **Undo** | Cursor back | ← One position back | None |
| **Next** | Cursor forward / Player switch | → One position forward | None |
| **+1, +5, +10** | Add points | None | Increases value at cursor position |
| **-1, -5, -10** | Subtract points | None | Decreases value at cursor position |

**Remember:** 
> Undo = Move cursor, +/- = Change points, Next = back to current inning

### 💡 Suggestion for Future Improvement

#### Solution 1: Game Protocol Modal (RECOMMENDED)

The current Undo/Edit function is complex and error-prone. A much better solution would be a **Game Protocol Modal**:

**Concept:**

Replace "Undo" button with **[📋 Game Protocol]**

Clicking opens a modal with complete overview:

```
┌─────────────────── Game Protocol ────────────────────┐
│                                                       │
│  Player A: John Doe          Player B: Jane Smith   │
│                                                       │
│  Inng. │ Points │ Total     Inng. │ Points │ Total  │
│  ──────┼────────┼─────     ──────┼────────┼───── │
│    1   │   5    │   5         1   │   6    │   6    │
│    2   │   8    │  13         2   │   7    │  13    │
│    3   │  12    │  25         3   │  10    │  23    │
│    4   │  20    │  45         4   │  15    │  38    │
│                                                       │
│  [Edit] [Done] [Print]                               │
└───────────────────────────────────────────────────────┘
```

**In Edit Mode:**

```
┌─────────────────── Game Protocol (Edit) ─────────────┐
│                                                       │
│  Inng. │ Points      │ Total     Inng. │ Points │... │
│  ──────┼─────────────┼─────     ──────┼────────┼──  │
│    1   │  5 [↑][↓]  │   5         1   │   6 [↑][↓] │
│    2   │  8 [↑][↓]  │  13         2   │   7 [↑][↓] │
│    3   │ 12 [↑][↓]  │  25         3   │  10 [↑][↓] │
│        │  [+ Insert inning]                           │
│                                                       │
│  [Save] [Cancel]                                     │
└───────────────────────────────────────────────────────┘
```

**Advantages:**

✅ **Clear Overview**
- ALL innings visible at a glance
- No hidden cursor navigation
- Complete game history immediately visible

✅ **Intuitive**
- Everyone understands tables
- Clear Edit mode on/off
- Arrows ↑↓ are self-explanatory

✅ **Safe**
- Accidental changes impossible (readonly in view mode)
- Clear separation: View vs. Edit
- "Done" unambiguously exits back to game

✅ **Powerful**
- **Insert rows** for forgotten player switches!
- Complex corrections possible
- Fix multiple errors at once

✅ **Professional**
- **Print function** for game protocol
- Documentation of game progression
- Archiving for tournaments

**Features:**

1. **View Mode (Default)**
   - Readonly table
   - Scrollbar for many innings
   - Current inning highlighted
   - Buttons: [Edit] [Done] [Print]

2. **Edit Mode**
   - All points with [↑] [↓] buttons
   - Totals automatically recalculated
   - [+ Insert inning] between rows
   - Buttons: [Save] [Cancel]

3. **Print**
   - Print-optimized layout
   - Date, players, final result
   - Optional: PDF export

**Use Case: Forgotten Player Switch**

Problem: After inning 3 of Player A, forgot to switch, he played inning 4 directly.

Solution:
1. Open [📋 Game Protocol]
2. Click [Edit]
3. Between row 3 and 4 of Player A: [+ Insert inning]
4. New empty row is inserted
5. Move points from inning 4 to new row
6. [Save]

This would be a complete redesign, but **significantly more user-friendly** than the current solution.

---

#### Solution 2: Three Separate Buttons (Alternative)

If the modal solution is too complex, a simpler improvement would be:

The current button assignment is confusing because:
- "Undo" sounds like "Undo", but is actually "Cursor back"
- "Next" has two meanings: "Cursor forward" AND "Player switch"

**Simplified Solution:**

Three separate, clear buttons:

```
[◄ Cursor back] [Cursor forward ►] [✓ Done]
```

**Advantages:**
- ✅ Each button has **exactly one** function
- ✅ Self-explanatory labels
- ✅ "✓ Done" makes clear: "Finish editing"
- ✅ Users can't get "stuck"

**Disadvantages compared to Game Protocol Modal:**
- ❌ No complete overview
- ❌ Still hidden navigation
- ❌ No print function
- ❌ No ability to insert rows

---

**Recommendation:** Solution 1 (Game Protocol Modal) is significantly better and fundamentally solves all problems.

---

## Support and Help

For problems or questions:

1. **Documentation**: Read this guide thoroughly
2. **Contact Administrator**: Your club administrator can help
3. **GitHub Issues**: [https://github.com/GernotUllrich/carambus/issues](https://github.com/GernotUllrich/carambus/issues)

---

## Version

This manual applies to Carambus version 2.0 and higher.

Last updated: November 2025

