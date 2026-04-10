# Phase 4: TableMonitor GameSetup & OptionsPresenter - Research

**Researched:** 2026-04-10
**Domain:** Ruby service extraction from a Rails god-object; callback suppression refactor; PORO view-data presenter
**Confidence:** HIGH

## Summary

Phase 4 extracts two distinct method clusters from `TableMonitor` (2882 lines after Phase 3) into dedicated classes. `TableMonitor::GameSetup` absorbs `start_game`, `initialize_game`, `assign_game`, and player-sequencing helpers — all AR-writing, one-shot operations that fit the `ApplicationService.call(kwargs)` pattern established in Phase 2. `TableMonitor::OptionsPresenter` absorbs `get_options!` and its name-disambiguation helper — a read-only, hash-returning operation that fits the Phase 3 PORO pattern.

The `skip_update_callbacks` attr_accessor is far more widely used than the CONTEXT.md implies. It appears at 30+ call sites in `table_monitor_reflex.rb` alone, used as a bracket around every reflex save: `skip = true → mutate → skip = false → save`. This is NOT the same usage pattern as `start_game`'s usage (internal multi-save suppression). D-04 and D-05 are scoped to the `start_game`/`GameSetup` case only. The reflex call sites must be handled separately — likely by extracting the broadcast-suppression logic into a helper that the reflex can call, or by keeping `skip_update_callbacks` as a transitional shim while only removing it from the model-internal usage. The planner must decide the exact scope.

The `get_options!` method also sets four class-level `cattr_accessor` values (`options`, `gps`, `location`, `tournament`, `my_table`) as a side effect of building the options hash. This is a design smell that complicates extraction: `OptionsPresenter` can return the hash, but the cattr assignments must remain in the thin model wrapper or be explicitly moved to the call site (e.g., `TableMonitorJob`).

**Primary recommendation:** Extract `GameSetup` as an `ApplicationService` subclass under `app/services/table_monitor/game_setup.rb`. Extract `OptionsPresenter` as a PORO under `app/models/table_monitor/options_presenter.rb` (consistent with ScoreEngine). Replace `skip_update_callbacks` in `GameSetup` with a thread-local `@suppress_broadcast` instance variable on the model. Leave the reflex `skip_update_callbacks` usages untouched in this phase — they are a separate concern. [ASSUMED] — scope decision for reflex call sites needs planner confirmation.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** GameSetup is an ApplicationService subclass using `.call(kwargs)` pattern — not a PORO like ScoreEngine.
- **D-02:** GameSetup handles: `start_game`, `initialize_game`, `assign_game`, and player sequence/switching methods. Game and GameParticipation record creation moves into GameSetup.
- **D-03:** GameSetup receives the TableMonitor instance as a parameter: `GameSetup.call(table_monitor: self, options: opts)`. It can call `save!` on the model since it's a service.
- **D-04:** Replace `skip_update_callbacks` attr_accessor with a `broadcast: false` keyword argument on the methods that trigger callbacks. Inside `start_game` (now in GameSetup), batch saves use `update_columns` or pass `broadcast: false` to suppress after_update_commit job enqueueing during the setup sequence.
- **D-05:** The `after_update_commit` callback checks for the `broadcast` flag (or uses a thread-local/instance variable `@suppress_broadcast`) rather than the old `skip_update_callbacks` pattern.
- **D-06:** OptionsPresenter is a PORO (like ScoreEngine). `TableMonitor::OptionsPresenter.new(data, discipline:, locale:).call` returns the options hash.
- **D-07:** OptionsPresenter handles `get_options!` and any helper methods it calls internally. TableMonitor keeps a thin wrapper `def get_options!(locale)` that delegates.

### Claude's Discretion
- Exact method split between what stays in TableMonitor vs moves to GameSetup (some helper methods may need to stay)
- Internal structure of OptionsPresenter (private method organization)
- How to handle the `switch_players` method — may stay in model if it's called from multiple contexts beyond start_game
- Error handling pattern within GameSetup (rescue and re-raise vs let exceptions propagate)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TMON-02 | Extract GameSetup service (game/participation creation, replace skip_update_callbacks) | GameSetup boundary mapped; all AR-write methods catalogued; skip_update_callbacks scope clarified |
| TMON-04 | Extract OptionsPresenter service (view-preparation logic) | get_options! fully read; cattr side-effect risk documented; PORO pattern confirmed |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ruby stdlib (PORO) | 3.2.1 | OptionsPresenter — no gem needed | Read-only hash building requires no external dependency |
| ApplicationService | project-internal | GameSetup base class — `.call(kwargs)` pattern | Matches Phase 2 syncer pattern; project standard for one-shot AR-writing operations |
| Minitest | Rails 7.2 built-in | Unit and characterization tests | Project uses Minitest exclusively |

[VERIFIED: codebase read] — `ApplicationService` at `app/services/application_service.rb` is six lines: `def self.call(kwargs = {}); new(kwargs).call; end`. No gem required for either extraction.

### No New Dependencies Required

Both extractions are pure Ruby reorganizations. No new gems, no new configuration.

## Architecture Patterns

### Recommended File Locations
```
app/services/
└── table_monitor/
    └── game_setup.rb         # New — ApplicationService subclass

app/models/
└── table_monitor/
    ├── score_engine.rb       # Existing (Phase 3)
    └── options_presenter.rb  # New — PORO

test/services/
└── table_monitor/
    └── game_setup_test.rb    # New unit tests

test/models/
└── table_monitor/
    └── options_presenter_test.rb  # New unit tests
```

[ASSUMED] — `OptionsPresenter` placement: both `app/models/table_monitor/` (like ScoreEngine) and `app/services/table_monitor/` are defensible. Phase 3 placed ScoreEngine in `app/models/table_monitor/` because it is a model-level collaborator with no AR writes. OptionsPresenter also has no AR writes, so `app/models/table_monitor/` is consistent. The planner should document the chosen rationale.

### Pattern 1: GameSetup as ApplicationService

**What:** One-shot service that receives the model instance and options hash, performs all AR writes, and returns `true` on success.
**When to use:** Called from `TableMonitor#start_game` (thin wrapper) and from `TableMonitorsController#start_game`.

```ruby
# app/services/table_monitor/game_setup.rb
# frozen_string_literal: true

class TableMonitor::GameSetup < ApplicationService
  def initialize(table_monitor:, options: {})
    @tm = table_monitor
    @options = HashWithIndifferentAccess.new(options)
  end

  def call
    @tm.suppress_broadcast = true
    setup_game_record
    build_result_hash
    @tm.initialize_game        # or inline the logic here
    @tm.deep_merge_data!(result)
    @tm.copy_from = nil
    @tm.save!
    @tm.suppress_broadcast = false
    TableMonitorJob.perform_later(@tm.id, "table_scores")
    @tm.finish_warmup! if shootout? && @tm.may_finish_warmup?
    true
  rescue StandardError => e
    @tm.suppress_broadcast = false
    Rails.logger.error "GameSetup ERROR: m6[#{@tm.id}]#{e}"
    raise
  end

  private

  def setup_game_record
    # ... Game/GameParticipation creation logic from start_game
  end
end
```

[VERIFIED: codebase read] — `ApplicationService.new(kwargs).call` passes a single hash. Because GameSetup needs structured keyword args (`table_monitor:`, `options:`), the `initialize` must accept a hash and destructure it, or the base class pattern must be extended. The simplest approach matching D-03 is to override `self.call` or to define `initialize(table_monitor:, options: {})` and call `TableMonitor::GameSetup.call(table_monitor: self, options: opts)`.

### Pattern 2: OptionsPresenter as PORO

**What:** Stateless hash builder that wraps the model's data and returns the options hash.
**When to use:** Called from thin `TableMonitor#get_options!(locale)` wrapper and from `TableMonitorJob`.

```ruby
# app/models/table_monitor/options_presenter.rb
# frozen_string_literal: true

class TableMonitor::OptionsPresenter
  def initialize(table_monitor, locale:)
    @tm = table_monitor
    @locale = locale
  end

  def call
    I18n.with_locale(@locale) do
      build_options
    end
  end

  private

  def build_options
    # ... the 190-line get_options! body, extracted verbatim
  end
end
```

### Pattern 3: suppress_broadcast Instance Variable

**What:** Replace `skip_update_callbacks` attr_accessor with an instance variable `@suppress_broadcast` checked in the `after_update_commit` lambda.
**Scope:** Only replaces the model-internal usage. Reflex call sites (`table_monitor_reflex.rb`) keep `skip_update_callbacks` as a transitional shim until a future phase refactors them.

```ruby
# In TableMonitor — new accessor
attr_writer :suppress_broadcast

def suppress_broadcast
  @suppress_broadcast || false
end

# In after_update_commit lambda — replace skip_update_callbacks check
if suppress_broadcast
  Rails.logger.info "Skipping callbacks (suppress_broadcast=true)"
  return
end
```

The old `skip_update_callbacks` attr_accessor at line 71 can be kept as a deprecated alias for the reflex call sites:

```ruby
# Transitional shim — reflex still uses this; remove in a later phase
alias_method :skip_update_callbacks=, :suppress_broadcast=
alias_method :skip_update_callbacks, :suppress_broadcast
```

[VERIFIED: codebase read] — `skip_update_callbacks` is set at 30+ locations in `table_monitor_reflex.rb` with the pattern `@tm.skip_update_callbacks = true; ... mutate ...; @tm.skip_update_callbacks = false; @tm.save`. Removing it from the reflex is out of scope for this phase. The alias shim preserves all existing reflex behavior at zero risk while the model-internal flag is renamed.

### Pattern 4: cattr Side-Effects in get_options!

**What:** `get_options!` sets `TableMonitor.options`, `.gps`, `.location`, `.tournament`, `.my_table` (class-level cattr_accessors) as side effects of building the options hash. These are used by partials to avoid DB access.

**After extraction:** The `OptionsPresenter#call` returns the options hash. The thin model wrapper is responsible for assigning the cattr values:

```ruby
# In TableMonitor — thin wrapper
def get_options!(locale)
  result = TableMonitor::OptionsPresenter.new(self, locale: locale).call
  self.class.options   = result
  self.class.gps       = result_gps   # OptionsPresenter must return gps separately
  self.class.location  = table.location
  self.class.tournament = ...
  self.class.my_table  = table
  result
end
```

[VERIFIED: codebase read] — `get_options!` at lines 1073-1265 sets `self.options`, `self.gps`, `self.location`, `self.tournament`, `self.my_table` (all cattr_accessors) at lines 1249-1257. OptionsPresenter returns the options hash but cannot set class-level state without coupling to the model. The thin wrapper must perform those assignments after calling `.call`. The planner must include this in the task for the delegation wrapper.

### Anti-Patterns to Avoid

- **Coupling OptionsPresenter to cattr assignments:** OptionsPresenter should be a pure function: in → out. Cattr side-effects belong in the thin wrapper on the model.
- **Passing options hash by reference into GameSetup:** The options parameter from the controller/reflex is an `ActionController::Parameters` object. GameSetup must coerce it with `HashWithIndifferentAccess.new(options_)` as `start_game` does today.
- **Inlining initialize_game into GameSetup constructor:** `initialize_game` is called from `assign_game` as well as `start_game`. If it moves entirely into GameSetup, `assign_game` (also in GameSetup) must call it via `self` — this is fine. But if `initialize_game` is ever needed outside GameSetup in the future, it becomes a problem. Keep it as a private method of GameSetup for now.
- **Removing skip_update_callbacks from reflex in this phase:** The reflex has 30+ call sites. Removing the attr_accessor without a shim will break all of them. The alias pattern is the safe path.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Thread-safety for broadcast suppression | Custom thread-local global | `@suppress_broadcast` instance variable on the model | Instance variables are inherently thread-safe per request in Rails |
| Options hash construction | Custom serialization/view-model gem | Plain Ruby hash with `HashWithIndifferentAccess` | Already used in get_options! today; no new abstraction needed |
| Lazy delegation | Forwardable module | Manual `def get_options!(locale); OptionsPresenter.new(self, locale:).call; end` | The wrapper is 2-3 lines; Forwardable adds complexity for no gain here |

## Method Boundary Map

### Methods Moving INTO GameSetup

| Method | Location | AR Writes? | Notes |
|--------|----------|-----------|-------|
| `start_game` | line 2001 | Yes (Game, GameParticipation, save!) | Core extraction target |
| `initialize_game` | line 775 | No (hash mutation only + deep_merge_data!) | Called from start_game and assign_game; moves with them |
| `assign_game` | line 736 | Yes (save!, start_new_match! AASM) | Moves with start_game cluster |
| `set_player_sequence` | line 2168 | No (data mutation only) | Moves if only called from GameSetup context |

### Methods with Discretion (may stay in model)

| Method | Location | Called From | Recommendation |
|--------|----------|------------|----------------|
| `switch_players` | line 674 | reflex (3 call sites), `revert_players` | STAY in model — called from reflex directly, not only from start_game |
| `revert_players` | line 2132 | controller | STAY in model — calls start_game but is itself a model-level reset |
| `seeding_from` | line 978 | `initialize_game` | MOVE into GameSetup if initialize_game moves there |

[VERIFIED: codebase grep] — `switch_players` is called at reflex lines 129, 187, 341. These are direct model calls that do not go through GameSetup. If `switch_players` moves into GameSetup, reflex must change to call `GameSetup.call(...)` for this operation — that is a larger change than needed. The CONTEXT.md notes "may stay in model if called from multiple contexts."

### Methods Moving INTO OptionsPresenter

| Method | Location | AR Writes? | Notes |
|--------|----------|-----------|-------|
| `get_options!` | line 1073 | No (hash building + cattr assignments) | Full body moves; cattr assignments stay in wrapper |
| Disambiguation helper (lines 1221-1246) | inside get_options! | No | Private method of OptionsPresenter |

### Characterization Test Coverage Required

The existing `table_monitor_char_test.rb` stubs `get_options!` to return nil in callback tests. After extraction, these stubs still work because the thin wrapper has the same signature. No characterization test changes needed for the stub behavior. New tests needed for:

1. `GameSetup.call` — verifies Game and GameParticipation creation, data initialization, correct jobs enqueued
2. `OptionsPresenter.new(tm, locale:).call` — verifies options hash keys/values match pre-extraction behavior
3. `after_update_commit` broadcast suppression — verifies `suppress_broadcast = true` prevents job enqueuing (existing job-count char tests already cover the positive case)

## Common Pitfalls

### Pitfall 1: Breaking the 30+ Reflex skip_update_callbacks Call Sites
**What goes wrong:** Removing the `attr_accessor :skip_update_callbacks` at line 71 without a compatibility shim causes `NoMethodError` across all reflex actions.
**Why it happens:** D-04/D-05 read as a full replacement, but the reflex is outside the extraction scope.
**How to avoid:** Keep `attr_accessor :skip_update_callbacks` or replace with alias methods. Do not remove it until all reflex call sites are updated.
**Warning signs:** Test suite will show `NoMethodError: undefined method 'skip_update_callbacks='` on TableMonitor.

### Pitfall 2: cattr_accessor State Leaking Between Tests After Extraction
**What goes wrong:** OptionsPresenter returns the hash; thin wrapper sets catrs. If the wrapper or OptionsPresenter sets catrs in a class method context, test pollution occurs.
**Why it happens:** The Phase 1 characterization tests already guard against this with setup/teardown that resets all 5 catrs to nil. Any new test for OptionsPresenter must do the same.
**How to avoid:** Copy the cattr reset block from `TableMonitorCharTest` setup/teardown into any new test class that tests `get_options!` or OptionsPresenter.
**Warning signs:** Flaky tests where order matters.

### Pitfall 3: GameSetup Cannot Call Private TableMonitor Methods
**What goes wrong:** `initialize_game` calls `deep_merge_data!`, `seeding_from`, `data_will_change!` — methods on the model. After moving to GameSetup, these are called on `@tm`, so they must be `public` or `protected` on the model.
**Why it happens:** `initialize_game` was private to the model. Moving it to a collaborator changes the visibility requirement.
**How to avoid:** Before extracting, check which methods `initialize_game` and `start_game` call on `self`, and verify they are accessible from GameSetup's `@tm` reference. Make them `public` if needed, or keep GameSetup as a `module` included in TableMonitor to sidestep visibility.
**Warning signs:** `NoMethodError: private method 'deep_merge_data!' called` in GameSetup tests.

### Pitfall 4: OptionsPresenter Signature Mismatch with Existing Stubs
**What goes wrong:** Existing characterization tests stub `get_options!` as `@tm.stub(:get_options!, nil)`. If the wrapper signature changes (e.g., adds required args), stubs break.
**Why it happens:** D-07 says "TableMonitor keeps a thin wrapper `def get_options!(locale)`." As long as the wrapper keeps the same `(locale)` signature, existing stubs are unaffected.
**How to avoid:** Keep the thin wrapper signature identical to the existing `def get_options!(locale)`.

### Pitfall 5: GameSetup Instance Variable @suppress_broadcast Not Cleaned Up on Error
**What goes wrong:** If GameSetup raises an exception after setting `@tm.suppress_broadcast = true`, the flag is never reset. Subsequent saves on the same model instance skip broadcasts.
**Why it happens:** The rescue block in `start_game` currently sets `self.skip_update_callbacks = false` before re-raising. GameSetup's `call` method must do the same in its rescue block.
**How to avoid:** Use ensure to guarantee cleanup: `ensure; @tm.suppress_broadcast = false`.

## Code Examples

### GameSetup Call Pattern
```ruby
# Source: app/models/table_monitor.rb line 2001 (current start_game)
# Thin wrapper that replaces start_game in TableMonitor after extraction

def start_game(options_ = {})
  TableMonitor::GameSetup.call(table_monitor: self, options: options_)
end
```

### suppress_broadcast in after_update_commit
```ruby
# Source: app/models/table_monitor.rb line 73-79 (current skip_update_callbacks check)
# Replacement pattern

after_update_commit lambda {
  if @suppress_broadcast
    Rails.logger.info "Skipping callbacks (suppress_broadcast=true)"
    return
  end
  # ... rest of callback
}
```

### OptionsPresenter Delegation Wrapper
```ruby
# Thin wrapper in TableMonitor — preserves existing signature and cattr side-effects
def get_options!(locale)
  cache_key = "#{locale}_#{updated_at.to_i}"
  return @cached_options if @cached_options && @cached_options_key == cache_key

  result = TableMonitor::OptionsPresenter.new(self, locale: locale).call
  # cattr assignments must stay here — OptionsPresenter is a PORO without model coupling
  self.class.options   = result
  # gps, location, tournament, my_table also assigned here
  @cached_options = result
  @cached_options_key = cache_key
  result
end
```

[VERIFIED: codebase read] — The instance-level cache (`@cached_options`, `@cached_options_key`) at lines 1076-1080 is inside `get_options!`. After extraction, the cache logic can either stay in the thin wrapper (cleaner) or move into OptionsPresenter (requires passing the cache key in). The thin wrapper approach is simpler and keeps OptionsPresenter pure.

## Open Questions

1. **Scope of skip_update_callbacks replacement**
   - What we know: D-04/D-05 say replace with `broadcast: false` or `@suppress_broadcast`. The reflex has 30+ call sites using the old pattern.
   - What's unclear: Does D-05 require removing the attr_accessor entirely this phase, or only replacing the model-internal usage?
   - Recommendation: Replace only the model-internal flag (in GameSetup and after_update_commit). Keep `attr_accessor :skip_update_callbacks` as an alias shim for the reflex. Plan a follow-up task in Phase 4 to update reflex call sites, or defer to Phase 6.

2. **Visibility of TableMonitor methods called from GameSetup**
   - What we know: `initialize_game`, `assign_game`, `deep_merge_data!`, `seeding_from` are all defined in TableMonitor. After extracting to GameSetup, they are called via `@tm`.
   - What's unclear: Which of these are currently private? If private, they cannot be called from GameSetup.
   - Recommendation: Wave 0 task should audit visibility of all methods GameSetup will call on `@tm` and make necessary ones `protected`.

3. **OptionsPresenter gps return**
   - What we know: `get_options!` uses a local variable `gps` (game participations) at line 1086, then assigns `self.gps = gps` at line 1250. The returned options hash does not contain gps.
   - What's unclear: Should OptionsPresenter return `{options:, gps:}` tuple, or should the wrapper query gps separately?
   - Recommendation: Have OptionsPresenter store `@gps` as an instance variable accessible after `call`, so the wrapper can read it: `presenter = OptionsPresenter.new(...); result = presenter.call; self.class.gps = presenter.gps`.

## Environment Availability

Step 2.6: SKIPPED — no external dependencies. This is a pure code reorganization with no new tools, databases, or runtime services.

## Validation Architecture

`nyquist_validation: false` in config.json. Section omitted per config.

## Security Domain

No new authentication, authorization, or input-handling surface introduced by this extraction. Security posture unchanged. `skip_update_callbacks` removal does not affect security. Section omitted — no new ASVS-applicable controls.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Reflex skip_update_callbacks call sites are out of scope for this phase | User Constraints / Open Questions | If in scope, the reflex must be updated at 30+ call sites — significantly larger change |
| A2 | OptionsPresenter belongs in app/models/table_monitor/ (consistent with ScoreEngine) | Architecture Patterns | If placed in app/services/, test paths and require paths differ — minor impact |
| A3 | initialize_game and assign_game methods are currently public or accessible from GameSetup | Method Boundary Map | If private, Wave 0 must include a visibility audit task |
| A4 | The cattr assignments (options, gps, location, tournament, my_table) must remain in the thin wrapper | cattr Side-Effects section | If OptionsPresenter sets them internally, it couples a PORO to class-level model state |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

## Sources

### Primary (HIGH confidence)
- `app/models/table_monitor.rb` (lines 71-184, 674-770, 775-967, 1073-1265, 2001-2130) — [VERIFIED: codebase read] all methods under extraction
- `app/reflexes/table_monitor_reflex.rb` — [VERIFIED: codebase read] 30+ skip_update_callbacks call sites
- `app/jobs/table_monitor_job.rb` — [VERIFIED: codebase read] job enqueue patterns and get_options! call sites
- `app/models/table_monitor/score_engine.rb` — [VERIFIED: codebase read] PORO template for OptionsPresenter
- `app/services/application_service.rb` — [VERIFIED: codebase read] 6-line base class; `.call(kwargs)` pattern
- `app/controllers/table_monitors_controller.rb` (lines 66-205) — [VERIFIED: codebase read] controller start_game call site
- `test/characterization/table_monitor_char_test.rb` — [VERIFIED: codebase read] get_options! stub pattern used in 5 tests
- `.planning/phases/03-tablemonitor-scoreengine/03-RESEARCH.md` — [VERIFIED: read] Phase 3 extraction patterns

### Secondary (MEDIUM confidence)
- Phase 3 RESEARCH.md — extraction pattern documentation (internal, authoritative for this project)

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Method boundary map: HIGH — all methods read directly from source
- skip_update_callbacks scope risk: HIGH — grep confirmed 30+ reflex call sites
- GameSetup pattern: HIGH — ApplicationService base class verified; Phase 2 syncer pattern confirmed
- OptionsPresenter cattr risk: HIGH — lines 1249-1257 read directly
- Reflex scope question: MEDIUM — depends on user intent for D-04/D-05

**Research date:** 2026-04-10
**Valid until:** Until Phase 4 execution — code is stable; no external dependencies
