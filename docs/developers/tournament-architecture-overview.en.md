# Carambus Tournament Architecture Overview

This document provides a concise, high-level overview of the most critical files managing tournaments and special tournament modes in Carambus. Use this summary to instantly establish context when debugging tournament logic.

## 1. Core Models & Setup

*   **`Tournament` (`app/models/tournament.rb`)**: The central hub data model. Focuses on overall metadata, synchronization with ClubCloud, aggregating requirements, and caching rankings. Handled in tandem with **`TournamentLocal` (`app/models/tournament_local.rb`)** which maintains local, match-specific settings (timeouts, follow-ups, win targets).
*   **`Seeding` (`app/models/seeding.rb`)**: Handles participant registrations, linking players to tournaments. Defines the initial rankings or handicaps, which determine group and bracket placements.
*   **`Game` (`app/models/game.rb`)**: Represents a single match pairing (Player A vs Player B). Holds the dynamic state (score, innings, timeouts) of the match currently taking place on a table.
*   **Structural Domain (`Location.rb`, `Region.rb`, `Club.rb`, `ClubLocation.rb`)**: These models primarily map the physical domain. They contain extensive sync/scraping logic to fetch and normalize data from ClubCloud/BillardArea (venues, table setups, state supervisors, and registered players).

## 2. Tournament Modes (The Blueprint)

*   **`TournamentPlan` (`app/models/tournament_plan.rb`)**: **Critical for Special Modes.** This acts as the blueprint for any tournament layout (Group phases, KO rounds, everyone-vs-everyone). It heavily relies on the column `executor_params` (parsing JSON structures like `pl`, `sq`, `RK` representing groups, round configurations, and rulesets) to understand how players proceed from phase to phase. Methods like `default_plan` and `ko_plan` define new brackets.

## 3. Execution & State Engines (The Runtime)

*   **`TournamentMonitor` (`app/models/tournament_monitor.rb`)**: The active runtime representation of a tournament. This runs the logic that transitions the `TournamentPlan` blueprint into tangible next steps. It handles current rounds, algorithms for distributing players to groups (`distribute_to_group`, `distribute_with_sizes`), determining group ranks (`group_rank`), and KO rankings (`ko_ranking`).
*   **`TournamentMonitorState` (`lib/tournament_monitor_state.rb`)**: Holds state machine logic to determine phases. (e.g., `finalize_game_result`, `all_table_monitors_finished?`, `finalize_round`, `group_phase_finished?`). It manages exactly *when* the tournament should step forward based on table progress.
*   **`TournamentMonitorSupport` (`lib/tournament_monitor_support.rb`)**: The operational workhorse. Handles populating available tables (`populate_tables`), placing next matches (`do_placement`), and reacting to game completions (`accumulate_results`, `report_result`, `update_ranking`).

## 4. Controllers (The UI Connectors)

*   **`TournamentsController` (`app/controllers/tournaments_controller.rb`)**: Handles the complex multi-step "Wizard" for setting up the tournament—importing participants, resolving location data, mapping seedings, selecting the tournament `TournamentPlan` mode (`finalize_modus`), and starting the tournament. 
*   **`TournamentMonitorsController` (`app/controllers/tournament_monitors_controller.rb`)**: The active interface for the Tournament Director *during* the event. Contains actions to oversee games continuously (`update_games`, `switch_players`, `start_round_games`).

---

## 💡 Cheatsheet: Debugging "Special Tournament Modes"

If you are debugging how a specific mode progresses or fails to place a player correctly:

1.  **Check `TournamentPlan#group_sizes` / `#rounds_count`** to see how the blueprint's `executor_params` is parsed.
2.  **Trace `TournamentMonitor`** methods like `#rank_from_group_ranks` and `#distribute_to_group` to see how it mathematically resolves player positioning.
3.  **Inspect `TournamentMonitorSupport#do_placement`** to step through how the next `Game` is actively scheduled based on those newly determined ranks.
4.  **Inspect `TournamentMonitorState#finalize_round`** to see if the criteria to close the active segment are firing properly.
