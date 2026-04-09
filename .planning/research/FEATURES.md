# Feature Landscape: Rails God-Model Refactoring

**Domain:** Brownfield Rails god-model extraction (TableMonitor 3900 lines, RegionCc 2700 lines)
**Researched:** 2026-04-09
**Confidence:** HIGH — standard Rails community patterns, verified against multiple sources

---

## Table Stakes

Features a refactoring of this type must have. Missing any one of these means the refactoring is
unsafe and likely to break production behavior.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Characterization tests for TableMonitor critical paths | Safety net before any change; 96 methods, AASM machine, callback chain — no move is safe without it | High | Must cover: state transitions, `after_update_commit` broadcast logic, timer callbacks, `skip_update_callbacks` flag behavior |
| Characterization tests for RegionCc critical paths | Same rationale; HTTP layer + data transformation = silent corruption risk | High | VCR cassettes already exist — extend to cover all `sync_*` methods and `fix` operations |
| Behavior-preserving extraction of TableMonitor broadcast logic | `after_update_commit` lambda is the most dangerous single block — it drives all live scoreboard updates via CableReady | High | Must keep identical trigger conditions and cable-ready channel targets; extract to a dedicated broadcaster class |
| Behavior-preserving extraction of TableMonitor state callbacks | `before_save`, `before_create`, `log_state_change`, `log_state_transition` — these have interdependencies that must be preserved in order | High | Callback firing order is contractual; tests must verify sequence, not just outcome |
| Service class tests alongside each extraction | Each extracted class must have its own unit tests before the model delegation is wired in | Medium | The project already has `ApplicationService` base — use it consistently |
| Incremental extraction — one domain at a time | Each extracted service must be independently deployable; a single giant PR is a revert waiting to happen | Medium | One service per PR: extract → test → wire delegation → PR |
| Explicit `delegate` wiring from model to extracted services | The model public interface must not change; callers (reflexes, jobs, controllers) must not know extraction happened | Medium | Use `delegate :method_name, to: :service_instance` or thin forwarding methods |
| RegionCc HTTP client extraction | `post_cc`, `get_cc`, `post_cc_with_formdata` are transport logic living inside a model — must be extracted to a dedicated client class | Medium | Model should call `ClubCloudClient.new(self).post(action, params)` not raw Net::HTTP |
| RegionCc sync domain grouping | 25+ `sync_*` methods fall into ~5 logical domains (league structure, teams/players, game plans, competitions, clubs) — each domain belongs in its own service | High | Grouping by prefix is a reliable heuristic here: `sync_league_*`, `sync_team_*`, `sync_game_*`, `sync_club_*`, `sync_competition_*` |
| AASM transitions kept inside the model | AASM's `included` block ties state columns directly to ActiveRecord persistence; moving it outside the model class creates an `aasm` scope problem | Medium | Keep the `include AASM` and transition definitions in the model; extract only the callback logic called from transitions |

---

## Differentiators

Features that separate a quality refactoring from a bare-minimum extraction. Not required for safety,
but they determine whether the codebase is actually easier to work in afterward.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Logical domain naming for extracted services | `TableMonitorBroadcaster`, `TableMonitorInningsEditor`, `TableMonitorTimerService`, `ClubCloudClient`, `LeagueSyncService` — names that communicate intent | Low | Naming discipline prevents future devs from dumping new logic in the wrong place |
| `skip_update_callbacks` flag moved to broadcaster | This flag currently controls whether the `after_update_commit` lambda short-circuits; it is a broadcast-layer concern, not a model concern | Medium | Extract the flag alongside the broadcasting logic; keep the model's `attr_accessor` as a pass-through for now |
| TableMonitor innings logic extracted as a value-object-style editor | `add_n_balls`, `undo`, `redo`, `insert_inning`, `delete_inning`, `recalculate_player_stats` are a coherent innings-editing domain — ~800 lines | High | Innings editor takes `table_monitor` as a dependency, returns mutated data, does not save itself; model calls save after |
| Snooker-specific methods isolated in a concern or subservice | `recalculate_snooker_state_from_protocol`, `update_snooker_state`, `snooker_balls_on`, `undo_snooker_ball` are discipline-specific — ~300 lines | Medium | Keeps generic scoreboard logic from entangling with snooker rules |
| RegionCc HTTP layer uses a proper HTTP wrapper with error handling | Current `get_cc`/`post_cc` have mixed concerns: session management, error handling, redirect following, response parsing all in one method | Medium | A dedicated `ClubCloudSession` or `ClubCloudHttp` class makes timeout handling and error recovery explicit and testable |
| Separate `fix` methods from `sync` methods in RegionCc | `fix` methods (patching data inconsistencies) and `sync` methods (authoritative pulls) serve different purposes; mixing them hides which operations are destructive | Medium | Group into `ClubCloudFixService` and `ClubCloudSyncService` with clear contracts |
| TableMonitor `start_game` extracted to a service | `start_game` is ~130 lines and the site of the `skip_update_callbacks` flag — it orchestrates timer, assignment, state, and broadcast | High | This is the highest-risk single method; extract last, after all dependencies have their own homes |
| Inline DEBUG constant centralized | `DEBUG = Rails.env != "production"` in TableMonitor and `DEBUG = true` (always on!) in RegionCc are both tech debt; move to a shared config or Rails.logger level | Low | Remove during extraction passes rather than as a separate ticket |
| Consistent `ApplicationService.call` interface for all extracted services | Project already has the base class; enforcing `.call` as the single public entry point makes services trivially mockable in tests | Low | Stateful services (ClubCloudClient, innings editor) may need an instance API, not `.call` |

---

## Anti-Features

Things to explicitly NOT do during this refactoring. Each one has caused rewrites in comparable projects.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Extracting to Concerns | Concerns expand into the model at runtime; they move lines between files but do not reduce model complexity or improve testability. The project has already decided against this. | Extract to plain Ruby service classes in `app/services/` with explicit instantiation |
| Moving AASM definition outside the model | AASM's `included do` block requires being inside the ActiveRecord class to wire up `aasm` column persistence and scopes correctly | Keep `include AASM` and `aasm do ... end` inside the model; only extract callback method bodies |
| Big-bang extraction in a single PR | A 3900-line model extracted in one commit is impossible to review, impossible to bisect if it breaks, and defeats the incremental safety guarantee | One domain per PR, passing tests before merge |
| Extracting query methods to scopes on other models | TableMonitor has `playing_round?`, `is_match_decided?`, etc. that encapsulate domain rules — these should stay near the state machine or move to a policy class, not become scopes on associated models | Keep query methods as model methods or extract to a `TableMonitorPolicy` if they grow |
| Changing the external interface of either model | Reflexes, jobs, and controllers call model methods directly; changing method signatures or removing delegations during extraction is a separate (and risky) concern | Preserve all public method names; add deprecation if anything genuinely needs renaming |
| Writing new tests only for extracted services | If characterization tests are skipped in favor of unit tests on the new services alone, extraction may pass tests while breaking integration paths | Characterization tests come first, covering existing behavior end-to-end; unit tests on services are additive |
| Introducing new abstractions (events, pub/sub, domain events) | Event sourcing and pub/sub are legitimate architectural patterns — they are also a scope explosion for a refactoring-only milestone | This milestone is extraction only; architectural patterns are a follow-on concern |
| Extracting RegionCc before TableMonitor is stable | TableMonitor has more integration surface (reflexes, jobs, live scoreboard); its extraction has higher risk and should be proven first | TableMonitor first; RegionCc second; skills and patterns transfer |

---

## Feature Dependencies

```
Characterization tests (TableMonitor) ──► Extract broadcaster
                                      ──► Extract callback logic
                                      ──► Extract innings editor
                                      ──► Extract start_game service
                                              (all of the above depend on tests first)

Characterization tests (RegionCc)     ──► Extract HTTP client
                                      ──► Extract sync domain services
                                      ──► Extract fix services

Extract HTTP client (RegionCc)        ──► Extract sync domain services
                                              (sync services depend on the HTTP client being injectable)

Extract broadcaster (TableMonitor)    ──► Extract start_game service
                                              (start_game is the main caller of skip_update_callbacks)
```

---

## MVP Recommendation

Prioritize in this order:

1. **Characterization test suite for TableMonitor** — covers state transitions, `after_update_commit` logic, timer callbacks; this is the gate for everything else
2. **Characterization test suite for RegionCc** — extend existing VCR cassette tests to cover all `sync_*` and `fix` operations end-to-end
3. **Extract `TableMonitorBroadcaster`** — isolates the single most dangerous callback block; highest risk reduction per effort
4. **Extract `ClubCloudClient`** — isolates the HTTP transport layer; prerequisite for all sync service extractions
5. **Extract RegionCc sync domain services** — five distinct domains, extract sequentially (league structure first, then teams/players, then game plans, competitions, clubs)
6. **Extract TableMonitor innings editor** — large self-contained domain; lower risk than broadcaster because it has no side-effectful callbacks
7. **Extract `TableMonitor#start_game` to service** — highest complexity, extract last when all its dependencies have their own homes

Defer:
- Snooker-specific extraction: low urgency, snooker is a single discipline variant
- `DEBUG` constant cleanup: fold into extraction passes, not a standalone ticket
- Policy class extraction: only if `can_*?` methods are present at scale; not a blocker

---

## Sources

- [7 Patterns to Refactor Fat ActiveRecord Models — Code Climate](https://codeclimate.com/blog/7-ways-to-decompose-fat-activerecord-models) — canonical pattern taxonomy
- [Refactoring Strategies for Rails Models — FastRuby.io](https://www.fastruby.io/blog/refactoring-strategies-for-rails-model.html) — 90% coverage threshold, incremental approach
- [Characterization Tests for Legacy Code — LearnAgilePractices](https://learnagilepractices.substack.com/p/characterization-tests-for-legacy) — golden master testing approach
- [Refactoring Long AASM Modules — Pedro Costa, Medium](https://medium.com/@pdrgc/refactoring-long-aasm-modules-d0e331f2054d) — AASM + `ActiveSupport::Concern` modularization
- [Implementing a State Machine as a Service — DEV Community](https://dev.to/caciquecoder/implementing-a-state-machine-as-a-service-with-aasm-gem-3c9p) — AASM service object pattern
- [Essential Rails Patterns: Clients and Wrappers — Selleo, Medium](https://medium.com/selleo/essential-rubyonrails-patterns-clients-and-wrappers-c19320bcda0) — HTTP client extraction pattern
- [Lesser Model Callbacks — Elijah Goh, Medium](https://medium.com/@elithecho/lesser-model-callbacks-refactoring-rails-the-clean-way-885721a84a4a) — callback extraction rationale
- [Leveraging Service Objects for Callback Refactoring — Egemen Öztürk, Medium](https://medium.com/@egemenn/leveraging-service-objects-and-concerns-in-refactoring-rails-model-callbacks-db33cb041591) — concrete callback extraction pattern
- [Key Points of Working Effectively with Legacy Code](https://understandlegacycode.com/blog/key-points-of-working-effectively-with-legacy-code/) — seam-based characterization testing
