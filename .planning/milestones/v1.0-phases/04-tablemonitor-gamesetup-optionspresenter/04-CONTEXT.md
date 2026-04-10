# Phase 4: TableMonitor GameSetup & OptionsPresenter - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract the start_game method cluster (start_game, initialize_game, assign_game, player switching) and view-preparation logic (get_options!) from TableMonitor into two new service classes. Replace the skip_update_callbacks flag with an explicit broadcast: false keyword argument. No new features, no architecture changes.

</domain>

<decisions>
## Implementation Decisions

### GameSetup Class Design
- **D-01:** GameSetup is an ApplicationService subclass using `.call(kwargs)` pattern — not a PORO like ScoreEngine. Rationale: start_game is a one-shot operation that creates Game/GameParticipation records (AR writes), fits the service pattern. ScoreEngine was a PORO because it's stateful and called many times per game.
- **D-02:** GameSetup handles: `start_game`, `initialize_game`, `assign_game`, and player sequence/switching methods. Game and GameParticipation record creation moves into GameSetup.
- **D-03:** GameSetup receives the TableMonitor instance as a parameter: `GameSetup.call(table_monitor: self, options: opts)`. It can call `save!` on the model since it's a service (unlike ScoreEngine which was pure data).

### skip_update_callbacks Replacement
- **D-04:** Replace `skip_update_callbacks` attr_accessor with a `broadcast: false` keyword argument on the methods that trigger callbacks. Inside `start_game` (now in GameSetup), batch saves use `update_columns` or pass `broadcast: false` to suppress after_update_commit job enqueueing during the setup sequence.
- **D-05:** The `after_update_commit` callback checks for the `broadcast` flag (or uses a thread-local/instance variable `@suppress_broadcast`) rather than the old `skip_update_callbacks` pattern. This is more explicit and doesn't leak state.

### OptionsPresenter Design
- **D-06:** OptionsPresenter is a PORO (like ScoreEngine) since it reads data and produces view hashes — no AR writes. `TableMonitor::OptionsPresenter.new(data, discipline:, locale:).call` returns the options hash.
- **D-07:** OptionsPresenter handles `get_options!` and any helper methods it calls internally. TableMonitor keeps a thin wrapper `def get_options!(locale)` that delegates.

### Claude's Discretion
- Exact method split between what stays in TableMonitor vs moves to GameSetup (some helper methods may need to stay)
- Internal structure of OptionsPresenter (private method organization)
- How to handle the `switch_players` method — may stay in model if it's called from multiple contexts beyond start_game
- Error handling pattern within GameSetup (rescue and re-raise vs let exceptions propagate)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Models Under Extraction
- `app/models/table_monitor.rb` — 2882-line model being extracted (start_game at line 2001, initialize_game at line 775, assign_game at line 736, get_options! at line 1073, skip_update_callbacks at line 71)

### Established Extraction Patterns
- `app/models/table_monitor/score_engine.rb` — Phase 3 PORO pattern (lazy accessor, hash by reference, signal returns)
- `app/services/region_cc/league_syncer.rb` — Phase 2 ApplicationService dispatcher pattern
- `app/services/application_service.rb` — Base class for services

### Characterization Tests (Safety Net)
- `test/characterization/table_monitor_char_test.rb` — 41 characterization tests pinning TableMonitor behavior

### Phase 3 Research
- `.planning/phases/03-tablemonitor-scoreengine/03-RESEARCH.md` — Method boundary mapping and extraction patterns

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ApplicationService` base class with `.call(kwargs)` pattern — ready for GameSetup
- ScoreEngine PORO pattern with lazy accessor — template for OptionsPresenter
- Phase 1 characterization tests — safety net for all extractions

### Established Patterns
- Phase 2: ApplicationService for one-shot operations with AR writes (syncers)
- Phase 3: PORO for stateful/read-only collaborators (ScoreEngine)
- Lazy accessor delegation: `def score_engine; @score_engine ||= ScoreEngine.new(data, ...); end`
- `reload` override to reset lazy accessors

### Integration Points
- `after_update_commit` callback at line 71 — where skip_update_callbacks is checked, needs broadcast: false replacement
- `app/reflexes/table_monitor_reflex.rb` — Reflex that triggers start_game and get_options!
- `app/jobs/table_monitor_job.rb` — Jobs enqueued by after_update_commit that skip_update_callbacks suppresses

</code_context>

<specifics>
## Specific Ideas

No specific requirements — follow established Phase 2/3 extraction patterns.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 04-tablemonitor-gamesetup-optionspresenter*
*Context gathered: 2026-04-10*
