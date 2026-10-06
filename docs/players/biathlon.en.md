# Biathlon on the Scoreboard

Biathlon combines **three-cushion** and **5-pins** in one game (DBU rules Biathlon §3,
[billardregel.de](https://billardregel.de/kegel/biathlon/03-spiel-partie/)). This page describes how
to set up a Biathlon game in Carambus and how it is scored on the scoreboard.

## The rule in brief {#rule}

1. **Three-cushion** is played first — up to the **partial distance** or the **innings limit**.
   There is **no follow-up shot**.
2. At the switch, the three-cushion points are **multiplied by 6** (conversion factor).
3. Then **5-pins** is played, continuing from the score of step 2, up to the **total goal**.
   Excess points of the last shot do not count. Whoever reaches the total goal first wins —
   without a follow-up shot.

The switch applies to **the whole game**: as soon as **one** player reaches the partial distance or
**both** players have played the innings limit. The next player starts with pins.

A variant is written as **partial distance / three-cushion innings / total goal**:

| Variant | Three-cushion | Factor | Pins up to |
|---|---|---|---|
| 15/30/180 | 15 points in 30 innings | ×6 | 180 |
| 15/20/180 | 15 points in 20 innings | ×6 | 180 |
| 10/20/120 | 10 points in 20 innings | ×6 | 120 |
| 10/15/120 | 10 points in 15 innings | ×6 | 120 |

## Setting up a game {#setup}

### Quick start {#quick-start}

On a **match table** the quick start shows the category **Biathlon** with the four variants from
the table. Pick a button, choose the players, done.

!!! note "Buttons missing?"
    The quick start buttons live in the server's `carambus.yml`. A club admin adds them in the admin
    area under **Settings → Quick Game Presets** at `match_billard`:
    `{"category": "Biathlon", "buttons": [{"balls": 180, "innings": 0, "balls_3b": 15, "innings_3b": 30, "discipline": "Biathlon", "allow_follow_up": false}, …]}`
    — then restart the application. The field holds the **whole** preset list: copy the other
    categories along, otherwise they disappear from the quick start. And enter it on the right
    server — every server has its own `carambus.yml`.

### Detail page {#detail-page}

On the detail page of a match table, choose **BIATHL**. Three rows appear:

| Row | Meaning | Default |
|---|---|---|
| **Gesamtziel** (total goal) | Score that ends the game (pins phase) | 180 |
| **Dreiband-Distanz** (partial distance) | Partial distance of the three-cushion phase | 15 |
| **Aufnahmen Dreiband** (three-cushion innings) | Innings limit of the three-cushion phase | 30 |

Every value can also be set freely with **−/+**. An innings limit for the whole game and a
follow-up shot are not used for Biathlon, even if set.

### In a tournament {#tournament}

For a tournament with the discipline Biathlon, the start page additionally shows
**Biathlon: three-cushion distance** and **Biathlon: three-cushion innings** (default 15/30). The
tournament's **balls goal** is the total goal; leave the **innings limit** at 0. The variant applies
to every game of the tournament. See [Tournament Management](../managers/tournament-management.md#start-parameters).

### Tournament app {#tournament-app}

The tournament app sets the variant **per game** — at the DBU Grand Prix e.g. different values for
the group stage, round of 16 and final. See [Tournament App](../managers/tournament-app.md#gp-biathlon).

## Scoring on the scoreboard {#scoring}

### Three-cushion phase {#three-cushion}

- The centre shows **Biathlon/3B**.
- **Goal** shows the **partial distance** (e.g. "Goal: 10"); below the inning count is the innings
  limit of the three-cushion phase ("of 15").
- Input as in three-cushion: **+1** per point. The large number shows the **raw three-cushion
  points** — not ×6.
- An input beyond the partial distance is capped at the partial distance.
- When a player reaches the partial distance, **their inning ends automatically** and the game
  switches to 5-pins. The opponent gets no three-cushion follow-up shot.
- When **both** players have reached the innings limit, the game switches as well — regardless of
  who broke.

### The switch {#switch}

- Both scores are multiplied by 6 (10 becomes 60).
- The centre now shows **Biathlon/5K** and below it the **3B result**, e.g. "10(60) / 4(24)" —
  three-cushion points and, in brackets, the multiplied value.
- The next player starts with pins, from the ball position left behind.

### Pins phase {#pins}

- **Goal** now shows the **total goal** (e.g. "Goal: 120"); there is no innings limit any more.
- Input as in 5-pins billiards. Excess points of the last shot are capped at the total goal.
- The game **ends immediately** when a player reaches the total goal. A draw is therefore
  impossible.

### Correcting (undo) {#undo}

**Undo** takes back the last input or inning as usual. If the inning that triggered the switch is
taken back, the game returns to the **three-cushion phase** — with the raw three-cushion points,
without the factor 6.

## Result {#result}

- **Result** is the total score: three-cushion points ×6 plus pins points, at most the total goal.
- **Innings** counts the innings of both parts together; an average (result ÷ innings) is thus
  comparable.
- **3B result** and **3B innings** (score at the switch) are stored as well.

## FAQ {#faq}

**In the three-cushion phase the large number shows only 7 — shouldn't it be 42?**
No. The three-cushion phase shows the raw points so that the +1 input stays traceable. ×6 is
applied at the switch.

**A player scored more in the last three-cushion inning than was missing to the partial
distance.** The input is capped at the partial distance — as the rule requires.

**The tournament has an innings limit of 30 — does the game end after 30 innings?**
No. For Biathlon the innings limit only applies to the three-cushion phase (field "Biathlon:
three-cushion innings"). The tournament's innings limit is ignored; still, better leave it at 0 so
the start page is unambiguous.

**A rematch (training) — is the variant kept?** Yes, the rematch takes over the partial distance
and innings limit of the first game.
