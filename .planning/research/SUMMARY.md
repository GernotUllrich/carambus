# Project Research Summary

**Project:** Carambus API — TableMonitor & RegionCc God-Model Extraction
**Domain:** Brownfield Rails refactoring (service object extraction from oversized ActiveRecord models)
**Researched:** 2026-04-09
**Confidence:** HIGH

## Executive Summary

This project is a focused brownfield refactoring, not a rewrite or architecture migration. Two Rails models — `TableMonitor` (3903 lines, 96 methods, AASM state machine, CableReady real-time broadcast chain) and `RegionCc` (2728 lines, 25+ sync methods, external HTTP API) — have accumulated responsibilities that make them unsafe to modify and impossible to unit test. The community-established approach is incremental service object extraction using Plain Old Ruby Objects (POROs) with explicit dependencies, preserving all public model interfaces so that reflexes, jobs, and controllers require no changes. The key constraint is that the extraction must be behavior-preserving: the external behavior of the system is the contract, and every extraction step must be gated by a characterization test suite that pins existing behavior before any code moves.

The recommended approach is a two-track extraction: RegionCc first (lower real-time risk, no live scoreboard coupling), then TableMonitor (higher risk, touches AASM state machine and CableReady broadcast chain). Within each track, extract the lowest-coupling cluster first — `RegionCc::HttpClient` (pure I/O, no ActiveRecord) and `TableMonitor::ScoreEngine` (pure data hash mutation, no callbacks) — and work outward toward the highest-risk clusters. Each extracted service should be independently testable, take explicit dependencies via constructor injection, and never save or broadcast directly. The model retains the AASM definition, `after_update_commit` callback, and the public API; extracted services mutate in memory and the model saves.

The primary risks are all in the callback and state machine layer. `TableMonitor`'s `after_update_commit` callback reads Rails-specific transient state (`previous_changes`, `@collected_changes`) that is only valid inside the callback lifecycle — extracting this logic without snapshotting that data first causes silent scoreboard update failures. The `skip_update_callbacks` flag is a suppression mechanism for batch operations that will break silently if not threaded explicitly into extracted services. AASM's default `whiny_transitions: false` causes failed state transitions to return false instead of raising, hiding extraction errors during live matches. These three risks must be addressed in the characterization phase before any extraction begins.

---

## Key Findings

### Recommended Stack

No new frameworks. The extraction uses the existing Rails 7.2 / Minitest / FactoryBot / VCR stack. The only additions are `reek` (dev-only, code smell detection to measure before/after extraction quality) and potentially `after_commit_everywhere` (only if extracted services need to register `after_commit` hooks outside model callbacks). All other proposed gems — interactor, dry-monads, dry-transaction, suture — were evaluated and rejected. Interactor adds indirection for no gain; dry-monads requires team familiarity with monadic programming not appropriate for a single-engineer brownfield refactor; suture is abandoned (last release 2018). The project already has RuboCop via `standard`; adding aspirational Metrics cop targets in `.rubocop.yml` provides objective extraction progress metrics.

**Core technologies:**
- **PORO with `call` convention:** Service structure — consistent with existing `app/services/`, no gem dependency, immediately testable with Minitest
- **Reek 6.5.0:** Code smell detection — quantifies LargeClass, TooManyMethods, FeatureEnvy before and after each extraction to confirm improvement
- **RuboCop Metrics cops (existing):** Aspirational targets for extracted classes — `ClassLength: 500`, `MethodLength: 15` as gates on new code
- **after_commit_everywhere 1.6.0 (conditional):** `after_commit` hooks from service objects — only needed if services must fire transactional side effects outside model callback chain; defer until needed
- **Minitest + FactoryBot + VCR (existing):** Characterization testing infrastructure — no new test tooling required

### Expected Features

The "features" for a refactoring project are the extraction deliverables and their safety constraints. The full dependency graph and priority order is in `.planning/research/FEATURES.md`.

**Must have (table stakes — extraction is unsafe without these):**
- Characterization test suite for TableMonitor critical paths — covers state transitions, `after_update_commit` logic, `skip_update_callbacks` behavior, timer callbacks, `local_server?` branch, `PartyMonitor` polymorphic branch
- Characterization test suite for RegionCc critical paths — extends existing VCR cassettes to cover all `sync_*` and `fix` operations end-to-end
- Behavior-preserving extraction of `TableMonitor::ScoreEngine` — pure data hash transformation, no callbacks
- Behavior-preserving extraction of `RegionCc::HttpClient` — pure I/O abstraction, prerequisite for all sync service extractions
- Explicit lazy accessor or `delegate` wiring from model to extracted services — public model interface must not change

**Should have (quality extractions that make the codebase easier to work in):**
- `TableMonitor::GameSetup` — isolates `start_game` (133 lines, most entangled method) and `skip_update_callbacks` management
- `TableMonitor::ResultRecorder` — isolates result persistence and AASM event calls
- `RegionCc::LeagueSyncer`, `RegionCc::TournamentSyncer`, `RegionCc::PartySyncer` — sync domains extracted sequentially
- `skip_update_callbacks` replaced with explicit `broadcast: false` keyword argument
- AASM `whiny_transitions: true` enforced before extraction begins

**Defer (not needed for this milestone):**
- Snooker-specific method isolation — low urgency, single discipline variant
- `DEBUG` constant cleanup — fold into extraction passes, not standalone ticket
- Policy class extraction for `can_*?` methods — only if they grow in scope
- Event sourcing / pub-sub architectural patterns — explicitly out of scope for this milestone

### Architecture Approach

The architecture is a hub-and-spoke delegation model: each god-model becomes a thin coordinator that instantiates and delegates to service objects. Services receive the model instance via constructor injection, mutate in memory (no save, no broadcast), and return. The model saves after the reflex finishes, preserving the `after_update_commit` -> `TableMonitorJob` -> CableReady -> browser DOM chain without modification. AASM definitions, `after_update_commit`, and class-level `cattr_accessor` state remain in the model. Services fire AASM events back on the model reference — they never own state machine logic.

**TableMonitor extracted components:**
1. `TableMonitor::ScoreEngine` — all in-game score mutation (`add_n_balls`, `undo`/`redo`, innings rendering, snooker logic); mutates `data` hash only; no AASM, no CableReady
2. `TableMonitor::GameSetup` — game initialization, player assignment, `start_game` (133 lines), `skip_update_callbacks` management; creates `Game` and `GameParticipation` records
3. `TableMonitor::ResultRecorder` — result persistence at set/match end; fires AASM events on model (`finish_match!`); communicates with `Game` and `TournamentMonitor`

**RegionCc extracted components:**
1. `RegionCc::HttpClient` — raw HTTP to ClubCloud (`post_cc`, `get_cc`, session management, URL discovery); pure I/O, no ActiveRecord
2. `RegionCc::LeagueSyncer` — league and team structure sync; injects `HttpClient`
3. `RegionCc::TournamentSyncer` — tournament and competition sync; injects `HttpClient`
4. `RegionCc::PartySyncer` — party (match) and game result sync; injects `HttpClient`

### Critical Pitfalls

1. **Callback chain instance variable capture** — `previous_changes` and `@collected_changes` are only valid inside the `after_commit` lifecycle. Prevention: snapshot `previous_changes` to a plain Hash at the top of the callback, pass the snapshot to the service as a constructor argument. Never have a service call `model.previous_changes`.

2. **`skip_update_callbacks` flag invisible in services** — `start_game` sets this flag to suppress 3-5 redundant broadcast jobs during batch saves. When extracted, the guard silently breaks. Prevention: replace the flag with an explicit `broadcast: false` keyword argument threaded through `GameSetup` before any extraction touches the broadcast path.

3. **AASM silently swallows guard failures** — default `whiny_transitions: false` converts extraction-broken guard methods into silent `false` returns, leaving the table stuck in the wrong state with no exception in logs. Prevention: set `whiny_transitions: true` and write unit tests for each guard method before extraction.

4. **Transactional tests silence `after_commit` behavior** — Rails' default `use_transactional_tests = true` means `after_commit` callbacks never fire in tests. Prevention: configure non-transactional test classes for any test verifying `after_commit` behavior before writing characterization tests.

5. **VCR cassettes masking RegionCc sync changes** — cassettes recorded against the old calling pattern silently replay partial responses after `HttpClient` extraction, letting tests pass while production sync produces orphaned records. Prevention: mandatory cassette re-record step after each RegionCc extraction; add `assert_requested` count assertions.

---

## Implications for Roadmap

Based on research, the dependency graph drives a clear 5-phase structure. The characterization test phase is a hard gate; no extraction is safe without it. RegionCc is lower-risk and should be extracted before TableMonitor.

### Phase 1: Characterization Tests and Pre-Extraction Hardening

**Rationale:** All 6 critical pitfalls manifest because there are no tests pinning current behavior. This phase is the gate for everything else. It also addresses two structural issues — AASM `whiny_transitions` and transactional test configuration — that would corrupt characterization tests if not fixed first.

**Delivers:**
- Full characterization test suite for TableMonitor: state transitions, all three `after_update_commit` speed branches, `skip_update_callbacks` suppression, timer callbacks, `local_server?` branch, `PartyMonitor` polymorphic branch
- Characterization test suite for RegionCc: all `sync_*` and `fix` operations with cassette coverage
- `whiny_transitions: true` set on AASM definition
- Non-transactional test configuration for `after_commit` coverage
- VCR cassette inventory: every unique request URI/method from `region_cc.rb` documented
- `cattr_accessor` teardown in characterization test setup blocks

**Addresses:** All table stakes characterization features from FEATURES.md
**Avoids:** Pitfalls 1, 2, 4, 5, 7, 9, 10

### Phase 2: RegionCc HTTP and Sync Service Extraction

**Rationale:** RegionCc has no live scoreboard coupling, no AASM state machine, and no CableReady callbacks. It is the safer model to extract first. `HttpClient` is the dependency for all sync services and must come first within this phase.

**Delivers:**
- `RegionCc::HttpClient` — extracted pure I/O abstraction; VCR cassettes re-recorded against new calling pattern
- `RegionCc::LeagueSyncer` — league and team structure sync, injecting `HttpClient`
- `RegionCc::TournamentSyncer` — tournament and competition sync
- `RegionCc::PartySyncer` — party and game result sync
- RegionCc post-extraction size: ~200-300 lines (down from 2728)

**Uses:** PORO + `call` convention, Reek before/after measurement
**Implements:** RegionCc hub-and-spoke architecture component
**Avoids:** Pitfall 4 (mandatory cassette re-record), Pitfall 8 (service testable without DB via injected HttpClient)

### Phase 3: TableMonitor ScoreEngine Extraction

**Rationale:** Within TableMonitor, `ScoreEngine` is the safest extraction — it touches only the `data` JSON hash, has no AASM coupling, no callback coupling, and no external model writes. Establishing the lazy accessor pattern here validates the integration approach for riskier phases.

**Delivers:**
- `TableMonitor::ScoreEngine` — all score mutation logic (`add_n_balls`, `undo`/`redo`, innings rendering, snooker methods)
- Lazy accessor pattern on `TableMonitor` model validated
- No reflex changes required (model public API preserved)
- TableMonitor size reduction: approximately 500-600 lines removed

**Uses:** PORO pattern, lazy accessor delegation
**Implements:** ScoreEngine component from architecture
**Avoids:** Pitfall 11 (serialized YAML through model accessors only), Pitfall 8 (testable with a plain struct double)

### Phase 4: TableMonitor GameSetup Extraction

**Rationale:** `start_game` (133 lines) is the most entangled method and the home of the `skip_update_callbacks` flag. Extracting it before `ResultRecorder` allows the flag suppression contract to be replaced with an explicit `broadcast:` keyword argument without touching the broadcast path, which is not yet extracted.

**Delivers:**
- `TableMonitor::GameSetup` — `start_game`, `initialize_game`, `assign_game`, player sequence/switching logic
- `skip_update_callbacks` flag replaced with explicit `broadcast: false` keyword argument
- Job enqueue count assertions added for batch operations
- `Game` and `GameParticipation` record creation moved out of the model

**Uses:** PORO pattern, explicit keyword argument for broadcast suppression
**Implements:** GameSetup component from architecture
**Avoids:** Pitfall 2 (`skip_update_callbacks` made explicit), Pitfall 6 (GameSetup does not call CableReady)

### Phase 5: TableMonitor ResultRecorder Extraction

**Rationale:** ResultRecorder is the highest-risk extraction because it fires AASM events on the model (`finish_match!`, `end_of_set!`) which trigger `after_enter` callbacks that call `save` internally, producing a nested save/broadcast chain. This must come last, after all other extractions have validated the integration patterns.

**Delivers:**
- `TableMonitor::ResultRecorder` — `save_result`, `save_current_set`, `evaluate_result`, `switch_to_next_set`, `get_max_number_of_wins`
- TableMonitor post-extraction size: ~600-800 lines (down from 3903)
- All AASM event callbacks verified to still fire correctly when events called from a service

**Uses:** PORO pattern, AASM event delegation to model
**Implements:** ResultRecorder component from architecture
**Avoids:** Pitfall 1 (AASM `after_enter` callbacks fire on save — must not be broken), Pitfall 5 (AASM guard tests clean), Pitfall 6 (ResultRecorder does not call CableReady directly)

---

### Phase Ordering Rationale

- Characterization tests before any extraction — every critical pitfall manifests without this foundation
- RegionCc before TableMonitor — lower real-time risk; failure mode is data inconsistency, not live match breakage; patterns transfer
- `HttpClient` before sync services — sync services cannot inject a testable HTTP dependency without it
- `ScoreEngine` before `GameSetup` before `ResultRecorder` — ordered by coupling surface: zero AASM coupling first, highest AASM coupling last
- Each phase is one coherent domain, one PR, with passing tests before merge — prevents the big-bang extraction anti-pattern

### Research Flags

Phases needing deeper research during planning:
- **Phase 5 (ResultRecorder):** AASM `after_enter` callback behavior when events are fired from inside a service object requires a spike test before planning extraction steps. The behavior is expected to be correct but should be verified empirically.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Characterization Tests):** Standard Minitest + FactoryBot patterns; the work is code reading and test writing, not researching new patterns
- **Phase 2 (RegionCc):** Standard service object extraction with HTTP client injection; well-documented community pattern
- **Phase 3 (ScoreEngine):** Pure data transformation extraction; no integration complexity
- **Phase 4 (GameSetup):** Explicit keyword argument pattern for flag replacement is documented; no novel patterns required

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All gem versions verified via RubyGems API. Alternatives evaluated and rejected with documented rationale. Suture abandonment confirmed (2018). |
| Features | HIGH | Derived from direct code reading of production models. Dependency graph verified against actual method signatures and call sites. |
| Architecture | HIGH | Component boundaries drawn from direct line-by-line inspection of `table_monitor.rb` and `region_cc.rb`. Interface contracts are concrete, not speculative. Line number ranges provided for all extraction targets. |
| Pitfalls | HIGH | All critical pitfalls sourced from direct code reading plus verified external sources (Karol Galanciak, Kelly Sutton, Rails Guides, AASM GitHub). Phase-specific warning table cross-references all pitfalls to concrete phases. |

**Overall confidence: HIGH**

### Gaps to Address

- **`get_options!` / `cattr_accessor` race condition:** Pre-existing issue documented in CONCERNS.md. Extraction does not worsen it, but if `ScoreEngine` ever needs options data, the snapshot pattern must be enforced. Address if it surfaces during Phase 3; defer otherwise.

- **`after_commit_everywhere` gem (conditional):** Only needed if extracted services require `after_commit` hooks outside the model callback chain. Defer adding until Phase 4 or 5 makes the need concrete. Do not add speculatively.

- **AASM `after_enter` service firing behavior:** Architecture research documents that `ResultRecorder` calling `table_monitor.finish_match!` is the correct pattern, but a spike test during Phase 5 planning is recommended before committing to extraction steps.

- **`RegionCc.REPORT_LOGGER` in sync services:** Logger must be passed as a constructor argument or accessed as `RegionCc.logger` — not redefined per service. Specific pattern should be decided in Phase 2 planning.

---

## Sources

### Primary (HIGH confidence)
- Direct code reading: `app/models/table_monitor.rb` (3903 lines) — component boundaries, method clusters, callback chain, line number ranges
- Direct code reading: `app/models/region_cc.rb` (2728 lines) — sync method groupings, HTTP methods, domain clusters
- Direct code reading: `app/jobs/table_monitor_job.rb` (401 lines), `app/reflexes/table_monitor_reflex.rb` — integration points
- RubyGems API: reek 6.5.0 — https://rubygems.org/gems/reek
- RubyGems API: after_commit_everywhere 1.6.0 — https://rubygems.org/gems/after_commit_everywhere
- RubyGems API: suture 1.1.2 (2018, abandoned) — https://rubygems.org/gems/suture
- Karol Galanciak: The inherent unreliability of after_commit callbacks — https://karolgalanciak.com/blog/2022/11/12/the-inherent-unreliability-of-after_commit-callback-and-most-service-objects-implementation/
- AASM GitHub: whiny_transitions option — https://github.com/aasm/aasm
- Rails Guides: Active Record Callbacks — https://guides.rubyonrails.org/active_record_callbacks.html

### Secondary (MEDIUM confidence)
- Code Climate: 7 Patterns to Refactor Fat ActiveRecord Models — https://codeclimate.com/blog/7-ways-to-decompose-fat-activerecord-models
- FastRuby.io: Refactoring Strategies for Rails Models — https://www.fastruby.io/blog/refactoring-strategies-for-rails-model.html
- Selleo: Essential Rails Patterns — Clients and Wrappers — https://medium.com/selleo/essential-rubyonrails-patterns-clients-and-wrappers-c19320bcda0
- Arkency: OOP Refactoring from a god class to smaller objects — https://blog.arkency.com/oop-refactoring-from-a-god-class-to-smaller-objects/
- StimulusReflex Docs: Lifecycle and Troubleshooting — https://docs.stimulusreflex.com/guide/lifecycle
- Kelly Sutton: Rails Callbacks Flatten Layered Architecture — https://kellysutton.com/2018/01/15/rails-callbacks-flatten-layered-architecture.html

### Tertiary (supporting)
- Pedro Costa: Refactoring Long AASM Modules — https://medium.com/@pdrgc/refactoring-long-aasm-modules-d0e331f2054d
- VCR gem documentation — https://github.com/vcr/vcr
- UnderstandLegacyCode.com: Key Points of Working Effectively with Legacy Code — https://understandlegacycode.com/blog/key-points-of-working-effectively-with-legacy-code/

---
*Research completed: 2026-04-09*
*Ready for roadmap: yes*
