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
  "Höchstserie1" => Integer,         # highest run player A
  "Höchstserie2" => Integer,         # highest run player B
  "Tischnummer"  => Integer          # table ID
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

## Cross-References

- Parent guide: [Developer Guide — Extracted Services](../developer-guide.en.md#extracted-services)
