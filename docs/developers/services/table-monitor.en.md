# TableMonitor:: — Architecture

The `TableMonitor::` namespace manages real-time billiards game control on a single table. It handles game creation, player assignment, score tracking, and set/match-end transitions.

The namespace consists of **2 services** in `app/services/table_monitor/`.

## Namespace Overview

| Class | File | Description |
|-------|------|-------------|
| `TableMonitor::GameSetup` | `app/services/table_monitor/game_setup.rb` | Encapsulates `start_game` logic — creates `Game`/`GameParticipation` records, builds the result hash, and enqueues `TableMonitorJob` |
| `TableMonitor::ResultRecorder` | `app/services/table_monitor/result_recorder.rb` | Result persistence — saves set data, navigates between sets, and coordinates AASM state transitions |

## Public Interface

### GameSetup

**Entry points:**

```ruby
TableMonitor::GameSetup.call(table_monitor: tm, options: params)
  # → true (raises StandardError on failure)

TableMonitor::GameSetup.assign(table_monitor: tm, game_participation: gp)
  # → performs assign_game logic, saves table monitor state

TableMonitor::GameSetup.initialize_game(table_monitor: tm)
  # → writes initial data hash to tm.data (balls, innings, player state)
```

**Input:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `table_monitor` | `TableMonitor` | ActiveRecord instance of the table monitor |
| `options` | `Hash` | Game parameters (game type, players, options) |
| `game_participation` | `GameParticipation` | Game participation record to assign |

### ResultRecorder

**Entry points:**

```ruby
TableMonitor::ResultRecorder.call(table_monitor: tm)
  # → evaluate_result (main entry — triggers set/match-end logic)

TableMonitor::ResultRecorder.save_result(table_monitor: tm)
  # → Hash (game_set_result with German field names — see data contract below)

TableMonitor::ResultRecorder.save_current_set(table_monitor: tm)
  # → nil (pushes result into data["sets"])

TableMonitor::ResultRecorder.get_max_number_of_wins(table_monitor: tm)
  # → Integer

TableMonitor::ResultRecorder.switch_to_next_set(table_monitor: tm)
  # → nil (initialises next set, resets player state, handles snooker state)
```

**Data contract — return hash from `save_result`:**

```ruby
{
  "Gruppe"       => game.group_no,   # Integer
  "Partie"       => game.seqno,      # Integer
  "Spieler1"     => player_a.ba_id,  # Integer (BA player ID)
  "Spieler2"     => player_b.ba_id,  # Integer
  "Innings1"     => Array,           # innings array player A
  "Innings2"     => Array,           # innings array player B
  "Ergebnis1"    => Integer,         # final score player A
  "Ergebnis2"    => Integer,         # final score player B
  "Aufnahmen1"   => Integer,         # number of innings player A
  "Aufnahmen2"   => Integer,         # number of innings player B
  "3BErgebnis1"  => Integer,         # 3-cushion sub-score player A (result_3b)
  "3BErgebnis2"  => Integer,         # 3-cushion sub-score player B
  "3BAufnahmen1" => Integer,         # 3-cushion innings player A (innings_3b)
  "3BAufnahmen2" => Integer,         # 3-cushion innings player B
  "Höchstserie1" => Integer,         # highest run player A
  "Höchstserie2" => Integer,         # highest run player B
  "Tischnummer"  => Integer,         # table number (game.table_no)
  "TiebreakWinner" => Integer        # per-set tiebreak winner: 1 = playera, 2 = playerb; nil if none
}
```

This hash is stored directly in `data["sets"]` and used for ClubCloud uploads.

## Architecture Decisions

### a. ApplicationService for both services

`GameSetup` and `ResultRecorder` inherit from `ApplicationService` because both make database changes (`Game`, `GameParticipation`, `TableMonitor` records). Services without side effects would be implemented as POROs.

### b. AASM events on the model, not in the service

AASM events (`end_of_set!`, `finish_match!`, `acknowledge_result!`) are fired on `@tm` (the `TableMonitor` instance), not by the service itself. This ensures that `after_enter` callbacks execute correctly through the model reference.

### c. No direct broadcast calls

Neither service calls CableReady or ActionCable directly. Broadcasts happen via `after_update_commit` hooks on the `TableMonitor` model — the services remain free of presentation logic.

### d. set_over ⟹ panel_state "protocol_final" (before_save invariant)

While the AASM state is `set_over` ("game finished"), the before_save invariant `enforce_protocol_final_panel_at_set_over` forces `panel_state = "protocol_final"`. As a result, at game end the scoreboard **always goes straight** to the protocol editor (final mode, "Fertig"/Done = `confirm_result` → `evaluate_result` advances the state) — instead of the rare detour through the "…OK?"/legacy `innings_list` panel. Rationale: several paths overwrite `panel_state` after entering `set_over` (karambol input mode `"inputs"`, `key_a`/`key_b` `"pointer_mode"`, app/bridge games); the invariant is the single path-independent chokepoint. `current_element` is left untouched (tiebreak sets `"tiebreak_winner_choice"`). The `"…OK?"` status itself is the tournament-director confirmation when `!player_controlled?` (see `locked_scoreboard`).

## Biathlon {#biathlon}

Biathlon (DBU rules Biathlon §3) is not a separate game type but carom with two phases —
implemented as a small extension of the existing paths (skill *extend-before-build*), not as a
separate state machine. Operation: [Biathlon on the Scoreboard](../../players/biathlon.md).

**Data in `tm.data`:**

| Key | Content |
|---|---|
| `biathlon_phase` | `"3b"` (three-cushion) or `"5k"` (5-pins) |
| `biathlon` | `{"balls_goal_3b", "innings_goal_3b", "factor"}` — partial distance, three-cushion innings limit, conversion factor (6). Missing values fall back to `TableMonitor::ScoreEngine::BIATHLON_DEFAULTS` (15/30/6) |
| `playerX.balls_goal` | **total goal** of the game |
| `playerX.result_3b`, `innings_3b` | three-cushion score at the switch (display, protocol `3BErgebnis`/`3BAufnahmen`) |

Biathlon is detected by `TableMonitor#discipline == "Biathlon"` (= `playera.discipline`).

**ScoreEngine** (`app/models/table_monitor/score_engine.rb`):

- Three-cushion phase: own branch in `add_n_balls`/`set_n_balls` (`add_biathlon_3b`,
  `set_biathlon_3b`) — counted raw against the partial distance, capped; on reaching it
  `:goal_reached`, so `TableMonitor` ends the inning.
- Switch in **one** place, at the end of every inning (`terminate_inning_data` →
  `switch_biathlon_to_5k!`), when one player has the partial distance or **both** have the innings
  limit — independent of who broke. All `innings_list`/`innings_redo_list` of both players
  ×factor, `recompute_result`.
- Pins phase: regular carom path; `overflow_capped?` caps excess at the total goal.
- Undo: `undo_hash` → `revert_biathlon_to_3b!` when the switching inning is taken back (both
  players at `innings_3b`).
- `innings_limit_open?` is always open for Biathlon; `TableMonitor#follow_up?` and `end_of_set?`
  treat Biathlon without follow-up shot and without a game innings limit.

**Why guards instead of a clean data flow:** tournament games go through `assign_game` →
`initialize_game`, not `GameSetup#perform_start_game`, and `TournamentsController#start` writes the
tournament's `innings_goal` to every table **after** placement. Instead of patching every path,
Biathlon is insensitive to `innings_goal`/`allow_follow_up`.

**Where the variant comes from:**

| Path | Source | Set in |
|---|---|---|
| Quick start | preset `{balls, balls_3b, innings_3b, discipline: "Biathlon"}` (`carambus.yml`, match table) → `biathlon[balls_goal_3b, innings_goal_3b]` | `GameSetup#biathlon_settings` |
| Detail page | `discipline_choice` 13, `biathlon_3b(_2)_choice`, `innings_choice` (= three-cushion innings) | `TableMonitorsController#start_game` → `biathlon_settings` |
| Tournament | start page → `tournament_monitor.data["biathlon"]` (local record; a sync would overwrite `tournament.data`) | `TournamentsController#start` (tables of round 1), `GameSetup.initialize_game` (every later game) |
| Tournament app | `POST start_game` with `biathlon: {…}` per game | `ExternalTournament::StartGameProcessor` → `biathlon_settings` |
| Rematch | `data["biathlon"]` | `TableMonitor#revert_players` |

Normalised in one place: `TableMonitor::GameSetup.biathlon_params` (positive values only, the rest
from the defaults). `initialize_game` clears a previous game's `biathlon` at the table.

**Tests:** `test/models/table_monitor/score_engine_biathlon_test.rb`,
`test/models/table_monitor/biathlon_lifecycle_test.rb`, Biathlon cases in
`test/services/table_monitor/game_setup_test.rb`, `test/controllers/table_monitors_controller_test.rb`,
`test/controllers/api/external_tournaments_lifecycle_test.rb`,
`test/integration/biathlon_tournament_start_test.rb`.

## Cross-References

- Parent guide: [Developer Guide — Extracted Services](../developer-guide.en.md#extracted-services)
