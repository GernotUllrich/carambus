# Phase 12: Tournament Characterization - Research

**Researched:** 2026-04-10
**Domain:** Tournament model characterization — AASM state machine, scraping pipeline, dynamic attribute delegation, PaperTrail versioning, Google Calendar integration, rankings calculation
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Cover all clusters: AASM (10 states, 8 events), scraping pipeline (~420 lines + 10 variant methods), dynamic attributes (13 define_method getters/setters), PaperTrail versioning, Google Calendar reservation, rankings calculation.

**D-02:** Existing `tournament_test.rb` (51 lines) is left as-is — new characterization tests go in separate files.

**D-03:** Record VCR cassettes from real ClubCloud tournament URLs. Claude discovers appropriate public tournament URLs from the codebase or existing cassettes during execution.

**D-04:** The scraping method `scrape_single_tournament_public` has 10+ variant methods for different result formats — VCR cassettes should cover at least the most common variants.

**D-05:** Split by concern into separate test files in `test/models/`:
- `tournament_aasm_test.rb` — AASM state transitions, guards, after_enter callbacks
- `tournament_scraping_test.rb` — scrape_single_tournament_public with VCR cassettes
- `tournament_attributes_test.rb` — 13 dynamic define_method getters/setters, tournament_local delegation for global records
- `tournament_papertrail_test.rb` — PaperTrail version count baselines for all state-changing operations
- Additional files for calendar/rankings if needed (Claude's discretion)

**D-06:** Assert version counts for all state-changing operations: create, each AASM transition, attribute updates (including tournament_local delegation path for global records), destroy. These baseline counts are the sync contract — extraction must preserve them exactly.

**D-07:** Run Reek on `app/models/tournament.rb`. One-time baseline report saved to `.planning/phases/12-tournament-characterization/` for comparison after extraction phases.

### Claude's Discretion

- Exact test method grouping within each concern file
- Which AASM transitions and guard chains to prioritize
- Which scraping variants to cover with VCR (based on URL discovery)
- Whether to create a shared TournamentTestHelper for fixture setup
- How to handle the 13 dynamic attribute test coverage (all paths or representative subset)
- Whether calendar and rankings tests need their own files or fit in existing ones

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CHAR-05 | Tournament AASM state machine transitions covered by tests | AASM block fully mapped: 9 states + `closed`, 8 events, 2 guards, `before_all_events`, 2 `after_enter` callbacks. See Architecture Patterns. |
| CHAR-06 | Scraping pipeline covered by VCR-backed tests | `scrape_single_tournament_public` makes 4 HTTP calls per run. VCR cassette strategy documented. ClubCloud URL pattern identified from `scraped` fixture. |
| CHAR-07 | All 13 dynamic attribute define_method getters/setters covered | Exact 13 attributes enumerated. Two code paths identified: global (id < MIN_ID → tournament_local) and local (id >= MIN_ID → read_attribute). |
| CHAR-08 | PaperTrail version baselines established | PaperTrail configured via LocalProtector's `has_paper_trail` with skip lambda. Version-producing operations identified. Existing test pattern confirmed. |
</phase_requirements>

---

## Summary

Tournament is a 1775-line Rails model with seven distinct responsibility clusters. This phase pins all of them with characterization tests before any extraction begins. The Reek baseline (412 warnings) has been saved to `reek-baseline.txt` for comparison after extraction phases — D-07 is already complete.

The AASM block declares 9 named states (plus the implicit initial state `new_tournament`) and 8 events. Two `after_enter` callbacks produce significant side effects: `reset_tournament` destroys TournamentMonitor and cascades to TableMonitor resets; `calculate_and_cache_rankings` writes to the `data` JSON blob. Both are critical to characterize before extraction.

The scraping pipeline (`scrape_single_tournament_public`) makes exactly 4 HTTP calls in sequence: tournament page, registration list, results page, ranking page. All 4 must be recorded as a single VCR cassette or 4 coordinated cassettes. No existing tournament-scraping cassettes exist — they must be recorded fresh. The ClubCloud URL pattern is known from fixtures and the `SHORTNAMES_CC` map. The 10 `parse_table_tr` variant dispatch branches (`variant0` through `variant8` plus two named variants) are private methods that can be tested via `send`.

PaperTrail is configured through `LocalProtector#has_paper_trail` (not a `has_paper_trail` call in the model itself). In the test environment, `Carambus.config.carambus_api_url` is absent, so PaperTrail IS active for Tournament in tests. The skip lambda only skips versions when ALL changed attributes are in `['updated_at', 'sync_date']`.

**Primary recommendation:** Write tests in this order: `tournament_attributes_test.rb` first (no HTTP, no state machine), then `tournament_aasm_test.rb`, then `tournament_papertrail_test.rb`, then `tournament_scraping_test.rb` last (requires real HTTP recording or existing cassettes).

---

## Standard Stack

### Core Test Infrastructure (already installed)
| Component | Version | Purpose | Notes |
|-----------|---------|---------|-------|
| Minitest | Rails default | Test runner | `test "description"` syntax |
| VCR | 6.4.0 [VERIFIED: existing cassettes] | HTTP record/replay | Config in `test/support/vcr_setup.rb` |
| WebMock | bundled | HTTP blocking | `disable_net_connect!` in test_helper |
| FactoryBot Rails | bundled | Test data | `fixtures :all` is primary, FactoryBot secondary |
| PaperTrail | bundled | Version tracking | Active in test env for Tournament |

**VCR is already configured** at `test/support/vcr_setup.rb`:
- cassette library: `test/snapshots/vcr/`
- hook: `:webmock`
- record mode: `:once`
- match: `[:method, :uri]`
- `allow_playback_repeats: true`

**No new gems required.** All infrastructure exists.

---

## Architecture Patterns

### AASM State Machine (CHAR-05)

**States** (line 271–311, `aasm column: "state", skip_validation_on_save: true`):

```
new_tournament (initial)     after_enter: [:reset_tournament]
accreditation_finished
tournament_seeding_finished  after_enter: [:calculate_and_cache_rankings]
tournament_mode_defined
tournament_started_waiting_for_monitors
tournament_started
tournament_finished
results_published
closed
```

**Events** (8 total):

| Event | From | To | Guards |
|-------|------|----|--------|
| `finish_seeding` | new_tournament, accreditation_finished, tournament_seeding_finished | tournament_seeding_finished | none |
| `finish_mode_selection` | new_tournament, tournament_seeding_finished, tournament_mode_defined | tournament_mode_defined | none |
| `start_tournament!` | tournament_started, tournament_mode_defined, tournament_started_waiting_for_monitors | tournament_started_waiting_for_monitors | none |
| `signal_tournament_monitors_ready` | tournament_started, tournament_mode_defined, tournament_started_waiting_for_monitors | tournament_started | none |
| `reset_tmt_monitor` | any | new_tournament | `tournament_not_yet_started` AND `admin_can_reset_tournament?` |
| `forced_reset_tournament_monitor` | any | new_tournament | `admin_can_reset_tournament?` |
| `finish_tournament` | any | tournament_finished | none |
| `have_results_published` | tournament_finished | results_published | none |

**Callbacks**:
- `before_all_events :before_all_events` — logs `aasm.current_event` (line 1653)
- `skip_validation_on_save: true` — ALL transition saves bypass ActiveRecord validators

**Guard implementations** (lines 942–957):
```ruby
# tournament_not_yet_started: true if no local games exist (games.id >= MIN_ID)
def tournament_not_yet_started
  !tournament_started
end

def tournament_started
  games.where("games.id >= #{Game::MIN_ID}").present?
end

# admin_can_reset_tournament?: true if no current_user, or user is club_admin/system_admin
def admin_can_reset_tournament?
  current_user = User.current || PaperTrail.request.whodunnit
  return true if current_user.blank?
  user = current_user.is_a?(User) ? current_user : User.find_by(id: current_user)
  user&.club_admin? || user&.system_admin?
end
```

**`after_enter :reset_tournament` cascade** (lines 833–881):
1. Collects all `tournament_monitor.table_monitors` before destroy
2. Destroys `tournament_monitor` (triggers `TableMonitor#reset_table_monitor` per monitor)
3. Destroys local seedings (`seedings.id >= Seeding::MIN_ID`) unless organizer is Club
4. Reorders remaining seedings by position
5. Destroys local games (`games.id >= Game::MIN_ID`)
6. Clears `tournament_plan_id`, `state`, `data` to `{}` via `save` (not `save!`)
7. Broadcasts teasers to table monitors via `TableMonitorJob`

**`after_enter :calculate_and_cache_rankings`** (lines 886–932):
- Returns early unless `organizer.is_a?(Region) && discipline.present?`
- Returns early unless `id >= Tournament::MIN_ID` (local records only)
- Loads `PlayerRanking` across 3 seasons
- Writes `data['player_rankings']` hash (player_id → rank integer)
- Calls `save!` — produces a PaperTrail version if any substantive field changed

**Note on `whiny_transitions`**: Not set explicitly in the AASM block. AASM default is `whiny_transitions: true` for bang methods, silent for non-bang. [ASSUMED — not verified against current AASM gem version, but standard behavior]

### Dynamic Attribute Delegation (CHAR-07)

**Exact 13 attributes** (lines 239–269):
```ruby
%i[timeouts timeout gd_has_prio admin_controlled auto_upload_to_cc sets_to_play sets_to_win
   team_size kickoff_switches_with allow_follow_up allow_overflow
   fixed_display_left color_remains_with_set]
```

**Getter code path** (per attribute):
```ruby
define_method(meth) do
  id.present? && id < Tournament::MIN_ID && tournament_local.present? ?
    tournament_local.send(meth) :
    read_attribute(meth)
end
```

- **Global record** (id < 50_000_000) with `tournament_local` present: reads from `tournament_local`
- **Global record** without `tournament_local`: reads from `read_attribute` (fallback)
- **Local record** (id >= 50_000_000): reads from `read_attribute`
- **New record** (id nil): reads from `read_attribute`

**Setter code paths** (3 branches):
```ruby
define_method(:"#{meth}=") do |value|
  if new_record?
    write_attribute(meth, value)                           # Branch 1: new record
  elsif id < Tournament::MIN_ID
    tol = tournament_local.presence || create_tournament_local(...)   # Branch 2: global — upsert tournament_local
    tol.update(meth => value)
  else
    write_attribute(meth, value)                           # Branch 3: local record
  end
end
```

**Key test scenarios required:**
1. Getter — local record (id >= MIN_ID): returns `read_attribute` value
2. Getter — global record with tournament_local: returns `tournament_local.send(meth)` value
3. Getter — global record without tournament_local: falls back to `read_attribute`
4. Setter — new record: calls `write_attribute`
5. Setter — global record (creates tournament_local): calls `create_tournament_local` then `update`
6. Setter — global record (updates existing tournament_local): calls existing `tol.update`
7. Setter — local record: calls `write_attribute`

**TournamentLocal schema** (all 13 attributes present as columns): `admin_controlled`, `allow_follow_up`, `allow_overflow`, `color_remains_with_set`, `fixed_display_left`, `gd_has_prio`, `kickoff_switches_with`, `sets_to_play`, `sets_to_win`, `team_size`, `timeout`, `timeouts`. Note: `auto_upload_to_cc` is in the `define_method` loop but NOT in the `tournament_locals` table schema — setter will call `tol.update(auto_upload_to_cc: value)` which will fail silently or raise. **Flag for investigation during test writing.** [VERIFIED: schema read from `tournament_local.rb` annotation]

### PaperTrail Configuration (CHAR-08)

**How PaperTrail is activated for Tournament:**
- `Tournament` includes `LocalProtector` (line 62)
- `LocalProtector` calls `has_paper_trail(skip: lambda {...})` unless `Carambus.config.carambus_api_url.present?` (local_protector.rb line 9)
- In test environment: `carambus_api_url` is absent → PaperTrail IS active

**Skip lambda** (skips version creation when ALL changed attrs are in ignorable set):
```ruby
skip: lambda { |obj|
  return false unless obj.saved_changes.present?
  changed_attrs = obj.saved_changes.keys.map(&:to_s)
  ignorable_attrs = ['updated_at']
  ignorable_attrs << 'sync_date' if obj.class.column_names.include?('sync_date')
  (changed_attrs - ignorable_attrs).empty?
}
```

**Operations that produce versions** (tested in existing `tournament_test.rb`):
- `Tournament.create!` → 1 version
- `tournament.update!(title: "...")` → 1 version (title change is substantive)
- `tournament.update_columns(sync_date: ...)` → 0 versions (bypasses callbacks entirely)
- AASM transitions via `save!` (with `skip_validation_on_save: true`) → 1 version if state column change is substantive

**Operations confirmed NOT to produce versions:**
- `update_columns` — bypasses ActiveRecord callbacks entirely
- Updates where only `updated_at` or `sync_date` change (skip lambda fires)

**D-06 baseline contract**: For each state-changing operation, assert exact version count delta using `assert_difference "tournament.versions.count", N do ... end`.

**PaperTrail whodunnit**: Set via `before_save :set_paper_trail_whodunnit` on both `ApplicationRecord` and `LocalProtector`. The `LocalProtector` version sets whodunnit to a stack trace proc; the `ApplicationRecord` version sets it to `Current.user&.id`. Since `LocalProtector` is included after `ApplicationRecord` callbacks in the include order, both run. [ASSUMED — callback ordering via `before_save` chain, not explicitly documented]

### Scraping Pipeline (CHAR-06)

**Method**: `scrape_single_tournament_public(opts = {})` (lines 392–810)

**Guard conditions** (method returns early if):
- `organizer_type != "Region"` (line 394)
- `Carambus.config.carambus_api_url.present?` (line 395) — method is API-server-only

**4 HTTP calls in sequence** (URLs built dynamically from `organizer.public_cc_url_base` and `tournament_cc.cc_id`):
1. Tournament page: `sb_meisterschaft.php?p={region_cc_id}--{season}-{tournament_cc_id}----1-100000-`
2. Registration list: `sb_meldeliste.php?p=...` (same params, `meisterschaft` → `meldeliste`)
3. Results page: `sb_einzelergebnisse.php?p=...` (same params, `meisterschaft` → `einzelergebnisse`)
4. Ranking page: `sb_einzelrangliste.php?p=...` (same params, `meisterschaft` → `einzelrangliste`)

**Known ClubCloud base URL for NBV** (the fixture region): `https://ndbv.de/`
**Source URL from `scraped` fixture**: `https://nbv.clubcloud.de/sb_meisterschaft.php?p=20--2025-123-0--2-1-100000-`

**Note on NBV URL**: The fixture uses `nbv.clubcloud.de` but the `SHORTNAMES_CC` map has `"NBV" => "https://ndbv.de/"`. The actual URL base depends on the `region.public_cc_url_base` column value, not the constant. The constant is only used to seed the value. Real cassette recording must use the actual URL that `Region#public_cc_url_base` returns for the NBV fixture. [VERIFIED: SHORTNAMES_CC in region.rb line 84; fixture source_url read from tournaments.yml]

**Variant dispatch** (the `parse_table_tr` private method, line 1061): dispatches based on `header` array:
- `variant0`: `%w[Partie Begegnung Partien Erg.]`
- `result_with_frames`: `%w[Partie Begegnung Frames HB Erg.]`
- `result_with_parties`: `%w[Partie Begegnung Partien Ergebnis]`
- `result_with_party`: `%w[Partie Begegnung Erg.]`
- `result_with_party_variant`: `%w[Partie Frame Begegnung HB Erg.]`
- `result_with_party_variant2`: `["Partie", "Frame", "Begegnung", "Aufn.", "", "", "Erg."]`
- `variant2`/named: `%w[Partie Frame Begegnung Erg.]` (3-column variant)
- `variant3`: `%w[Partie Begegnung Planzeit]`
- `Variant4` (capital V): `%w[Partie Begegnung Pkt. Aufn. HS GD Erg.]` or `%w[Partie Begegnung Punkte Aufn. HS GD Erg.]`
- `variant5`: `["Partie", "Begegnung", "Pkt.", "Aufn.", "", "", "Erg."]`
- `variant6`: `%w[Partie Frame Begegnung Pkt. Aufn. HS GD Erg.]`
- `variant7`: `%w[Partie Begegnung Aufn. HS GD Erg.]` or `%w[Partie Begegnung Aufn. HS GD Ergebnis]`
- `variant8`: `%w[Partie Begegnung GD Erg.]`

**VCR strategy for scraping tests**: Record one cassette per tournament page set (4 interactions). Named descriptively: `tournament_scraping_nbv_2025.yml`. The VCR config's `allow_playback_repeats: true` handles repeated test runs.

**`opts` parameter values affecting behavior**:
- `opts[:tournament_doc]` — pre-parsed Nokogiri doc (skips 1st HTTP call; for unit testing without HTTP)
- `opts[:reload_game_results]` — destroys all games before re-scraping
- `opts[:reload_seedings]` — destroys all seedings before re-scraping

### Rankings Calculation (Claude's discretion — fits in existing or new file)

`calculate_and_cache_rankings` (lines 886–932):
- Only runs for local tournaments with discipline
- Reads from `PlayerRanking` (3 seasons)
- Writes `data['player_rankings']` as `{player_id => rank}` hash
- Calls `save!` at end — produces a PaperTrail version

### Google Calendar Reservation (Claude's discretion)

Cluster: `create_table_reservation`, `available_tables_with_heaters`, `required_tables_count`, `format_table_list`, `build_event_summary`, `calculate_start_time`, `calculate_end_time`, `create_google_calendar_event`.

Existing test file: `test/models/tournament_auto_reserve_test.rb` — check before writing any new calendar tests. May already cover the behavior.

---

## Reek Baseline (D-07 — COMPLETE)

**Status:** Saved to `.planning/phases/12-tournament-characterization/reek-baseline.txt`

**Summary**: 412 warnings. Top smells:
- `DataClump`: 30+ instances across `parse_table_tr` and variant methods (parameter groups like `[nbsp, points, tr]` passed to 12+ methods)
- `DuplicateMethodCall`: `tr.css("td")` called up to 9x per variant method
- `UtilityFunction`: variants 3, 5, 6, 7, 8 don't depend on instance state
- `LongMethod`: expected for 400-line scraping method

This is the baseline. Extraction must not increase the warning count.

---

## Existing Test Infrastructure Assessment

### Files to Reuse/Extend
| File | Status | Relevance |
|------|--------|-----------|
| `test/models/tournament_test.rb` | 51 lines, active | Leave as-is per D-02. Contains PaperTrail skip-lambda test. |
| `test/support/t04_tournament_test_helper.rb` | Active | `create_t04_tournament_with_seedings` — reuse for AASM tests needing seedings |
| `test/support/t06_tournament_test_helper.rb` | Active | Similar helper for T06 plan |
| `test/support/vcr_setup.rb` | Active | Already loaded via `Dir[...support/**/*.rb]` in test_helper |
| `test/snapshots/vcr/` | 7 cassettes (RegionCc only) | No tournament scraping cassettes exist — must record fresh |
| `test/fixtures/tournaments.yml` | 3 fixtures | `local` (id 50M+1), `imported` (id 1000), `scraped` (id 50M+2 with source_url) |

### Fixture Analysis
- `local` tournament: `state: "registration"` — note this is NOT an AASM state (states start at `new_tournament`). Fixture may need `state: "new_tournament"` for AASM tests. Check whether "registration" is accepted by AASM or causes errors. [VERIFIED: state column is a plain string; AASM reads it but does not validate on load]
- `imported` tournament (id 1000): global record — perfect for testing the `tournament_local` delegation path in CHAR-07
- `scraped` tournament (id 50M+2): has `source_url` set — useful for scraping setup context

### TournamentTestHelper Decision
The T04 and T06 helpers create full tournament setups for complex tests. For simpler characterization tests, direct `Tournament.create!` with explicit IDs (matching the MIN_ID boundary) is simpler. **Recommendation**: Create a lightweight `TournamentCharTestHelper` module in `test/support/` for fixture setup patterns specific to this phase (global vs local tournament construction, tournament_local creation).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP recording | Manual stub files | VCR cassettes | Already configured; handles all 4 scraping URLs automatically |
| Version counting | Custom diff tracking | `assert_difference "tournament.versions.count"` | Minitest built-in; works with PaperTrail |
| AASM state forcing | Direct `tournament.state = "..."` | `tournament.aasm.current_state = :state` or fixture `state:` column | Avoids triggering callbacks unintentionally when testing non-transition behavior |
| Private method testing | Extracting to public | `tournament.send(:method_name, args)` | Standard pattern used throughout existing tests |

---

## Common Pitfalls

### Pitfall A: `auto_upload_to_cc` is in the define_method loop but NOT in tournament_locals table
**What goes wrong:** The setter for `auto_upload_to_cc` on a global record calls `tol.update(auto_upload_to_cc: value)` on a `TournamentLocal` record that has no `auto_upload_to_cc` column. This will raise `ActiveModel::UnknownAttributeError` or silently be ignored depending on Rails config.
**How to avoid:** Test setter behavior for `auto_upload_to_cc` on a global record specifically. If it raises, this is a bug to document (not fix) in the characterization test.
**Confidence:** HIGH — confirmed by reading TournamentLocal schema annotation (no `auto_upload_to_cc` column present).

### Pitfall B: `skip_validation_on_save: true` means AASM transitions don't validate `data`
**What goes wrong:** Tests that fire AASM transitions and then check `tournament.valid?` will find that `validates_each :data` (which checks `table_ids`) was never run by the transition.
**How to avoid:** In `tournament_aasm_test.rb`, add explicit `assert tournament.valid?` after each transition. Separately test the `validates_each :data` validator on direct `save!` calls (not via AASM).
**Source:** PITFALLS.md Pitfall 3 [VERIFIED: `skip_validation_on_save: true` confirmed at line 271]

### Pitfall C: PaperTrail only active in test env when `carambus_api_url` is absent
**What goes wrong:** If a test somehow sets `Carambus.config.carambus_api_url`, PaperTrail deactivates mid-test and version assertions fail.
**How to avoid:** Do not modify `Carambus.config` in characterization tests. Assert `PaperTrail.enabled?` at the top of `tournament_papertrail_test.rb` as a sanity check.

### Pitfall D: `reset_tournament` uses `save` (not `save!`) on line 866
**What goes wrong:** If the save fails silently, `reset_tournament` leaves the record in a partially-reset state. Tests that call `reset_tmt_monitor!` and then assert on `tournament.state` may see stale state.
**How to avoid:** After any AASM transition that triggers `reset_tournament`, assert `tournament.reload.state == "new_tournament"` AND `tournament.reload.tournament_monitor.nil?`.

### Pitfall E: LocalProtector bypass is automatic in tests, but test creates need valid season association
**What goes wrong:** `Tournament.create!` requires `season:` (belongs_to :season — not optional). The `season` fixture `:current` must exist. `LocalProtectorTestOverride` is already prepended in `test_helper.rb`, so global-id tournaments can be saved.
**How to avoid:** Always pass `season: seasons(:current)` in `Tournament.create!` calls in characterization tests.

### Pitfall F: VCR cassettes must be recorded with `Net::HTTP.get` not `Version.http_get_with_ssl_bypass`
**What goes wrong:** `scrape_single_tournament_public` line 409 uses `Rails.env == 'development' ? Version.http_get_with_ssl_bypass(uri) : Net::HTTP.get(uri)`. In test environment, it uses `Net::HTTP.get` — VCR intercepts `Net::HTTP` via WebMock, so cassettes recorded correctly. But if a test accidentally sets `Rails.env` to something unexpected, the wrong HTTP method is used.
**How to avoid:** No action needed — test env uses `Net::HTTP.get` which VCR intercepts correctly.

---

## Architecture Patterns — Test File Design

### `tournament_aasm_test.rb`
```ruby
# frozen_string_literal: true

class TournamentAasmTest < ActiveSupport::TestCase
  fixtures :all
  use_transactional_tests = true   # no after_commit needed for AASM tests

  # Pattern: create local tournament (id >= MIN_ID) to avoid LocalProtector concerns
  # Use direct state column assignment for setup, bang methods for tested transitions

  test "initial state is new_tournament" do ...end
  test "finish_seeding transitions to tournament_seeding_finished" do ...end
  test "finish_seeding triggers calculate_and_cache_rankings after_enter" do ...end
  test "reset_tmt_monitor guard blocks reset when games present" do ...end
  test "reset_tmt_monitor guard allows reset when no local games" do ...end
  test "admin_can_reset_tournament? returns true with no current_user" do ...end
  test "reset_tournament destroys tournament_monitor" do ...end
  test "reset_tournament reorders seedings" do ...end
  test "validates_each data NOT called during AASM transition" do ...end
  test "validates_each data IS called during direct save!" do ...end
end
```

### `tournament_attributes_test.rb`
```ruby
# frozen_string_literal: true

class TournamentAttributesTest < ActiveSupport::TestCase
  fixtures :all

  # For global record tests, use tournaments(:imported) (id: 1000)
  # For local record tests, use tournaments(:local) (id: 50_000_001)
  # Test all 13 attributes; use representative subset for dual-path verification

  test "getter returns read_attribute value for local record" do ...end
  test "getter returns tournament_local value for global record with tournament_local" do ...end
  test "getter falls back to read_attribute for global record without tournament_local" do ...end
  test "setter calls write_attribute for new record" do ...end
  test "setter creates tournament_local for global record" do ...end
  test "setter updates existing tournament_local for global record" do ...end
  test "setter calls write_attribute for local record" do ...end
  # Special case: auto_upload_to_cc behavior on global record (possible missing column)
  test "auto_upload_to_cc setter behavior on global record" do ...end
end
```

### `tournament_papertrail_test.rb`
```ruby
# frozen_string_literal: true

class TournamentPapertrailTest < ActiveSupport::TestCase
  fixtures :all

  setup do
    assert PaperTrail.enabled?, "PaperTrail must be active in test env"
  end

  test "create! produces exactly 1 version" do
    assert_difference "PaperTrail::Version.count", 1 do
      Tournament.create!(title: "T", season: seasons(:current), organizer: regions(:nbv))
    end
  end

  test "update! with title change produces 1 version" do ...end
  test "update_columns skips PaperTrail" do ...end
  test "AASM transition produces 1 version (state column change)" do ...end
  test "tournament_local update via dynamic setter produces version on tournament_local NOT tournament" do ...end
  test "destroy produces 1 version" do ...end
  test "update with only sync_date change produces 0 versions" do ...end
end
```

### `tournament_scraping_test.rb`
```ruby
# frozen_string_literal: true

class TournamentScrapingTest < ActiveSupport::TestCase
  fixtures :all

  test "scrape_single_tournament_public returns early for non-Region organizer" do ...end
  test "scrape_single_tournament_public returns early on API server" do ...end

  test "scrape_single_tournament_public with VCR cassette creates seedings and games" do
    VCR.use_cassette("tournament_scraping_nbv_2025") do
      tournament = tournaments(:scraped)
      tournament.scrape_single_tournament_public
      assert tournament.seedings.any?
    end
  end

  # Variant dispatch tests — use pre-parsed Nokogiri docs (opts[:tournament_doc])
  # to avoid HTTP for variant-level tests
  test "variant0 parses 6-column result row" do ...end
  test "variant7 parses row with gd and hs" do ...end
end
```

---

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|------------------|-------|
| `PaperTrail.ignore` columns | Skip lambda on `saved_changes` | Current: skip only when ALL changes are ignorable |
| `has_paper_trail` in model | `has_paper_trail` in `LocalProtector` | Inherited — don't call it again in Tournament directly |
| Testing via `save` then `versions.reload` | `assert_difference "model.versions.count"` | Current pattern from existing tournament_test.rb |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `whiny_transitions` defaults to true for bang methods in current AASM version | AASM State Machine | If false, invalid transitions silently no-op instead of raising — tests that expect `AASM::InvalidTransition` won't fire |
| A2 | Both `LocalProtector#set_paper_trail_whodunnit` and `ApplicationRecord#set_paper_trail_whodunnit` run (callback ordering) | PaperTrail Configuration | If only one runs, whodunnit value differs from expected — low impact for characterization tests |
| A3 | `auto_upload_to_cc` is absent from `tournament_locals` schema | Dynamic Attributes | If column exists (hidden), setter works fine; the bug doesn't exist |
| A4 | Test env has `carambus_api_url` absent (so PaperTrail is active for Tournament) | PaperTrail Configuration | If present, PaperTrail inactive — all version count assertions wrong |

---

## Open Questions

1. **`auto_upload_to_cc` column in tournament_locals**
   - What we know: The define_method loop includes `auto_upload_to_cc` but the schema annotation on `TournamentLocal` does not show this column
   - What's unclear: Whether the column exists and the annotation is stale, or the column truly is absent
   - Recommendation: First test written for this attribute should assert `tol.respond_to?(:auto_upload_to_cc=)` and observe behavior

2. **Which ClubCloud URL to use for VCR recording**
   - What we know: The `scraped` fixture has `source_url: "https://nbv.clubcloud.de/sb_meisterschaft.php?p=20--2025-123-0--2-1-100000-"` but `SHORTNAMES_CC["NBV"]` maps to `"https://ndbv.de/"`
   - What's unclear: What `Region#public_cc_url_base` returns for the NBV fixture (depends on database column value, not constant)
   - Recommendation: During execution, read `regions(:nbv).public_cc_url_base` first to confirm the actual URL used by the scraper before recording

3. **`state: "registration"` in local fixture**
   - What we know: The `local` tournament fixture has `state: "registration"` which is not a defined AASM state
   - What's unclear: Whether AASM accepts any string in the state column (it likely reads the column value directly) or raises on first transition from this state
   - Recommendation: AASM tests should create fresh Tournament records with known states rather than relying on the `local` fixture

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| VCR gem | tournament_scraping_test.rb | Yes | 6.4.0 | — |
| WebMock | All tests (blocks HTTP) | Yes | bundled | — |
| reek CLI | D-07 baseline | Yes | 6.5.0 (system) | — |
| PaperTrail | tournament_papertrail_test.rb | Yes | bundled via LocalProtector | — |
| ClubCloud live URLs | VCR cassette recording | Yes (public sites) | — | Use `opts[:tournament_doc]` with fixture HTML |

**Note:** VCR cassette recording requires a live network connection to ClubCloud. Once recorded with `record: :once`, subsequent test runs are offline. The 7 existing RegionCc cassettes confirm this workflow is established.

---

## Validation Architecture

`nyquist_validation: false` in `.planning/config.json` — section skipped per config.

---

## Security Domain

This phase is test-only. No new endpoints, no user input handling, no authentication changes. No ASVS controls apply.

---

## Sources

### Primary (HIGH confidence)
- Direct read: `app/models/tournament.rb` (all 1775 lines across 6 reads) — AASM block, define_method loop, scraping pipeline, all private variants, Google Calendar methods
- Direct read: `app/models/local_protector.rb` — `has_paper_trail` configuration, skip lambda, `disallow_saving_global_records`
- Direct read: `app/models/tournament_local.rb` — schema annotation (confirms which columns exist)
- Direct read: `test/test_helper.rb` — LocalProtectorTestOverride, ApiProtectorTestOverride, VCR/WebMock setup
- Direct read: `test/support/vcr_setup.rb` — cassette library, hook, record mode, match options
- Direct read: `test/models/tournament_test.rb` — existing 51-line test, PaperTrail patterns
- Direct read: `test/fixtures/tournaments.yml` — fixture IDs, states, source_url
- Direct read: `.planning/research/PITFALLS.md` — pitfalls 2, 3, 7, 8, 9 directly relevant
- Direct read: `.planning/research/FEATURES.md` — cluster map, extraction candidates
- Direct read: `test/support/t04_tournament_test_helper.rb` and `t06_tournament_test_helper.rb`
- Bash: `reek tournament.rb` — 412 warnings, baseline saved to `reek-baseline.txt`

### Secondary (MEDIUM confidence)
- Direct read: `app/models/application_record.rb` — `set_paper_trail_whodunnit`, `local_server?`
- Direct read: `app/models/region.rb` lines 69–87 — `SHORTNAMES_CC` map for ClubCloud URLs

---

## Metadata

**Confidence breakdown:**
- AASM mapping: HIGH — read directly from source, all 8 events and guards verified
- Dynamic attributes: HIGH — 13 attributes enumerated directly; `auto_upload_to_cc` schema gap flagged
- PaperTrail: HIGH — skip lambda read; activation condition verified
- Scraping pipeline: HIGH — 4 HTTP calls identified; 14 variant branches mapped
- VCR cassette URL: MEDIUM — URL pattern known but actual `public_cc_url_base` column value unconfirmed until execution

**Research date:** 2026-04-10
**Valid until:** 2026-05-10 (stable codebase, no external deps)
**Reek baseline:** `.planning/phases/12-tournament-characterization/reek-baseline.txt` (412 warnings, reek 6.5.0)
