# TournamentMonitor:: — Architecture

The `TournamentMonitor::` namespace provides services for managing a live tournament — distributing players to groups, resolving placement rules, processing match results, and populating tables.

The namespace consists of **4 services** in `app/services/tournament_monitor/`.

## Namespace Overview

| Class | File | Description |
|-------|------|-------------|
| `TournamentMonitor::PlayerGroupDistributor` | `app/services/tournament_monitor/player_group_distributor.rb` | Pure PORO — distributes players to groups via zig-zag or round-robin per NBV rules |
| `TournamentMonitor::RankingResolver` | `app/services/tournament_monitor/ranking_resolver.rb` | Pure PORO — resolves player IDs from ranking rule strings (group ranks, KO bracket references) |
| `TournamentMonitor::ResultProcessor` | `app/services/tournament_monitor/result_processor.rb` | Processes match results with pessimistic DB lock — coordinates ClubCloud upload and `GameParticipation` updates |
| `TournamentMonitor::TablePopulator` | `app/services/tournament_monitor/table_populator.rb` | Assigns games to tournament tables — initialises `TableMonitor` records and runs the placement algorithm |

## Public Interface

### PlayerGroupDistributor

**Entry points (class methods — no instantiation needed):**

```ruby
TournamentMonitor::PlayerGroupDistributor.distribute_to_group(players, ngroups)
  # → Hash { group_no => [player_ids] }
  # Distributes players (Array of Integer) to ngroups groups via zig-zag

TournamentMonitor::PlayerGroupDistributor.distribute_with_sizes(players, ngroups, sizes)
  # → Hash { group_no => [player_ids] }
  # Distributes players to ngroups groups with explicit group sizes
```

**Input:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `players` | `Array<Integer>` | List of player IDs (ordered by ranking) |
| `ngroups` | `Integer` | Number of groups |
| `sizes` | `Array<Integer>` | Explicit group sizes (only for `distribute_with_sizes`) |

**Output:** `Hash { Integer => Array<Integer> }` — group number → list of player IDs.

### RankingResolver

**Entry points:**

```ruby
resolver = TournamentMonitor::RankingResolver.new(tournament_monitor)

resolver.player_id_from_ranking(rule_str, opts = {})
  # → Integer (player_id) or nil
```

**`rule_str` DSL — examples:**

| Expression | Meaning |
|------------|---------|
| `"g1.2"` | Player ranked 2nd in group 1 |
| `"g1.rk4"` | Player ranked 4th in group 1 (explicit `rk` prefix) |
| `"(g1.rk4 + g2.rk4).rk2"` | Composite rule: rank 2 among all rank-4 players from groups 1 and 2 |
| `"fin.w"` | Winner of the final (KO bracket reference) |
| `"sl.rk1"` | Rank 1 in the small final (consolation bracket) |

**Input (constructor):**

| Parameter | Type | Description |
|-----------|------|-------------|
| `tournament_monitor` | `TournamentMonitor` | ActiveRecord instance of the tournament monitor |

### ResultProcessor

**Entry points:**

```ruby
processor = TournamentMonitor::ResultProcessor.new(tournament_monitor)

processor.report_result(table_monitor)
  # → side effects: writes game result, triggers finish_match!, uploads to CC

processor.accumulate_results
  # → PUBLIC — also used by TablePopulator

processor.update_ranking
  # → updates rankings after result processing

processor.update_game_participations
  # → updates GameParticipation records
```

**DB lock scope:**

```ruby
game.with_lock do
  # Covers exactly: write_game_result_data + finish_match!
  # Pessimistic lock prevents race conditions on concurrent results
end
```

**Input (constructor):**

| Parameter | Type | Description |
|-----------|------|-------------|
| `tournament_monitor` | `TournamentMonitor` | ActiveRecord instance of the tournament monitor |

### TablePopulator

**Entry points:**

```ruby
populator = TournamentMonitor::TablePopulator.new(tournament_monitor)

populator.do_reset_tournament_monitor
  # → AASM after_enter callback entry point for full reset

populator.populate_tables
  # → assigns games to tournament tables

populator.initialize_table_monitors
  # → initialises TableMonitor records for all tables
```

**Input (constructor):**

| Parameter | Type | Description |
|-----------|------|-------------|
| `tournament_monitor` | `TournamentMonitor` | ActiveRecord instance of the tournament monitor |

## Architecture Decisions

### a. PORO vs. PORO with DB side effects

Services are split by purpose — not by `ApplicationService` inheritance:

- **Pure POROs** (no DB operations): `PlayerGroupDistributor`, `RankingResolver`
- **POROs with DB side effects**: `ResultProcessor`, `TablePopulator` — have multiple public entry points and therefore do not inherit from `ApplicationService` (which supports only a single `.call` entry point)

### b. AASM events on the model

AASM events (`finish_match!`, `after_enter` callbacks, etc.) are fired on `@tournament_monitor`, not by the service itself. This ensures that `after_enter` callbacks execute correctly through the model reference.

### c. DB lock in the service, not in the model

The pessimistic lock (`game.with_lock`) is placed in `ResultProcessor`, not in the `TournamentMonitor` model. The lock boundary belongs to the result processing logic — it is not a model infrastructure concern.

### d. Cross-dependency: RankingResolver → PlayerGroupDistributor

`RankingResolver#group_rank` calls `PlayerGroupDistributor.distribute_to_group` directly. This dependency is intentional — the resolver must know the group distribution to resolve ranks within groups.

### e. Class attribute `allow_change_tables`

`TournamentMonitor.allow_change_tables` is set and controlled as a class attribute (`cattr_accessor`). Access is via `TournamentMonitor.allow_change_tables` (class level), not as an instance method.

## Cross-References

- Parent guide: [Developer Guide — Extracted Services](../developer-guide.en.md#extracted-services)
