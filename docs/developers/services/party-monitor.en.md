# PartyMonitor:: — Architecture

The `PartyMonitor::` namespace contains services for managing a live league match day (Ligaspieltag). It is the direct counterpart to `TournamentMonitor::`, but scoped to the party (league match day) context.

The namespace consists of **2 services** in `app/services/party_monitor/`.

## Namespace Overview

| Class | File | Description |
|-------|------|-------------|
| `PartyMonitor::ResultProcessor` | `app/services/party_monitor/result_processor.rb` | Processes match results in PartyMonitor context with pessimistic DB lock |
| `PartyMonitor::TablePopulator` | `app/services/party_monitor/table_populator.rb` | Resets PartyMonitor and assigns TableMonitor records to party tables |

## Public Interface

### ResultProcessor

**Entry points:**

```ruby
processor = PartyMonitor::ResultProcessor.new(party_monitor)

processor.report_result(table_monitor)
  # → side effects: writes game result, triggers finish_match!, finalizes round

processor.accumulate_results
  # → nil; aggregates GameParticipation results into @party_monitor.data["rankings"]

processor.finalize_round
  # → nil; closes all TableMonitor records and accumulates results

processor.finalize_game_result(table_monitor)
  # → nil; writes GameParticipation updates and handles manual assignment

processor.update_game_participations(table_monitor)
  # → nil; updates GameParticipation records with result data
```

**DB lock behavior in `report_result`:**

```
Thread A acquires game.with_lock
→ write_game_result_data(table_monitor)   # data write (PRIVATE)
→ table_monitor.finish_match!             # state transition (if may_finish_match?)
Thread A releases lock
Thread B acquires lock → checks idempotency → skips (already finalized)
```

The lock covers `write_game_result_data` and `finish_match!` together to prevent race conditions when concurrent result reports are submitted.

**Important — `TournamentMonitor.transaction` scope intentionally preserved:**

```ruby
# ResultProcessor#report_result:
TournamentMonitor.transaction do
  ...
end
```

The `TournamentMonitor.transaction` scope was carried over from the original `PartyMonitor` implementation and was intentionally not changed to `PartyMonitor.transaction` (Pitfall 5 in source documentation). This scope decision must not be changed.

### TablePopulator

**Entry points:**

```ruby
populator = PartyMonitor::TablePopulator.new(party_monitor)

populator.reset_party_monitor
  # → nil; resets sets_to_play, sets_to_win, team_size; destroys local games/seedings

populator.initialize_table_monitors
  # → nil; assigns TableMonitors to party tables

populator.do_placement(game, r_no, t_no)
  # → places a single game on a table (round number r_no, table number t_no)
```

**Input for `do_placement`:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `game` | `Game` | The game to be placed |
| `r_no` | `Integer` | Round number |
| `t_no` | `Integer` | Table number |

## Architecture Decisions

### a. POROs with DB side effects

Both services are POROs (not `ApplicationService` subclasses) because they have multiple public entry points and a single `call` interface would not be meaningful. POROs allow flexible calling patterns while maintaining clear separation of responsibilities.

### b. AASM events on the model, not the service

All AASM events (e.g., `finish_match!`, `close_match!`) are fired on `@party_monitor` or the respective `table_monitor` record, not by the service itself. This ensures `after_enter` callbacks execute correctly through the model reference.

### c. cattr_accessor pattern

The `cattr_accessor` value `allow_change_tables` is accessed as `PartyMonitor.allow_change_tables` (class level) — not as `TournamentMonitor.allow_change_tables`. This reflects the PartyMonitor's independent namespace.

### d. Parallel pattern to TournamentMonitor::

`PartyMonitor::ResultProcessor` and `PartyMonitor::TablePopulator` are direct analogs of `TournamentMonitor::ResultProcessor` and `TournamentMonitor::TablePopulator`. The extraction patterns were adopted 1:1, including the DB lock scope and AASM event delegation.

### e. Pitfall — scope preservation for `TournamentMonitor.transaction`

The `TournamentMonitor.transaction` scope in `ResultProcessor#report_result` is not a bug. It was extracted from the original `PartyMonitor` model and deliberately preserved. Changing it to `PartyMonitor.transaction` would alter transaction behavior unpredictably.

## Cross-References

- Parent guide: [Developer Guide — Extracted Services](../developer-guide.en.md#extracted-services)
