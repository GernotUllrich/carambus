# Pool Scoreboard User Manual

## Overview

The Carambus Pool Scoreboard is a complete display system for pool billiards games that can be used for both tournaments and training games. It supports all common pool disciplines:

- **8-Ball** - Classic 8-ball with rack counting
- **9-Ball** - 9-ball with rack counting
- **10-Ball** - 10-ball with rack counting
- **14.1 Continuous** - Straight Pool with point counting

## Main Functions

- **Score Display** - Real-time display of scores/racks for both players
- **Ball Display** - Visual representation of remaining balls (14.1 continuous)
- **Inning Counter** - Automatic counting of innings in 14.1 continuous
- **Rack Management** - Automatic rack counting for all disciplines
- **Foul Tracking** - Recording fouls with point deduction
- **Dark Mode** - Eye-friendly display for different lighting conditions

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Pool Disciplines Overview](#pool-disciplines-overview)
3. [Scoreboard Main View](#scoreboard-main-view)
4. [14.1 Continuous (Straight Pool)](#141-continuous-straight-pool)
5. [8-Ball, 9-Ball, 10-Ball](#8-ball-9-ball-10-ball)
6. [Game Flow](#game-flow)
7. [Key Bindings](#key-bindings)
8. [Quickstart Games](#quickstart-games)
9. [Troubleshooting](#troubleshooting)

---

## Getting Started

### Starting the Scoreboard

1. **Raspberry Pi Setup**: The scoreboard starts automatically when booting the Raspberry Pi
2. **Manual Start**: Open a browser and navigate to:
   ```
   http://[server-address]:3000/locations/[location-id]/scoreboard?sb_state=welcome
   ```
3. **From Location Page**: Click on the "scoreboard" link

### Welcome Screen

The welcome screen is the starting point for all scoreboard activities. From here you can:

- **Select Tournament** - For official pool tournaments
- **Select Table** - For training games
- **Show Scores** - Overview of ongoing games

### Table Overview

After selecting "Training", the table overview appears with all available pool and snooker tables:

![Table Overview](screenshots/pool_tables_overview.png)

- **Blue Buttons**: Free tables
- **Player Names**: Tables with ongoing games

---

## Pool Disciplines Overview

### 8-Ball

The classic pool game with 15 balls:
- Player A: Solids (1-7) or Stripes (9-15)
- Player B: The other group
- Won by correctly pocketing the 8

**Scoreboard Display:** Rack count (e.g. "Race to 5")

### 9-Ball

Rotation with 9 balls:
- Balls must be contacted in numerical order
- Won by pocketing the 9

**Scoreboard Display:** Rack count (e.g. "Race to 7")

### 10-Ball

Similar to 9-ball, but with 10 balls:
- Balls must be contacted in numerical order
- Won by pocketing the 10
- Call shot required

**Scoreboard Display:** Rack count (e.g. "Race to 9")

### 14.1 Continuous (Straight Pool)

The most demanding pool game:
- 15 balls are racked
- Each pocketed ball counts 1 point
- When 1 or 0 balls remain, a re-rack occurs (14 balls)
- Played to a target score (e.g. 100, 125, 150)

**Scoreboard Display:** Point count with ball display and inning stack

---

## Scoreboard Main View

### Layout for 8-Ball, 9-Ball, 10-Ball

```
┌─────────────────────────────────────────────────────┐
│  [Dark Mode] [Undo] [Redo] [Home] [End]              │
│                                                       │
│  Player A                          Player B          │
│  ┌─────────────────┐              ┌─────────────────┐│
│  │                 │              │                 ││
│  │      3          │              │      2          ││
│  │                 │              │                 ││
│  │  Race to 5      │              │  Race to 5      ││
│  └─────────────────┘              └─────────────────┘│
│                                                       │
│  [Rack A] [Rack B]                                   │
└─────────────────────────────────────────────────────┘
```

### Layout for 14.1 Continuous

```
┌─────────────────────────────────────────────────────┐
│  [Dark Mode] [Undo] [Redo] [Home] [End]              │
│                                                       │
│  Player A (active)                  Player B         │
│  ┌─────────────────┐              ┌─────────────────┐│
│  │  Inning: 12     │              │  Inning: --     ││
│  │                 │              │                 ││
│  │  Goal: 100      │              │  Goal: 100      ││
│  │  Avg: 8.50      │              │  Avg: 6.20      ││
│  │  HS: 23         │              │  HS: 18         ││
│  │                 │              │                 ││
│  │      67  ←──────│──────────────│───── 52         ││
│  │   (click=+1)    │              │  (click=switch) ││
│  └─────────────────┘              └─────────────────┘│
│                                                       │
│  Inning Stack: 15 | 29 | 43 | 57 | 67                │
│                                                       │
│  [0][1][2][3][4][5][6][7][8][9][10][11][12][13][14][15] [F1] [F2] │
└─────────────────────────────────────────────────────┘
```

**Clickable Areas:**
- **Active player's score** (67): Click = +1 point
- **Inactive player's score** (52): Click = switch players

### 14.1 Continuous Scoreboard in Action

![14.1 Continuous Scoreboard - Game Start](screenshots/pool_14_1_scoreboard_start.png)

*Game start: Both players at 0, 15 balls on table*

![14.1 Continuous Scoreboard - During Game](screenshots/pool_14_1_scoreboard_playing.png)

*During game: Player A (green frame) is active, has 6 points, 9 balls remain*

![14.1 Continuous Scoreboard - After Player Switch](screenshots/pool_14_1_after_switch.png)

*After player switch: Player B (green frame) is now active, Avg and HS updated*

### Display Elements for 14.1 Continuous

#### Player Information (per side)

1. **Player Name** - Full name or short name
2. **Current Inning** - Points in current inning (highlighted in red)
3. **Goal** - Target score (e.g. 100, 125, 150)
4. **Avg (Grand Average)** - Average points per inning
5. **HS (High Series)** - Best single inning in game
6. **Total Points** - Large score in center

#### Inning Stack

The inning stack shows intermediate scores after each re-rack:
- Each number represents the score after a re-rack
- Example: `15 | 29 | 43` means:
  - After 1st re-rack: 15 points
  - After 2nd re-rack: 29 points
  - After 3rd re-rack: 43 points

#### Ball Control Bar (only 14.1 continuous)

The bottom bar shows balls from 0 to 15:
- **Clickable Balls**: Show remaining balls on table
- **Ball 0 (white)** and **Ball 1 (yellow)**: Automatically trigger re-rack
- **F1**: Foul (-1 point)
- **F2**: Break foul (-2 points, only with full table)

---

## 14.1 Continuous (Straight Pool)

### Rules Summary

14.1 continuous is the classic point game in pool billiards:

1. **Setup**: 15 balls in triangle
2. **Goal**: Reach a predetermined score (typical: 100, 125, 150)
3. **Points**: Each correctly pocketed ball = 1 point
4. **Re-rack**: When 1 or 0 balls remain, 14 balls are re-racked
5. **Fouls**: -1 point per foul, 3 consecutive fouls: -15 points

### Operating the Scoreboard

#### Entering Points

**Method 1: Ball Click (recommended for multiple balls)**

Click on the ball corresponding to the number of **remaining** balls on the table:

- Example: 12 balls on table → Click ball "12"
- System automatically calculates pocketed balls

**Method 2: Click on Own Score (+1 point)**

For single points, click directly on the **active player's score**:

- Click on active player's large score number
- Each click adds **+1 point**
- Ideal for quick single-point entries

**Method 3: Direct Entry**

For larger series, you can also use number input.

#### Player Switch

**Method 1: Click on Other Player's Score**

The easiest way to switch players:

- Click on **inactive player's score number**
- Player switches immediately
- Current inning is completed
- Green frame switches to new active player

**Method 2: Automatic Switch**

After an unsuccessful inning:
- Active player switches automatically
- Green frame shows new active player

> **Tip:** Clicking on opponent's score is the fastest method for player switch and is preferred by experienced referees.

#### Re-rack (Rerack)

When clicking on **Ball 1** or **Ball 0**:
1. Pocketed balls are counted
2. Inning stack is updated
3. Ball counter jumps to 15 (or 14 + remaining ball)

**Ball 1 (yellow)**: 14 balls pocketed, 1 ball remains
**Ball 0 (white)**: All 15 balls pocketed (break-and-run to re-rack)

#### Fouls

**F1 - Simple Foul (-1 point)**
- Click the **F1** button
- Player receives -1 point
- A foul marker appears
- After 3 consecutive fouls: Automatic -15 additional points

**F2 - Break Foul (-2 points)**
- Only active with full table (15 balls)
- Typical for failed break shots
- Click the **F2** button

### Example Game Flow 14.1 Continuous

1. **Start**: Both players have 0 points, 15 balls on table
2. **Player A** pockets 5 balls → Click ball "10" (10 balls left)
3. **Player A** pockets 4 more balls → Click ball "6" (6 balls left)
4. **Player A** pockets 5 more balls → Click ball "1" (Re-rack!)
   - Stack shows: `14`
   - Ball counter: 15
5. **Player A** misses → Click **Player B's score** → Player switch
6. **Player B** pockets 1 ball → Click **own score** (+1 point)
7. **Player B** pockets 1 more ball → Click **own score** (+1 point)
8. **Player B** misses → Click **Player A's score** → Player switch
9. Etc.

### Input Summary

| Action | Input |
|--------|-------|
| **+1 Point** | Click on own score |
| **+X Points** | Click on ball with remaining count |
| **Player Switch** | Click on opponent's score |
| **Foul (-1)** | Click on F1 |
| **Break Foul (-2)** | Click on F2 (only with 15 balls) |
| **Re-rack** | Click on ball 0 or 1 |

---

## 8-Ball, 9-Ball, 10-Ball

### Operating the Scoreboard

For these disciplines, games are played in racks (e.g. "Race to 5").

#### Winning a Rack

Click on the corresponding button:
- **Rack A**: Player A wins the rack
- **Rack B**: Player B wins the rack

#### Match End

The game ends automatically when a player wins the required number of racks.

### Example: 9-Ball Race to 5

1. **Start**: 0:0
2. Player A wins Rack 1 → Click "Rack A" → 1:0
3. Player B wins Rack 2 → Click "Rack B" → 1:1
4. ... (more racks)
5. Player A reaches 5 racks → Match won!

---

## Game Flow

### 1. Select Table

1. From **Welcome Screen** choose **"Tables"**
2. Select a **Pool Table** (recognizable by table type)
3. Click on desired table

### 2. Choose Game Type

After selecting the table, pool options appear:

**Quickstart Buttons:**
- **8-Ball Race to 3/5/7**
- **9-Ball Race to 5/7/9**
- **10-Ball Race to 5/7/9**
- **14.1 Continuous 50/75/100/125/150**

**Or:** Detailed configuration via "New Pool Game"

### 3. Select Players

1. Click **"Player A"**
2. Select player from list
3. Repeat for **"Player B"**

### 4. Lag

Determine who starts the game:
1. Both players lag from headstring
2. Choose winner:
   - **"Player A"**: Player A wins the lag
   - **"Player B"**: Player B wins the lag
3. **Start Game**

### 5. Game Running

Depending on discipline:
- **14.1 continuous**: Ball clicks for point entry
- **8/9/10-Ball**: Rack buttons for rack wins

### 6. Game End

- **14.1 continuous**: When a player reaches target score
- **8/9/10-Ball**: When a player wins required racks

---

## Key Bindings

### Main Keys

| Key | Function | Description |
|-----|----------|-------------|
| **Left Arrow** | Player A | Rack for Player A (8/9/10-Ball) |
| **Right Arrow** | Player B | Rack for Player B (8/9/10-Ball) |
| **Up Arrow** | Navigation | Next element |
| **Down Arrow** | Action | Activate element |
| **B** | Back/Forward | Navigation |
| **Esc** | Back | To previous screen |
| **Enter** | Confirm | Confirm selection |

### Special Keys

| Key | Function |
|-----|----------|
| **F5** | Reload page |
| **F11** | Fullscreen mode |
| **F12** | Exit scoreboard |

---

## Quickstart Games

### Pool Presets

![Pool Quickstart Buttons](screenshots/pool_quickstart_buttons.png)

*Quick selection for pool games: 8-ball, 9-ball, 10-ball and 14.1 continuous*

For quick start without many settings:

#### 8-Ball
- **8-Ball Race to 3** - Short match
- **8-Ball Race to 5** - Standard match
- **8-Ball Race to 7** - Long match

#### 9-Ball
- **9-Ball Race to 5** - Short match
- **9-Ball Race to 7** - Standard match
- **9-Ball Race to 9** - Long match

#### 10-Ball
- **10-Ball Race to 5** - Short match
- **10-Ball Race to 7** - Standard match
- **10-Ball Race to 9** - Long match

#### 14.1 Continuous
- **14.1 Continuous 50** - Short game (training)
- **14.1 Continuous 75** - Medium game
- **14.1 Continuous 100** - Standard match
- **14.1 Continuous 125** - Long match
- **14.1 Continuous 150** - Tournament standard

### Using Quickstart

1. Select table
2. Click on desired quickstart button
3. Select Player A and B
4. **Start Game**

---

## Menu and Navigation

### Main Menu Icons

| Icon | Function | Description |
|------|----------|--------------|
| 🌓 | Dark Mode | Toggle light/dark mode |
| ↩️ | Undo | Undo last action |
| ↪️ | Redo | Restore undone action |
| 🏠 | Home | Return to welcome screen |
| ⌫ | End | End game (with confirmation) |

### Undo/Redo

For input errors:
1. Click **Undo** (↩️) to undo last action
2. Click **Redo** (↪️) to restore it

---

## Troubleshooting

### Ball Display Not Updating (14.1 continuous)

**Solution:**
1. Press **F5** to reload page
2. Correct score will be restored

### Points Not Being Saved

**Cause:** Network connection interrupted

**Solution:**
1. Check network connection
2. Reload page (F5)
3. During longer interruption: Note score manually

### Wrong Player Active

**Solution:**
1. Use **Undo** to return to correct position
2. Or: End game and restart

### Foul Counter Wrong

**Solution:**
1. For 14.1 continuous: Use **Undo** multiple times
2. Foul markers are automatically corrected

### Scoreboard Not Responding

**Solution:**
1. Press **F5** to reload page
2. If that doesn't help: Close and restart browser
3. In emergency: Restart Raspberry Pi

---

## Differences: Pool vs. Carom

| Aspect | Pool | Carom |
|--------|------|-------|
| **Point Counting** | Balls/Racks | Caroms |
| **Input** | Ball clicks / Rack buttons | Number input |
| **Re-rack** | At 0-1 balls (14.1) | Not relevant |
| **Fouls** | -1/-2 points (14.1) | No point deduction |
| **Timer** | Rarely used | Frequently used |
| **Innings** | Counted (14.1) | Always counted |

---

## Glossary

| Term | Explanation |
|------|-------------|
| **Break** | Opening shot |
| **Rack** | A set/frame in 8/9/10-ball |
| **Rerack/Re-rack** | New setup of balls in 14.1 |
| **Lag** | Determination of break rights |
| **Race to X** | Whoever wins X racks first |
| **Run** | Series of pocketed balls without miss |
| **Safety** | Safety shot |
| **Foul** | Rule violation with penalty points |
| **Avg** | Grand average (points per inning) |
| **HS** | High series (best inning in game) |

---

## Support and Help

For problems or questions:

1. **Documentation**: Read this manual thoroughly
2. **Contact Administrator**: Your club administrator can help
3. **GitHub Issues**: [https://github.com/GernotUllrich/carambus/issues](https://github.com/GernotUllrich/carambus/issues)

---

## Version

This manual applies to Carambus version 2.0 and higher.

Last update: December 2025





