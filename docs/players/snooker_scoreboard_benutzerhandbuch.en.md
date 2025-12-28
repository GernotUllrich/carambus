# Snooker Scoreboard User Manual

## Overview

The Carambus Snooker Scoreboard is a complete display system for snooker games that can be used for both tournaments and training games. It supports the classic snooker discipline with frame counting.

## Main Functions

- **Frame Display** - Real-time display of won frames for both players
- **Break Display** - Current break points of active player
- **High Break (HB)** - Highest break of each player in the game
- **Frame Management** - Automatic frame counting (Best of 3, 5, 7, 9)
- **Ball Value Buttons** - Color-coded buttons for all snooker balls (Red=1, Yellow=2, Green=3, Brown=4, Blue=5, Pink=6, Black=7)
- **Pyramid Display** - Visually realistic representation of red balls (6/10/15 Reds) with perspective 3D view
- **Remaining Points Display** - Live calculation of remaining points on the table
- **Concede Function** - Ability for players to concede a frame early
- **Intelligent Ball Management** - Automatic detection of playable balls (red/colored) with visual highlighting
- **Dark Mode** - Eye-friendly display for different lighting conditions

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Snooker Rules Overview](#snooker-rules-overview)
3. [Scoreboard Main View](#scoreboard-main-view)
4. [Game Flow](#game-flow)
5. [Key Bindings](#key-bindings)
6. [Quickstart Games](#quickstart-games)
7. [Troubleshooting](#troubleshooting)

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

- **Select Tournament** - For official snooker tournaments
- **Select Table** - For training games
- **Show Scores** - Overview of ongoing games

### Table Overview

After selecting "Training", the table overview appears with all available pool and snooker tables:

- **Blue Buttons**: Free tables
- **Player Names**: Tables with ongoing games

---

## Snooker Rules Overview

### Basic Rules

Snooker is played with 22 balls:

**Red Balls:**
- 15 red balls (each worth 1 point)
- At the start of the frame, all 15 red balls are racked

**Colored Balls:**
- Yellow (2 points)
- Green (3 points)
- Brown (4 points)
- Blue (5 points)
- Pink (6 points)
- Black (7 points)

**White Ball:**
- The white cue ball

### Game Flow

1. **Red Phase**: Player must first pocket a red ball (1 point)
2. **Colored Phase**: After a red ball, a colored ball must be pocketed
3. **Repeat**: Red → Color → Red → Color ... until all red balls are pocketed
4. **Colored Phase**: After red balls, colored balls must be pocketed in ascending order: Yellow → Green → Brown → Blue → Pink → Black

### Winning a Frame

A frame is won when:
- A player pockets all balls (Maximum Break: 147 points)
- Opponent concedes
- Opponent commits more fouls than points scored

### Winning a Match

A match is won when a player wins the required number of frames:
- **Best of 3**: Win 2 frames
- **Best of 5**: Win 3 frames
- **Best of 7**: Win 4 frames
- **Best of 9**: Win 5 frames

### Fouls

Common fouls in snooker:
- **Ball not hit**: Minimum 4 points penalty (or value of ball if higher)
- **Wrong ball hit**: Penalty equals value of wrong ball
- **Ball pocketed but wrong ball**: Penalty equals value of pocketed ball
- **White ball pocketed**: Minimum 4 points penalty

**Important**: In case of a foul, opponent receives penalty points.

---

## Scoreboard Main View

### Layout

```
┌─────────────────────────────────────────────────────┐
│  [Dark Mode] [Undo] [Home] [End]                     │
│                                                       │
│  Player A (active)                  Player B         │
│  ┌─────────────────┐              ┌─────────────────┐│
│  │  Break: 24      │              │  Break: --      ││
│  │                 │              │                 ││
│  │  Frames: 1 / 3  │              │  Frames: 0 / 3  ││
│  │  HB: 45         │              │  HB: 32         ││
│  │                 │              │                 ││
│  │      1  ←───────│──────────────│───── 0          ││
│  │   (click=+1)    │              │  (click=switch) ││
│  └─────────────────┘              └─────────────────┘│
│                                                       │
│  [●●●●●●]  ← Pyramid (15 Reds)                      │
│  42 Points Remaining                                 │
│                                                       │
│  Frame 1                                             │
│  Best of 5                                           │
│                                                       │
│  [Protocol] [●] [●●] [●●●] [●●●●] [●●●●●] [●●●●●●]  │
│              6   Foul  Concede   Calc                │
│  [Red=1] [Yellow=2] [Green=3] [Brown=4] [Blue=5]    │
│  [Pink=6] [Black=7]                                  │
└─────────────────────────────────────────────────────┘
```

**Clickable Areas:**
- **Active player's frame score** (1): Click = +1 point to current break
- **Inactive player's frame score** (0): Click = player switch

**New Visual Elements:**
- **Pyramid Display**: Shows remaining red balls as 3D pyramid (dynamic based on chosen number: 6/10/15 Reds)
- **Remaining Points**: Automatically calculates maximum achievable points on table
- **Red Ball Counter**: Shows number of remaining red balls directly on red ball button

### Display Elements

#### Player Information (per side)

1. **Player Name** - Full name or short name
2. **Current Break** - Points in current inning (highlighted in red, only for active player)
3. **Frames** - Won frames / Frames to win (e.g. "1 / 3" means 1 frame won, 3 frames to win)
4. **HB (High Break)** - Highest break in current game
5. **Frame Score** - Large display of won frames in center

#### Central Display

- **Frame Number** - Current frame (e.g. "Frame 1")
- **Match Format** - Best of X (e.g. "Best of 5")
- **Tournament Information** - Tournament name, round, game name (if in tournament)

#### Ball Value Buttons (only in fullscreen mode)

The bottom bar shows color-coded buttons for all snooker balls:

- **Red (1 point)** - Red balls (shows number of remaining red balls)
- **Yellow (2 points)** - Yellow ball
- **Green (3 points)** - Green ball
- **Brown (4 points)** - Brown ball
- **Blue (5 points)** - Blue ball
- **Pink (6 points)** - Pink ball
- **Black (7 points)** - Black ball
- **Foul** - Foul entry (minimum penalty 4 points)
- **Concede** - End frame early (opponent wins frame)
- **Calculator** - Direct number entry for larger breaks

**Intelligent Ball Display:**
- **Playable balls** are displayed normally and are clickable
- **Non-playable balls** are dimmed and not clickable
- System automatically detects which balls are "on" (red or colored)
- After a red ball, all colored balls are playable
- After a colored ball (when red balls remain), only red is playable
- When no red balls remain, colored balls are played in order (Yellow → Green → Brown → Blue → Pink → Black)

---

## Game Flow

### 1. Select Table

1. From **Welcome Screen** choose **"Tables"**
2. Select a **Snooker Table** (recognizable by table type)
3. Click on desired table

### 2. Choose Game Type

After selecting the table, snooker options appear:

**Quickstart Buttons:**
- **Best of 3** (2 frames to win)
- **Best of 5** (3 frames to win)
- **Best of 7** (4 frames to win)
- **Best of 9** (5 frames to win)

**Or:** Detailed configuration via "New Snooker Game"

### 3. Select Players

- **Player Selection**: Choose both players from list
- **New Player**: Register a new guest player

### 4. Set Game Parameters

- **Frames**: Choose match format (Best of 3/5/7/9)
- **Red Balls**: Choose number of starting red balls (6 Reds, 10 Reds or 15 Reds)
  - **6 Reds**: Quick training (approx. 15-20 min per frame)
  - **10 Reds**: Medium length (approx. 25-35 min per frame)
  - **15 Reds**: Full snooker (approx. 40-60 min per frame)
- **Game Time**: Set maximum playing time per frame (optional)
- **Warning Time**: Set warning time before expiration (optional)
- **First Break**: Lag, Player A or Player B

### 5. Start Game

Click **"Start Game"** - the scoreboard displays the score.

---

## Key Bindings

### Entering Points

**Method 1: Ball Value Buttons (recommended)**

Click on the color-coded button corresponding to the pocketed ball:

- **Red Button**: Red ball pocketed → +1 point
- **Yellow Button**: Yellow ball pocketed → +2 points
- **Green Button**: Green ball pocketed → +3 points
- **Brown Button**: Brown ball pocketed → +4 points
- **Blue Button**: Blue ball pocketed → +5 points
- **Pink Button**: Pink ball pocketed → +6 points
- **Black Button**: Black ball pocketed → +7 points

**Example:**
- Player pockets red ball → Click **Red Button (1)** → Break: +1
- Player then pockets blue ball → Click **Blue Button (5)** → Break: +6 (1+5)
- Player pockets another red ball → Click **Red Button (1)** → Break: +7 (1+5+1)

**Method 2: Click on Own Frame Score (+1 point)**

For single points, click directly on **active player's frame score**:

- Click on active player's large frame number
- Each click adds **+1 point** to current break
- Ideal for quick single-point entries (e.g. red balls)

**Method 3: Direct Entry (Calculator)**

For larger breaks, use the calculator function:

- Click **Calculator Button**
- Enter total break points
- System automatically takes over points

### Player Switch

**Method 1: Click on Other Player's Frame Score**

The easiest way to switch players:

- Click on **inactive player's frame number**
- Player switches immediately
- Current break is completed and added to frame score
- Green frame switches to new active player
- Break counter is reset

**Method 2: Automatic Switch**

After a foul or when player scores no points:
- Active player switches automatically
- Green frame shows new active player

> **Tip:** Clicking on opponent's frame score is the fastest method for player switch and is preferred by experienced referees.

### Ending Frame

A frame ends automatically when:
- A player pockets all balls
- A player concedes (via **"Concede"** button)
- Maximum is reached

**Concede Function:**
- Click **"Concede"** button (orange, right in control bar)
- Confirm action in dialog
- Opponent wins frame with current score
- System calculates frame winner based on points scored
- Next frame starts automatically (if match not ended)

After frame end:
- Frame score is updated
- Frame counter increases
- Protocol modal shows frame result
- During ongoing match: Click "Confirm" to go to next frame
- At match end: Final result is displayed

### Match End

Match ends automatically when a player wins required number of frames:

- **Best of 3**: 2 frames won
- **Best of 5**: 3 frames won
- **Best of 7**: 4 frames won
- **Best of 9**: 5 frames won

After match end:
- System displays final result
- You can view protocol
- Game can be ended

### Entering Fouls

For fouls there are various options:

**Option 1: Deduct Points**
- Use **Undo function** or **-1/-5/-10 buttons** to deduct points
- Then perform **player switch**

**Option 2: Direct Entry**
- Use **Calculator** to enter corrected score
- Then perform **player switch**

**Important**: In case of foul, opponent receives penalty points. This must be entered manually via calculator or point buttons.

### Example Game Flow

**Frame 1 - Best of 5:**

1. **Start**: Both players have 0 frames, Frame 1 begins
2. **Player A** pockets red ball → Click **Red Button (1)** → Break: 1
3. **Player A** pockets blue ball → Click **Blue Button (5)** → Break: 6
4. **Player A** pockets another red ball → Click **Red Button (1)** → Break: 7
5. **Player A** misses → Click **Player B's Frame Score (0)** → Player switch
   - Break of 7 added to frame score (if frame won)
6. **Player B** pockets red ball → Click **Red Button (1)** → Break: 1
7. **Player B** misses → Click **Player A's Frame Score** → Player switch
8. ... (game continues)
9. **Player A** wins Frame 1 → Frame Score: 1:0
10. **Frame 2** starts automatically
11. ... (more frames)
12. **Player A** reaches 3 frames → Match won!

### Input Summary

| Action | Input |
|--------|-------|
| **+1 Point** (Red Ball) | Click Red Button (1) or Frame Score |
| **+2 Points** (Yellow Ball) | Click Yellow Button (2) |
| **+3 Points** (Green Ball) | Click Green Button (3) |
| **+4 Points** (Brown Ball) | Click Brown Button (4) |
| **+5 Points** (Blue Ball) | Click Blue Button (5) |
| **+6 Points** (Pink Ball) | Click Pink Button (6) |
| **+7 Points** (Black Ball) | Click Black Button (7) |
| **Foul** | Click Foul Button → Opponent receives penalty points |
| **Concede Frame** | Click Concede Button → Opponent wins frame |
| **Player Switch** | Click opponent's frame score |
| **Larger Breaks** | Use Calculator button |
| **Correction** | Undo button or -1/-5/-10 buttons |
| **Show Protocol** | Click Protocol button (left) |

---

## Quickstart Games

### Best of 3 (2 frames to win)

Ideal for quick training games:
- Click **"Best of 3"** button
- Select players
- Click **"Start Game"**

### Best of 5 (3 frames to win)

Standard for most games:
- Click **"Best of 5"** button
- Select players
- Click **"Start Game"**

### Best of 7 (4 frames to win)

For longer games:
- Click **"Best of 7"** button
- Select players
- Click **"Start Game"**

### Best of 9 (5 frames to win)

For tournaments and important games:
- Click **"Best of 9"** button
- Select players
- Click **"Start Game"**

---

## New Features (December 2024)

### Visual Pyramid Display

The scoreboard now shows a realistic 3D pyramid of red balls:

**Functions:**
- **6 Reds**: 3 rows (1-2-3 balls)
- **10 Reds**: 4 rows (1-2-3-4 balls)
- **15 Reds**: 5 rows (1-2-3-4-5 balls)
- **Perspective Display**: Balls shown with realistic depth effect
- **Dynamic Size**: Automatically adjusts to fullscreen/normal mode

### Remaining Points Calculation

System automatically shows remaining points on table:

**Calculation:**
- **Red Phase** (red balls still present):
  - Each red ball = 1 point
  - All 6 colored balls = 27 points (respotted after each colored ball)
  - **Example**: 5 Reds remaining → 5 + 27 = **32 points possible**

- **Colored Phase** (no red balls):
  - Only colored balls remaining in order
  - **Example**: Yellow, Green, Brown, Blue, Pink, Black remaining → 2+3+4+5+6+7 = **27 points possible**

**Benefits:**
- Players can immediately see if "snooker" (catching up impossible) exists
- Helps decide whether to concede frame
- Shows maximum possible break

### Intelligent Ball Management

System automatically detects which balls are playable:

**"On" Balls (playable):**
- Displayed normally
- Are clickable
- Show magnification effect on hover

**"Off" Balls (not playable):**
- Dimmed (30% transparency)
- Not clickable
- Show "Ball not 'on'" on hover

**Automatic Detection:**
- **After red ball**: All colored balls are "on"
- **After colored ball** (with red balls): Only red balls are "on"
- **No reds left**: Next colored ball in sequence is "on"
- **Last ball pocketed**: All balls "off" → Frame end

**Red Ball Counter:**
- Red ball button shows number of remaining red balls
- Large number displayed centered on red ball
- When 0 Reds → Ball automatically dimmed

### Concede Function

Players can concede a frame early:

**Usage:**
1. Click orange **"Concede"** button
2. Confirm in dialog "Do you really want to concede the frame?"
3. Frame ends immediately

**Result:**
- Frame winner determined by points (higher score wins)
- Points of both players correctly saved
- Next frame starts automatically (if match not ended)
- At match end: Final result modal displayed

**When to Concede?**
- When "snooker" exists (catching up impossible)
- When point difference is too large
- In difficult game situation

### Variable Number of Red Balls

System now supports three different frame lengths:

**6 Reds (Quick Training):**
- **Duration**: approx. 15-20 minutes per frame
- **Maximum Break**: 75 points (6×1 + 6×7 + 27)
- **Ideal for**: Beginners, quick training sessions, time pressure
- **Pyramid**: 3 rows (1-2-3)

**10 Reds (Medium):**
- **Duration**: approx. 25-35 minutes per frame
- **Maximum Break**: 107 points (10×1 + 10×7 + 27)
- **Ideal for**: Advanced, club games, moderate length
- **Pyramid**: 4 rows (1-2-3-4)

**15 Reds (Full):**
- **Duration**: approx. 40-60 minutes per frame
- **Maximum Break**: 147 points (15×1 + 15×7 + 27)
- **Ideal for**: Tournaments, experienced players, official matches
- **Pyramid**: 5 rows (1-2-3-4-5)

**Selection:**
- At game start: Choose desired number of red balls
- Pyramid display adjusts automatically
- Remaining points calculation considers chosen number

---

## Tips for Efficient Operation

### Quick Break Entry

1. **For red balls**: Use **Frame Score click** (+1) - fastest
2. **For colored balls**: Use **color-coded buttons** - visually clear
3. **For larger breaks**: Use **Calculator** for direct entry

### Optimize Player Switch

- **Always click opponent's frame score** - faster than other methods
- Break automatically completed and added to frame score

### Break Tracking

- **Current break** only displayed for active player
- After player switch, break added to frame score
- **High Break (HB)** automatically updated when new record reached

### Frame Management

- **Frame number** automatically incremented
- **Match format** (Best of X) displayed in center
- **Frame score** shows won frames / frames to win

---

## Troubleshooting

### Break Not Displayed

- **Check**: Is player active? (Green frame)
- Break only displayed for active player
- After player switch, break added to frame score

### Wrong Points Entered

- **Undo Button**: Undoes last action
- **-1/-5/-10 Buttons**: Deduct points
- **Calculator**: For larger corrections

### Player Switch Not Working

- **Click on other player's frame score** (not on own)
- Green frame shows active player
- Check if game is running (not paused)

### Frame Score Not Updating

- Frame score only updated when frame is won
- Individual breaks added to frame score when frame won
- Check if frame already ended

### High Break Not Updating

- High break only updated when new record reached
- Check if current break is higher than previous high break
- High break tracked per game (not per frame)

---

## Tournament Integration

### Snooker in Tournaments

Snooker scoreboard is fully integrated into tournament system:

- **Automatic frame counting** for tournament games
- **Result submission** to tournament system
- **Score display** in tournament overview
- **Protocol creation** for official games

### League Integration

Snooker leagues are supported:

- **Frame results** automatically transferred to league table
- **High breaks** recorded in statistics
- **Scores** used for league ranking

---

## Frequently Asked Questions (FAQ)

### How many points can be scored maximum in a frame?

Depends on number of red balls:

**15 Reds (full):**
- **147 points** (Maximum Break)
- 15 red balls (15 points) + 15 black balls (15 × 7 = 105 points) = 120 points
- Then all colored balls in order: Yellow (2) + Green (3) + Brown (4) + Blue (5) + Pink (6) + Black (7) = 27 points
- **Total: 147 points**

**10 Reds:**
- **107 points** (Maximum Break)
- 10 red balls (10 points) + 10 black balls (10 × 7 = 70 points) = 80 points
- Then all colored balls: 27 points
- **Total: 107 points**

**6 Reds:**
- **75 points** (Maximum Break)
- 6 red balls (6 points) + 6 black balls (6 × 7 = 42 points) = 48 points
- Then all colored balls: 27 points
- **Total: 75 points**

### What happens if both players have same number of frames?

In case of a tie (e.g. 2:2 in Best of 5), a **deciding frame** is played until one player wins.

### How are fouls handled?

Fouls must be entered manually:
1. Deduct points from break (or correct)
2. Add foul points to opponent (via Calculator or point buttons)
3. Perform player switch

### Can I pause a game?

Yes, via **Menu** you can:
- Pause game
- End game
- Return to welcome screen

### How do I see game statistics?

After game end, you can:
- View **Protocol**
- Display **High Breaks** and **Frame Results**
- Check **Game Statistics** in tournament/league system

### Why does red ball show a number?

The number on red ball shows **number of remaining red balls**:
- At start: 6, 10 or 15 (depending on chosen variant)
- After each pocketed red ball: Number reduced by 1
- At 0: Red ball dimmed and no longer playable

### What do dimmed balls mean?

Dimmed balls are **"off"** (not playable):
- Cannot be clicked
- System shows "Ball not 'on'" on hover
- Game rules allow only certain balls as target

**Rules:**
- After red ball: Only colored balls are "on"
- After colored ball: Only red balls are "on" (if still present)
- No reds left: Colored balls in order (Yellow → Green → Brown → Blue → Pink → Black)

### What does "X Points Remaining" show?

**Remaining points display** shows maximum achievable points on table:
- Helps recognize if catching up is still possible
- Automatically updated after each pocketed ball
- Considers correct snooker rule (reds respawn colors)

**Example:**
- 3 red balls remaining → 3 + 27 = **30 points possible**
- Player A: 45 points, Player B: 20 points
- Difference: 25 points → Player B can still catch up (30 > 25)

### When should I concede?

Conceding makes sense when:
- **"Snooker"** exists (remaining points < point difference)
- Opponent has insurmountable lead
- Game situation is hopeless

**Example for Snooker:**
- Player A: 60 points, Player B: 25 points
- Difference: 35 points
- Remaining points: 30 points
- → Player B cannot win anymore → Conceding is fair

---

## Support

For questions or problems, please contact:
- The **Referee** or **Tournament Director**
- **Club Administration**
- **System Administrator**

---

**Good luck playing snooker!**



