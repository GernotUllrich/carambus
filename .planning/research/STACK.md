# Technology Stack: Rails God-Model Refactoring

**Project:** Carambus API — TableMonitor & RegionCc extraction
**Researched:** 2026-04-09
**Scope:** Tools and patterns for extracting service objects from oversized ActiveRecord models in a Rails 7.2 / Minitest brownfield app

---

## Decision Summary

This is a **no-new-framework** refactoring. The goal is extracting logic from two god-models into Plain Old Ruby Objects (POROs). The tooling question is narrow: what assists characterization testing, code smell detection, and safe service extraction? The answer is a small, targeted addition of dev/test gems — not a new architectural framework like dry-rb or interactor.

---

## Recommended Stack

### Service Object Convention

| Approach | Rationale |
|----------|-----------|
| PORO with `call` convention | No gem needed. Conventions: single public method `call`, `initialize` takes explicit dependencies, returns a result struct or raises. Consistent with what already exists in `app/services/`. Adding dry-monads or interactor would require rewriting existing services to match the new convention — a risk with no proportionate gain for this scope. |

**Pattern to standardize on:**

```ruby
# app/services/table_monitor/state_broadcaster.rb
module TableMonitor
  class StateBroadcaster
    def initialize(table_monitor:)
      @table_monitor = table_monitor
    end

    def call
      # single responsibility: CableReady broadcast for state change
    end

    private

    attr_reader :table_monitor
  end
end
```

Result: call it with `TableMonitor::StateBroadcaster.new(table_monitor: tm).call`. No new dependency. Immediately testable with Minitest.

**Confidence: HIGH** — Established Rails convention. No version to track.

---

### Static Analysis: Code Smell Detection

#### Reek 6.5.0

**Install:** `gem "reek", require: false` (dev group)

**Why:** Reek is the standard Ruby static analysis tool for code smell detection. Its `LargeClass`, `TooManyMethods`, `FeatureEnvy`, and `DataClump` detectors directly map to the problems in TableMonitor and RegionCc. Running Reek before and after extraction gives objective evidence of improvement.

**Version:** 6.5.0 (released 2025-03-24) — current.

**Confidence: HIGH** — RubyGems verified.

**What it detects relevant to this project:**
- `LargeClass` — flags TableMonitor (3903 lines) and RegionCc (2728 lines)
- `TooManyMethods` — flags TableMonitor (96 methods)
- `FeatureEnvy` — methods that belong in another class (extraction targets)
- `DataClump` — groups of data that should become a value object

**Do NOT use RubyCritic** as a substitute here — it wraps Reek but adds HTML report overhead. Use Reek directly on the target files.

---

#### RuboCop Metrics Cops (already in project via `standard`)

The project already has `standard` (which wraps RuboCop). No new gem needed. Configure `.rubocop.yml` overrides for Metrics cops during the refactoring:

```yaml
# .rubocop.yml additions for refactoring visibility
Metrics/ClassLength:
  Max: 500          # target for extracted models
  CountAsOne: ['array', 'hash', 'heredoc']

Metrics/MethodLength:
  Max: 15
  CountAsOne: ['array', 'hash', 'heredoc']

Metrics/AbcSize:
  Max: 25
```

These are **aspirational targets for new extracted classes**, not enforced on legacy files yet. Use `rubocop:todo` inline comments to exclude the legacy files explicitly.

**Confidence: HIGH** — Already installed, configuration only.

---

### Characterization Testing

#### Minitest (already in project)

No new test framework. The project uses Minitest with fixtures and FactoryBot. Characterization tests fit naturally:

```ruby
# test/models/table_monitor_characterization_test.rb
class TableMonitorCharacterizationTest < ActiveSupport::TestCase
  # Pin current behavior before refactoring.
  # These tests describe what the code DOES, not what it SHOULD do.
  test "state transition from available to playing triggers broadcast" do
    tm = table_monitors(:available_table)
    assert_difference -> { CableReady::... } do
      tm.start_game!(game)
    end
  end
end
```

**Confidence: HIGH** — Project standard, no change.

---

#### suture gem — NOT RECOMMENDED

Suture records production call signatures and auto-generates characterization tests. It looks appealing for a 3900-line god class.

**Why to skip it:**
- Last release: 1.1.2 in **2018**. No updates in 7 years. Last GitHub push was September 2023 (minor tooling), not a maintenance release.
- Requires a SQLite side database for recording; adds an environment dependency.
- Recording requires running the app and exercising code paths, which is slower than reading the code and writing targeted tests manually.
- The existing VCR cassettes and FactoryBot fixtures already provide the infrastructure. The gap is effort, not tooling.

**Instead:** Write characterization tests by hand using the existing Minitest + FactoryBot setup. Focus on the explicit input/output of each method you plan to extract. This is slower but produces tests that remain maintainable.

**Confidence: HIGH** — Suture abandonment verified via RubyGems (1.1.2 / 2018-11-12).

---

### Callback Isolation

#### after_commit_everywhere 1.6.0

**Install:** `gem "after_commit_everywhere", "~> 1.6"` (main group, not dev-only)

**Why:** TableMonitor has complex `after_update_commit` callbacks. When extracting state broadcasting logic, you often need to fire transactional callbacks from service objects that live outside models. `after_commit_everywhere` lets service objects register `after_commit` hooks without inheriting from ActiveRecord.

**Version:** 1.6.0 (released 2025-02-07) — current. Actively maintained.

**When to use it:** Only if extracted services need to ensure their side effects (CableReady broadcasts, job enqueues) happen after the transaction commits, not mid-transaction.

**When NOT to use it:** If the service is called explicitly from a controller or job outside a model callback chain, plain `after_commit` in the model calling the service is sufficient and cleaner.

**Confidence: MEDIUM** — RubyGems verified current. Usage pattern is well-documented but conditional on how TableMonitor's callback chain is restructured.

---

## Alternatives Considered and Rejected

| Category | Recommended | Alternative | Why Rejected |
|----------|-------------|-------------|--------------|
| Service structure | PORO + `call` convention | `interactor` gem (3.2.0 / Jul 2025) | Interactor's context object and organizers add indirection with no benefit for single-responsibility extractions. The project has no multi-step orchestration needs that POROs can't handle. Brownfield cost: no existing services use interactor. |
| Service structure | PORO + `call` convention | `dry-monads` (1.9.0 / Jun 2025) + `dry-transaction` (0.16.0 / Jan 2024) | dry-monads is the right tool for complex error-railway pipelines. But dry-transaction is stagnating (last release Jan 2024) and the pattern requires team familiarity with monadic programming. For a single-engineer brownfield refactoring, the cognitive overhead exceeds the benefit. RegionCc's HTTP error handling can be addressed with explicit rescue blocks in plain POROs. |
| Characterization testing | Hand-written Minitest | `suture` gem | Abandoned in 2018, no maintenance. See above. |
| Code analysis | Reek + RuboCop Metrics | RubyCritic | RubyCritic wraps Reek + adds HTML overhead. Overkill for targeted file-by-file analysis during refactoring. |
| State machine | Keep AASM as-is | Migrate to Rails 7.1 enum | AASM is in-use across TableMonitor with dozens of events and callbacks. Migrating the state machine is a separate concern and orthogonal to extracting service logic. The PROJECT.md explicitly excludes architecture changes. |

---

## What to Install

```ruby
# Gemfile additions

group :development do
  gem "reek", "~> 6.5", require: false    # Code smell detection; run on extraction targets
end

gem "after_commit_everywhere", "~> 1.6"   # Only if service objects need after_commit hooks
                                           # outside model callbacks; defer adding until needed
```

No other new gems are required. The characterization testing, assertion, and factory infrastructure already exists (Minitest, FactoryBot, WebMock, VCR).

---

## Naming Convention for Extracted Services

Namespace under the model name to keep `app/services/` navigable:

```
app/services/
  table_monitor/
    state_broadcaster.rb        # CableReady broadcast logic
    callback_handler.rb         # after_update_commit orchestration
    game_timer_service.rb       # timer start/stop logic
  region_cc/
    club_cloud_sync.rb          # HTTP + sync orchestration
    player_data_transformer.rb  # raw response → ActiveRecord attributes
    league_importer.rb          # league creation/update logic
```

Each service: one public `call` method, explicit `initialize` dependencies, no ActiveRecord callbacks inside the service itself.

---

## Sources

- RubyGems API: reek 6.5.0 — https://rubygems.org/gems/reek
- RubyGems API: after_commit_everywhere 1.6.0 — https://rubygems.org/gems/after_commit_everywhere
- RubyGems API: interactor 3.2.0 — https://rubygems.org/gems/interactor
- RubyGems API: dry-monads 1.9.0 — https://rubygems.org/gems/dry-monads
- RubyGems API: dry-transaction 0.16.0 — https://rubygems.org/gems/dry-transaction
- RubyGems API: suture 1.1.2 (2018) — https://rubygems.org/gems/suture
- GitHub: testdouble/suture — last push 2023-09-29, not archived
- after_commit_everywhere docs — https://github.com/Envek/after_commit_everywhere
- Service Objects best practices — https://www.honeybadger.io/blog/refactor-ruby-rails-service-object/
- Rails callback extraction pattern — https://guides.rubyonrails.org/active_record_callbacks.html
- Reek code smells — https://github.com/troessner/reek
