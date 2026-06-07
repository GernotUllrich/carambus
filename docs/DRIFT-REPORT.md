# Drift-Report: Dokumentation vs. Code

> Automatisch erzeugt durch den Code-Docs-Verifier (graphify-Pilot + Verifier-Fan-out).
> Scope dieses Laufs: **Batch 1 — `docs/developers/` + `docs/reference/`** (26 eindeutige Inhalte, de/en zusammengefasst).
> Jeder Befund ist gegen die echte Quelle mit `Datei:Zeile` belegt.
> Nicht in diesem Batch: `docs/managers|players|administrators|decision-makers` (nutzerorientiert), `archive/obsolete/changelog` (historisch).

## Zusammenfassung

- **71 handlungsrelevante Befunde** (50 DRIFT = Widerspruch, 21 GAP = Luecke)
- Schweregrad: **26 hoch**, 29 mittel, 16 niedrig
- **79+ Aussagen verifiziert korrekt** (MATCH) — die Docs sind strukturell ueberwiegend solide

**DRIFT** = Doc behauptet X, Code macht Y. **GAP** = Struktur existiert im Code, Doc laesst sie weg (oder Doc nennt totes Symbol).

## 🔴 Hoch — irrefuehrend / gebrochene Anweisungen (26)

### `docs/developers/clubcloud-mcp-server.de.md`

- **[DRIFT]** The MCP server has 11 tool classes (10 Read-Tools + 1 Write-Tool cc_finalize_teilnehmerliste).
  - Doc-Stelle: Sec 1 'Die vier Schichten' table + Sec 2 diagram 'Tools::* (11 Klassen)' + Sec 4 file layout + Sec 8 '11 Tool-Namen'
  - Code: `lib/mcp_server/tools/ contains 22 files declaring tool_name (grep tool_name -> 22). New write/list tools absent from doc: cc_register_for_tournament (register_for_tournament.rb:36), cc_unregister_for_tournament (unregister_for_tournament.rb:33), cc_assign_player_to_teilnehmerliste (assign_player_to_teilnehmerliste.rb:31), cc_remove_from_teilnehmerliste (remove_from_teilnehmerliste.rb:23), cc_update_tournament_deadline (update_tournament_deadline.rb:34), cc_list_open_tournaments, cc_list_clubs_by_discipline, cc_list_players_by_name, cc_list_players_by_club_and_discipline, cc_check_player_discipline_experience, cc_lookup_meldeliste_for_tournament`
  - Doc is frozen at 'Phase 40' (11 tools). Code has roughly doubled to 22 tools, including 4+ new WRITE tools that the doc explicitly says are only 'Phase 40.1 Roadmap / TBD' (Sec 12). cc_register_for_tournament/cc_unregister_for_tournament etc. are fully implemented, not future work.
  - ➜ **Fix:** Regenerate the tool inventory and the four-layer table from the actual lib/mcp_server/tools/ directory; move all implemented write-tools out of the Phase 40.1 Roadmap section.

### `docs/developers/clubcloud-upload.en.md`

- **[DRIFT]** The auto-upload call (Setting.upload_game_to_cc) lives in lib/tournament_monitor_state.rb#finalize_game_result.
  - Doc-Stelle: Sec 'Upload Logic' — 'The upload occurs in lib/tournament_monitor_state.rb after game completion: def finalize_game_result(table_monitor)'
  - Code: `app/services/tournament_monitor/result_processor.rb:294 def finalize_game_result(table_monitor) ... :315 result = Setting.upload_game_to_cc(table_monitor). grep of lib/tournament_monitor_state.rb for finalize_game_result/upload_game_to_cc returns nothing.`
  - The upload logic was extracted into the result_processor service; lib/tournament_monitor_state.rb no longer contains finalize_game_result. The log-message strings ([TournamentMonitorState] DRY RUN/skipped/successful) and the guard 'tournament.tournament_cc.present? && tournament.auto_upload_to_cc?' match the new location exactly.
  - ➜ **Fix:** Change the file path to app/services/tournament_monitor/result_processor.rb (note the log prefix is still '[TournamentMonitorState]').

- **[DRIFT]** RegionCc holds credentials in region_cc.login_username and region_cc.login_password.
  - Doc-Stelle: Sec 'Prerequisites > RegionCc Configuration' and 'Troubleshooting > ClubCloud login failed'
  - Code: `db/schema.rb create_table "region_ccs" columns are username (string) and userpw (string) — there is no login_username/login_password column. grep login_username/login_password across app/ and lib/ returns zero hits.`
  - The documented attribute names do not exist; the actual columns are username and userpw. Any reader following the troubleshooting steps (region_cc.login_username) gets a NoMethodError.
  - ➜ **Fix:** Replace login_username/login_password with username/userpw in the prerequisites and troubleshooting sections.

### `docs/developers/debugging/websocket-logging.de.md`

- **[DRIFT]** Manual change required in app/models/table_monitor.rb: insert logging lines after line 71 'after_update_commit lambda {'; uses skip_update_callbacks flag and previous_changes.inspect.
  - Doc-Stelle: lines 5-46
  - Code: `app/models/table_monitor.rb:85 — `after_update_commit lambda {` (not at/after line 71; line 73 is `before_save :enforce_protocol_final_panel_at_set_over`). Line 87 uses `if suppress_broadcast` (not skip_update_callbacks). Line 104 logs `@collected_changes.inspect` (not previous_changes.inspect).`
  - The doc presents this as a patch still to be applied manually, but the logging is ALREADY in the code, AND the implementation diverged: the suppression flag is named `suppress_broadcast` (attr_writer at line 79), not `skip_update_callbacks`; the logged changeset is `@collected_changes`/`@collected_data_changes`, not `previous_changes`. A developer following these instructions would search for the wrong line number and wrong identifiers.
  - ➜ **Fix:** Rewrite the doc to reflect that logging is already present, rename skip_update_callbacks->suppress_broadcast and previous_changes->@collected_changes, and remove the 'insert after line 71' instruction.

### `docs/developers/developer-guide.en.md`

- **[DRIFT]** RSpec: Unit and integration tests
  - Doc-Stelle: Development Tools > Testing (line 206)
  - Code: `Gemfile has no rspec gem (grep gem rspec -> none); test/ uses Minitest (test/concerns, test/models, etc.); CLAUDE.md: 'Uses Minitest (not RSpec despite .cursorrules mentioning rspec)'`
  - The doc lists RSpec as the test framework, but the project uses Minitest. The empty spec/ directory (only spec/fixtures and spec/services, no rspec config) reinforces that RSpec is not the actual test stack. The Testing section's commands (rails test, rails test:system) at lines 396-404 are correct Minitest invocations, contradicting the RSpec claim.
  - ➜ **Fix:** Change 'RSpec' to 'Minitest' in the Development Tools list.

- **[GAP]** cp config/database.yml.example config/database.yml
  - Doc-Stelle: Getting Started > Installation, step 3 (line 170)
  - Code: `ls config/database.yml.example -> No such file or directory; only config/database.yml exists`
  - The setup command copies from config/database.yml.example, but that file does not exist in the repo. A new developer following this instruction gets 'No such file or directory'.
  - ➜ **Fix:** Either commit a config/database.yml.example template, or change the instruction to reflect that config/database.yml already exists (or is generated).

- **[GAP]** cp config/application.yml.example config/application.yml; Edit application.yml with your configuration
  - Doc-Stelle: Getting Started > Installation, step 4 (lines 186-188)
  - Code: `ls config/application.yml / config/application.yml.example -> No such file or directory; app config lives in config/carambus.yml (CLAUDE.md: 'Custom config in config/carambus.yml accessed via Carambus.config')`
  - Neither config/application.yml nor config/application.yml.example exist. The app's custom configuration is config/carambus.yml. The 'Application Configuration' YAML block at lines 474-481 ('config/application.yml' with defaults:/database_url/redis_url) describes a file that does not exist.
  - ➜ **Fix:** Replace references to config/application.yml with config/carambus.yml and document the actual config keys, or remove the application.yml steps.

### `docs/developers/index.en.md`

- **[GAP]** Link '[YouTube Streaming Development Setup](streaming-dev-setup.md)' references an existing doc.
  - Doc-Stelle: line 353
  - Code: `docs/developers/ — only `streaming-dev-setup.de.md` exists; `streaming-dev-setup.en.md` is absent (ls: No such file or directory).`
  - mkdocs.yml configures the i18n plugin with `docs_structure: suffix` (line 48-49), so on the English page index.en.md a bare `streaming-dev-setup.md` link resolves to `streaming-dev-setup.en.md` — which does not exist (only the German variant does). This produces a broken link in the EN build, unlike the other suffix-resolved links which have both variants.
  - ➜ **Fix:** Create streaming-dev-setup.en.md (or an EN stub), or drop the EN-page link until the English translation exists.

### `docs/developers/pool-scoreboard-changelog.en.md`

- **[DRIFT]** Added balls_left() method to app/javascript/controllers/table_monitor_controller.js that calls this.stimulate('TableMonitor#balls_left', this.element)
  - Doc-Stelle: JavaScript Changes (lines 188-204)
  - Code: `app/javascript/controllers/table_monitor_controller.js — grep 'balls_left' returns 0 matches; the reflex exists at app/reflexes/table_monitor_reflex.rb:937 (def balls_left) and model at app/models/table_monitor.rb:909`
  - The changelog's headline JS change does NOT exist in the named file. There is no balls_left() method (and no 'balls' reference) in table_monitor_controller.js. The reflex action TableMonitor#balls_left exists, but the documented Stimulus wrapper that the changelog says was 'added' is absent — either never committed to this branch or later removed. This is the changelog's clearest unlanded claim.
  - ➜ **Fix:** Verify how balls click is dispatched now; correct or remove the JS-change section.

### `docs/developers/services/region-cc.en.md`

- **[DRIFT]** All sync operations are dispatched via `RegionCc.synchronize(opts)` on the model
  - Doc-Stelle: line 3
  - Code: `app/models/region_cc.rb:210,244,285 — def synchronize_league_structure(opts = {}); def synchronize_league_plan_structure(opts = {}); def synchronize_tournament_structure(opts = {})`
  - There is no `synchronize` method (instance or class) on RegionCc. grep for 'def synchronize' returns only three domain-specific instance methods: synchronize_league_structure, synchronize_league_plan_structure, synchronize_tournament_structure. The doc's single unified dispatch entry point `RegionCc.synchronize(opts)` does not exist in the code.
  - ➜ **Fix:** Replace the claim with the actual entry points (the three synchronize_*_structure instance methods), or describe that callers invoke the individual `RegionCc::*Syncer.call(...)` services directly, which is the pattern the rest of the doc documents.

- **[DRIFT]** `RegionCc::MetadataSyncer.call(... operation: :sync_metadata ...)` — operation key is :sync_metadata
  - Doc-Stelle: line 87
  - Code: `app/services/region_cc/metadata_syncer.rb:28-30 — when :sync_category_ccs then sync_category_ccs; when :sync_group_ccs then sync_group_ccs; when :sync_discipline_ccs then sync_discipline_ccs`
  - MetadataSyncer's case dispatch accepts :sync_category_ccs, :sync_group_ccs, :sync_discipline_ccs. There is no :sync_metadata operation; calling with operation: :sync_metadata would hit the else branch and raise ArgumentError 'Unknown operation'. The doc's example is non-functional.
  - ➜ **Fix:** Update the MetadataSyncer example to list the three real operations (:sync_category_ccs, :sync_group_ccs, :sync_discipline_ccs).

### `docs/developers/services/tournament-monitor.en.md`

- **[DRIFT]** distribute_to_group / distribute_with_sizes return Hash { Integer => Array<Integer> }, i.e. keys are the integer group number (group_no => [player_ids]).
  - Doc-Stelle: PlayerGroupDistributor — Output (lines 23, 27, 40)
  - Code: `app/services/tournament_monitor/player_group_distributor.rb:60-61 groups["group#{group_no}"] = []; :103 groups["group#{group_no}"] << player_id; :111 groups["group#{group_no}"]`
  - The returned Hash is keyed by STRING keys of the form "group1", "group2", ... not by Integer group numbers. The consumer RankingResolver#group_rank reads groups["group#{group_no}"] (ranking_resolver.rb:111), confirming string keys. A developer following the doc would index the result with an Integer and get nil.
  - ➜ **Fix:** Change the Output rows to: Hash { String => Array<Integer> } with keys like "group1", "group2", …. Update the table header in the namespace overview (line 40) and the inline comments on lines 23/27 accordingly.

- **[GAP]** "fin.w" is a valid rule_str meaning 'Winner of the final (KO bracket reference)'.
  - Doc-Stelle: RankingResolver — rule_str DSL examples table (line 61)
  - Code: `app/services/tournament_monitor/ranking_resolver.rb:46 match(/^(?:(?:fg|g)(\d+)|sl|rule|64f|32f|16f|8f|vf|hf|af|qf|fin|p<...>)(\d+)?\.rk(\d+)$/); :77 fin/qf/hf/etc. only accept a \.rk(\d+) suffix`
  - The KO-ranking parser only recognizes a '.rk<n>' suffix (and the '.rk-rand-a-b' / '(...).rk<n>' composite forms). There is no '.w' (winner) token, and no 'winner'/'loser' handling anywhere in ranking_resolver.rb. A string like "fin.w" fails every regex branch and player_id_from_ranking returns nil. The doc invents a DSL form the code cannot parse.
  - ➜ **Fix:** Remove the "fin.w" row, or replace it with a real KO form such as "fin1.rk1" (rank 1 of the final game) to express 'winner of the final'.

### `docs/developers/streaming-architecture.en.md`

- **[DRIFT]** stream_configurations has a location reference / belongs_to :location, and t.references :location null:false foreign_key:true
  - Doc-Stelle: Section 1.1 (lines 98-99, 155) + diagram line 28
  - Code: `app/models/stream_configuration.rb:45,48-49 — self.ignored_columns = ["location_id"]; belongs_to :table; has_one :location, through: :table`
  - location_id was removed (db/migrate/20251226091838_remove_location_id_from_stream_configurations.rb). The model now has NO belongs_to :location and NO location_id column (schema annotation lines 5-37 confirm only table_id). Location is reached indirectly via has_one :location, through: :table. The doc's migration snippet, schema, and 'belongs_to :location' model snippet are all stale.
  - ➜ **Fix:** Remove the location reference from the migration/schema/model snippets; document 'has_one :location, through: :table' and the ignored_columns shim.

- **[GAP]** StreamConfiguration only encrypts youtube_stream_key and only supports YouTube RTMP; rtmp_url generates rtmp://a.rtmp.youtube.com/live2/:stream_key
  - Doc-Stelle: Section 1.2 model snippet (lines 150-183), Security section (904-913)
  - Code: `app/models/stream_configuration.rb:52-59,198-209 — encrypts :custom_rtmp_key; validates :stream_destination inclusion %w[youtube local custom]; rtmp_url case dispatches youtube_rtmp_url/local_rtmp_url/custom_rtmp_url_complete`
  - The code grew a stream_destination concept (youtube|local|custom) with separate local RTMP (rtmp://IP:1935/stream/tableN) and custom RTMP destinations, plus a second encrypted attribute custom_rtmp_key. The doc treats YouTube as the only destination and documents only one encrypted field.
  - ➜ **Fix:** Document stream_destination, the local/custom RTMP paths, custom_rtmp_url/custom_rtmp_key, and local_rtmp_server_ip; update rtmp_url description.

- **[GAP]** deploy_all action deploys all streams (doc lists it as a valid custom action)
  - Doc-Stelle: Section 1.3 deploy_all (line 203) — implicit
  - Code: `app/controllers/admin/stream_configurations_controller.rb:126-128 — configs.each { |config| StreamDeployJob.perform_later(config.id) }; grep shows NO app/jobs/stream_deploy_job.rb and no StreamDeployJob class anywhere`
  - deploy_all enqueues StreamDeployJob, which does not exist in the codebase (only StreamControlJob and StreamHealthJob exist). The doc documents deploy_all as functional but never mentions StreamDeployJob; the action would raise NameError at runtime. This is a latent code bug the doc papers over.
  - ➜ **Fix:** Either implement StreamDeployJob or fix deploy_all to use StreamControlJob; doc should reflect the real deploy path.

### `docs/developers/test-implementation-summary.de.md`

- **[GAP]** References docs contributors should read: QUICKSTART_TESTS.md, TESTING.md, INSTALL_TESTS.md, TEST_SETUP_SUMMARY.md, TEST_ERFOLG.md.
  - Doc-Stelle: lines 84-95, 324-336
  - Code: `repo root — QUICKSTART_TESTS.md, TESTING.md, INSTALL_TESTS.md, TEST_SETUP_SUMMARY.md, TEST_ERFOLG.md all MISSING (test/README.md, test/ARCHITECTURE.md, test/TEST_STRUCTURE.md, test/snapshots/README.md, docs/developers/testing-strategy.de.md DO exist).`
  - Five of the ten documentation files the summary directs contributors to (including the headline 'QUICKSTART_TESTS.md - In 3 Befehlen zu laufenden Tests' and 'TESTING.md - Quick Start Guide') do not exist anywhere in the repo. The 'Getting Started' contributor path in the doc (QUICKSTART_TESTS.md, TESTING.md) is entirely broken.
  - ➜ **Fix:** Either restore/create these five files or update the doc's references to the actually-present docs (test/README.md, testing-strategy.de.md).

### `docs/developers/tournament-architecture-overview.en.md`

- **[DRIFT]** Inspect TournamentMonitor::PlayerGroupDistributor#do_placement to step through how the next Game is actively scheduled
  - Doc-Stelle: Cheatsheet step 3 (line 35)
  - Code: `grep 'def do_placement' -> app/services/tournament_monitor/table_populator.rb:847; PlayerGroupDistributor (player_group_distributor.rb) defines only self.distribute_to_group (57) and self.distribute_with_sizes (115), no do_placement`
  - do_placement is defined in TournamentMonitor::TablePopulator, not PlayerGroupDistributor. A developer following this cheatsheet step to debug game scheduling would open the wrong file and not find the method.
  - ➜ **Fix:** Change the reference to TournamentMonitor::TablePopulator#do_placement.

### `docs/developers/tournament-duplicate-handling.en.md`

- **[DRIFT]** The duplicate-handling system runs automatically via `rake scrape:tournaments_optimized`.
  - Doc-Stelle: lines 44-48 (Automatic Handling)
  - Code: `lib/tasks/scrape.rake:80 — `task scrape_tournaments_optimized: :environment do``
  - There is no rake task named `scrape:tournaments_optimized`. The real task is `scrape:scrape_tournaments_optimized`. A user copy-pasting the documented command gets 'Don't know how to build task'.
  - ➜ **Fix:** Change the doc to `rake scrape:scrape_tournaments_optimized` (or `rake scrape:daily_update`/`scrape:optimized_daily_update`, which also reach the path).

- **[DRIFT]** `Region#scrape_tournaments_optimized` now groups tournaments by name before processing, detects duplicates and applies selection logic, marking abandoned cc_ids.
  - Doc-Stelle: lines 86-91 (Modified Methods — Region#scrape_tournaments_optimized)
  - Code: `app/models/region.rb:529-539 — duplicate detection is NOT name-grouping; it does `existing_tc_for_tournament = TournamentCc.joins(:tournament).where(tournaments: {title: name, ...}).where.not(cc_id: cc_id).first` then `AbandonedTournamentCcSimple.mark_abandoned!(old_cc_id, ...)`. No `group_by` over a name dictionary occurs in the scraping path.`
  - The actual mechanism is incremental per-row: while iterating scraped tournament rows, if a TournamentCc already exists for the same title in the season with a DIFFERENT cc_id, the OLD one is abandoned and the current (new) cc_id is kept. There is no up-front grouping-by-name pass and no analysis of a duplicate set in the scraping path. Method also takes args `(season, opts)`, not the parameterless form implied.
  - ➜ **Fix:** Rewrite this section to describe the actual incremental detection (existing TournamentCc with same title + different cc_id → abandon old, keep new) and the `(season, opts)` signature.

- **[DRIFT]** Selection prioritizes in order: 1) Has games, 2) Has seedings, 3) No seedings/games, 4) Highest cc_id.
  - Doc-Stelle: lines 14-19 (Selection Logic)
  - Code: `app/models/region.rb:530-539 — the scraping path keeps the CURRENTLY-SCRAPED cc_id and abandons the previously-stored one unconditionally; no games/seedings/highest-cc_id comparison is performed.`
  - This priority ladder (has games > has seedings > highest cc_id) is not implemented in the live scraping dedup. The only place games/seedings are examined is the read-only diagnostic `AbandonedTournamentCc.analyze_duplicates` (app/models/abandoned_tournament_cc.rb:88-137 via `region.check_tournament_status`), which merely PRINTS has_seedings/has_games and never selects or abandons. The documented selection logic does not drive abandonment anywhere.
  - ➜ **Fix:** Either remove the selection-logic ladder or relabel it explicitly as a not-yet-implemented design goal; document the actual 'keep current scraped cc_id, abandon prior' behavior.

- **[DRIFT]** Abandoned cc_ids are stored in `abandoned_tournament_ccs` via the `AbandonedTournamentCc` model with fields region_shortname/season_name/tournament_name/reason/replaced_by_cc_id/replaced_by_tournament_id, and `mark_abandoned!`/`is_abandoned?` drive the scraping skip.
  - Doc-Stelle: lines 21-24 (Abandonment Tracking) + 26-40 (Database Schema) + 96-100 (model methods)
  - Code: `app/models/region.rb:508 `AbandonedTournamentCcSimple.is_abandoned?(cc_id, region_cc.context)` and region.rb:538 `AbandonedTournamentCcSimple.mark_abandoned!(old_cc_id, region_cc.context)` — the SCRAPING path uses AbandonedTournamentCcSimple (app/models/abandoned_tournament_cc_simple.rb), a table with only cc_id/context/abandoned_at.`
  - Two distinct models exist. The rich `AbandonedTournamentCc` (with reason/replaced_by/region_shortname/season_name/tournament_name, table `abandoned_tournament_ccs`) is documented, but the actual scrape-time skip/mark uses `AbandonedTournamentCcSimple` (table `abandoned_tournament_cc_simples`, migration 20250712160000), whose `mark_abandoned!(cc_id, context)` takes only two args and stores no name/season/reason/replacement. So the 'full audit trail with reasons' benefit (doc lines 113-115) does not apply to the records the scraper actually writes.
  - ➜ **Fix:** Document BOTH models and their roles: AbandonedTournamentCcSimple = the live scrape skip-list (cc_id+context only); AbandonedTournamentCc = the manual/diagnostic rich model used by the rake tasks. Clarify that the audit-trail fields only exist on the manually-populated model.

- **[GAP]** New private methods `process_single_tournament` and `process_duplicate_tournaments` handle individual tournaments and duplicate groups.
  - Doc-Stelle: lines 92-95 (New Private Methods)
  - Code: `grep -rn 'def process_single_tournament|def process_duplicate_tournaments' app/ lib/ → no matches.`
  - Neither method exists anywhere in the codebase. The doc names methods that were never implemented (or have been removed). The actual per-row processing is inline within Region#scrape_tournaments_optimized.
  - ➜ **Fix:** Remove the 'New Private Methods' subsection; it describes nonexistent code.

### `docs/reference/api.en.md`

- **[DRIFT]** POST /tournaments/{id}/generate_game_plan endpoint generates a tournament game plan.
  - Doc-Stelle: api.en.md:259-262 (Generate Game Plan)
  - Code: `config/routes.rb:338-363 — tournaments member block lists order_by_ranking_or_handicap, select_modus, start, reset, finalize_modus, tournament_monitor, reload_from_cc, finish_seeding, etc. — NO generate_game_plan. grep 'generate_game_plan' across app/ and config/ returns nothing.`
  - No generate_game_plan route exists anywhere in the codebase. The documented endpoint (and the JS example api.tournaments.generateGamePlan in the workflow section, api.en.md:687) is non-existent.
  - ➜ **Fix:** Remove the Generate Game Plan endpoint and the generateGamePlan workflow step, or document the actual game-plan-related actions (e.g. select_modus / finalize_modus).

- **[DRIFT]** REST CRUD endpoints: POST /tournaments, PATCH /tournaments/{id}, DELETE /tournaments/{id}, and list/get for players and parties returning JSON:API-style {data:{type,attributes,relationships}} payloads.
  - Doc-Stelle: api.en.md:135-245, 264-335 (List/Create/Update/Delete Tournaments, Players, Parties)
  - Code: `config/routes.rb:338 'resources :tournaments do' has full REST but the canonical public top-level resource is config/routes.rb:15 'resources :tournaments, only: %i[index show]'. Controllers render HTML/Turbo views, not the documented JSON:API envelope. No serializer producing {data:{id,type,attributes,relationships}} exists.`
  - The entire 'Response Format' / 'Core Endpoints' section describes a JSON:API contract (data/type/attributes/relationships, meta.total_count/total_pages) that the Rails app does not implement — these are scaffolded/HTML resources, and the public tournaments route is index/show only. The documented JSON shapes are aspirational, not real.
  - ➜ **Fix:** Either mark the JSON:API contract as a future/planned design, or rewrite to reflect that these are server-rendered HTML/Turbo resources. Do not present unimplemented JSON envelopes as the API contract.

- **[GAP]** POST /api/sync/ba/players, /api/sync/ba/tournaments, /api/sync/cc/competitions, /api/sync/cc/results sync endpoints exist.
  - Doc-Stelle: api.en.md:514-524 (Data Synchronization API)
  - Code: `config/routes.rb:56-160 namespace :api defines only ai_search, ai_docs, players#autocomplete, locations#autocomplete, tournament_ccs#link_registration_list, and external_tournament/* routes. grep 'sync' in routes.rb shows no /api/sync/* routes; sync happens via rake tasks / scraping, not HTTP endpoints.`
  - None of the four documented /api/sync/* endpoints exist. Synchronization is performed by scrapers/rake tasks (see CLAUDE.md scraping architecture), not REST endpoints.
  - ➜ **Fix:** Remove the Data Synchronization API section or replace it with the actual mechanism (scraper services / scheduled rake tasks).

## 🟠 Mittel — veraltete Details (29)

### `docs/developers/clubcloud-mcp-server.de.md`

- **[DRIFT]** ApiSurface exposes 15 cc://api/{action} resources with a 15-entry ALLOWLIST.
  - Doc-Stelle: Sec 4 file layout (resources/api_surface.rb '15 ALLOWLIST entries') + Sec 1 'API-Surface (curated) | 15 Resources' + Sec 7.4
  - Code: `lib/mcp_server/resources/api_surface.rb:32 comment 'Manuelle ALLOWLIST mit exakt 26 Entries' and counted ALLOWLIST = 26 entries (awk count = 26).`
  - The ALLOWLIST grew from 15 to 26 (the code comment at line 53 documents the 25->26 growth via D-08-01). Doc still says 15.
  - ➜ **Fix:** Update the count to 26 in the layer table and file-layout block.

- **[DRIFT]** WorkflowScenarios whitelists 3 scenario slugs.
  - Doc-Stelle: Sec 4 file layout 'workflow_scenarios.rb # cc://workflow/scenarios/* (3 Slugs whitelisted)' + Sec 1 'Workflow-Doku (DE) | 5 Resources'
  - Code: `lib/mcp_server/resources/workflow_scenarios.rb SCENARIOS has 8 slugs: teilnehmerliste-finalisieren (l.25), player-anlegen (l.26), endrangliste-eintragen (l.27), anmeldung-aus-email (l.28), turnier-status-und-anmelden (l.33), meldeliste-finalisieren (l.38), sportwart-tagesablauf-vor-turnier (l.43), akkreditierung-am-turniertag (l.48).`
  - Doc claims 3 whitelisted slugs / 5 workflow resources; code has 8 scenario slugs plus 2 meta keys (roles, glossary) = 10 workflow resources.
  - ➜ **Fix:** Update SCENARIOS slug count to 8 and the workflow-resource total.

- **[GAP]** The file layout block enumerates the lib/mcp_server/ source files (server.rb, cc_session.rb, transport/boot.rb, tools/, resources/) with no other top-level lib files.
  - Doc-Stelle: Sec 4 file layout (lib/mcp_server/) — 'Gesamt: 30 Source-Files'
  - Code: `lib/mcp_server/ also contains audit_trail.rb, role_tool_map.rb, tool_registry.rb (ls lib/mcp_server/), and test/mcp_server/ adds audit_trail_test.rb, role_tool_map_test.rb, tool_registry_test.rb, scenarios/ — none mentioned in the doc.`
  - Three production lib files (audit_trail.rb, role_tool_map.rb, tool_registry.rb) and their tests were added after the doc was written and are entirely undocumented. tool_registry.rb in particular changes the registration story the doc describes as pure constant-enumeration auto-registry.
  - ➜ **Fix:** Add audit_trail / role_tool_map / tool_registry to the file layout and Reference Manual; verify whether tool_registry.rb supersedes the 'Auto-Registry via constant enumeration' description in Sec 2.

### `docs/developers/database-partitioning.en.md`

- **[DRIFT]** The Version for_region scope is: where("region_id IS NULL OR region_id = ?", region_id).
  - Doc-Stelle: Sec 'Versions-Scope' — scope :for_region, ->(region_id) { where("region_id IS NULL OR region_id = ?", region_id) }
  - Code: `app/models/version.rb:33-35 scope :for_region, ->(region_id) { where("region_id IS NULL OR region_id = ? OR global_context = TRUE", region_id) }`
  - The actual scope has a third clause 'OR global_context = TRUE' that the doc omits. This is material because the whole doc is about how global_context routes data to all servers — the scope as documented would not include global_context rows.
  - ➜ **Fix:** Add the 'OR global_context = TRUE' clause to the documented scope.

- **[DRIFT]** 13 models include RegionTaggable, including PartyGame and Location.
  - Doc-Stelle: Sec 'Modelle mit RegionTaggable' — lists Region, Club, Tournament, League, Party, Location, LeagueTeam, Game, PartyGame, GameParticipation, Player, SeasonParticipation, Seeding
  - Code: `grep 'include RegionTaggable' app/models/*.rb yields: club, club_location, game, game_participation, game_plan, league, league_team, location, party, party_game, player, region, season_participation, seeding, tournament (15 models). Missing from doc: ClubLocation, GamePlan, Table.`
  - Doc lists 13 includers; code has 15. Doc omits ClubLocation, GamePlan, and Table. (Note: the model is 'Table' the carom table, picked up via grep 'include RegionTaggable' app/models/table.rb.) Doc's listed models all genuinely include the concern.
  - ➜ **Fix:** Add ClubLocation, GamePlan, Table to the includers list (verify Table is intended).

### `docs/developers/debugging/websocket-logging.de.md`

- **[DRIFT]** Callback enqueues jobs via `TableMonitorJob.perform_later(self, "table_scores")` etc., and contains a line `TableMonitorJob.perform_later(self, "")` (line 88) with empty string that 'should maybe be removed'.
  - Doc-Stelle: lines 30-40, 46
  - Code: `app/models/table_monitor.rb:121 — `TableMonitorJob.perform_later(id, "table_scores")` (passes `id`, not `self`); no `TableMonitorJob.perform_later(self, "")` empty-string call exists in the callback.`
  - Current code passes the record `id` to perform_later, not `self`. The empty-string enqueue the doc flags (and asks whether to remove) no longer exists; the open question in the doc is stale. The teaser-branch logic was also restructured (now an elsif on @collected_changes rather than a plain else).
  - ➜ **Fix:** Update code snippets to pass `id`, remove the obsolete empty-string-arg discussion, and reflect the current teaser/elsif branch structure.

### `docs/developers/developer-guide.en.md`

- **[DRIFT]** class Seeding includes SourceHandler (include SourceHandler) and belongs_to :player, optional: true
  - Doc-Stelle: Database Design > Seeding Model code block (lines 251-258)
  - Code: `app/models/seeding.rb:24-37 — include LocalProtector; include RegionTaggable; include Searchable; include AASM; belongs_to :player (NO optional, NO SourceHandler)`
  - The doc's Seeding code block shows 'include SourceHandler' and 'belongs_to :player, optional: true'. Actual Seeding does NOT include SourceHandler (only Party does, party.rb:49) and player is a required belongs_to. The doc also omits the real includes Searchable and AASM.
  - ➜ **Fix:** Update the Seeding example to match: remove SourceHandler, remove 'optional: true' from player, add Searchable/AASM if listing includes.

- **[DRIFT]** rake scenario:deploy[scenario_name,target_environment] (two args); link to scenario-management.md
  - Doc-Stelle: Deployment > Quick Start (lines 435-440); Additional Resources (line 534)
  - Code: `lib/tasks/scenarios.rake:115 — task :deploy, [:scenario_name] => :environment; usage string line 119: 'Usage: rake scenario:deploy[scenario_name]' (single arg only)`
  - The scenario:deploy rake task accepts only one parameter [:scenario_name]. The doc's example passes a second argument target_environment ('carambus_location_5101,production') which the task ignores. Separately the link target scenario-management.md does not exist (files are scenario-management.en.md / .de.md).
  - ➜ **Fix:** Drop the second argument from the deploy example, and fix the doc link to scenario-management.en.md.

- **[GAP]** Links to database-setup.md, scoreboard-autostart.md, database-design.md, tournament-management.md, installation-overview.md, developer-guide.md#operations
  - Doc-Stelle: Database Setup / Key Features / Additional Resources (many relative links)
  - Code: `find docs -name 'database-setup*' -> database-setup.en.md, database-setup.de.md (no bare .md); same pattern for all others; docs/developers/developer-guide.md (bare) does not exist (only .en.md/.de.md)`
  - All cross-doc links use bare '.md' filenames, but every target file in the repo uses a language suffix (.en.md/.de.md). The bare-named files do not exist, so these links are broken. Includes the self-reference at line 455 to developer-guide.md#operations (also has no '#operations' anchor in this doc).
  - ➜ **Fix:** Update all relative doc links to the .en.md (or locale-appropriate) filenames, and remove or fix the nonexistent #operations anchor.

### `docs/developers/index.en.md`

- **[GAP]** Links '[Developer Guide - Frontend](developer-guide.en.md#frontend)' (twice) point to a Frontend section anchor.
  - Doc-Stelle: lines 138, 89
  - Code: `docs/developers/developer-guide.en.md — heading grep shows `## Architecture` (line 39) but NO `# Frontend`/`## Frontend` heading; nearest is `### Real-time Scoreboards` / 'Key Features'. No anchor `#frontend` is generated.`
  - The `#architecture` anchor target exists, but the `#frontend` fragment has no corresponding heading in developer-guide.en.md, so both Frontend links land on the page top instead of a Frontend section. Broken in-page anchor a developer would click.
  - ➜ **Fix:** Add a `## Frontend` heading to developer-guide.en.md or repoint the links to an existing section/doc.

### `docs/developers/pool-scoreboard-changelog.en.md`

- **[DRIFT]** start_game() in app/models/table_monitor.rb checks existing_party_game = game if game.present? && game.tournament_type.present?
  - Doc-Stelle: Bug Fixes #3 (lines 98-121)
  - Code: `app/models/table_monitor.rb:1427-1429 — def start_game delegates to TableMonitor::GameSetup.call; the actual logic lives at app/services/table_monitor/game_setup.rb:342 — existing_party_game = @tm.game if @tm.game.present? && @tm.game.tournament_type.present?`
  - The behavior the changelog describes is real and correct, but it was extracted out of table_monitor.rb into the GameSetup service object (setup_existing_party_game at game_setup.rb:390). The changelog's file attribution (app/models/table_monitor.rb) and inline-method snippet are stale post-extraction.
  - ➜ **Fix:** Update file reference to app/services/table_monitor/game_setup.rb.

- **[DRIFT]** Pool quickstart config in config/carambus.yml.erb uses keys 'sets:' / 'kickoff_switches_with' under flat pool: 8-Ball: hash with 'Best of N' labels
  - Doc-Stelle: New Features #1 (lines 13-37)
  - Code: `config/carambus.yml.erb:72-110 — pool: is an array of {category:, buttons:[...]}; buttons use sets_to_win: (not sets:), labels like '3 (W)'/'5 (A)'; 14.1 endlos uses balls:/innings: with labels '50','75','100'`
  - The feature exists but the documented config shape is wrong: actual structure is a list of category/buttons, the key is sets_to_win (not sets), and labels are '(W)'/'(A)' suffixes, not 'Best of N'. The doc's 14.1 labels ('50 Points') also differ from actual ('50'). The YAML snippet would not parse against the real config schema.
  - ➜ **Fix:** Replace the YAML snippet with the real category/buttons + sets_to_win structure.

### `docs/developers/services/party-monitor.en.md`

- **[DRIFT]** do_placement takes exactly 3 parameters: game, r_no (round number), t_no (table number).
  - Doc-Stelle: line 75 — TablePopulator entry point `populator.do_placement(game, r_no, t_no)` and Input table lines 80-86
  - Code: `app/services/party_monitor/table_populator.rb:71 — def do_placement(new_game, r_no, t_no, row = nil, row_nr = nil)`
  - The method has FIVE parameters: new_game, r_no, t_no, row (default nil), row_nr (default nil). The doc omits the two optional trailing params row and row_nr, both of which are forwarded into @table_monitor.deep_merge_data! (lines 124-125). The PartyMonitor model delegator also passes all five: party_monitor.rb:119 `do_placement(new_game, r_no, t_no, row, row_nr)`.
  - ➜ **Fix:** Update the signature to do_placement(game, r_no, t_no, row = nil, row_nr = nil) and add row/row_nr rows to the Input table (both optional).

- **[DRIFT]** All AASM events (e.g., `finish_match!`, `close_match!`) are fired on `@party_monitor` or the respective `table_monitor` record.
  - Doc-Stelle: lines 93-95 — Architecture Decision b ("AASM events on the model, not the service")
  - Code: `app/services/party_monitor/result_processor.rb:63 table_monitor.finish_match!; :154 tabmon.close_match!; :186 table_monitor.close_match!`
  - The two events named as examples (finish_match!, close_match!) are TableMonitor events and are ONLY ever fired on table_monitor/tabmon, NEVER on @party_monitor. No finish_match!/close_match! call targets @party_monitor anywhere in result_processor.rb. The PartyMonitor model has a completely different AASM event set (finish_round, finish_party, close_party, etc. — party_monitor.rb:62-91), none of which are fired by ResultProcessor. The phrase '@party_monitor or the respective table_monitor' wrongly implies these example events can fire on the party_monitor.
  - ➜ **Fix:** Reword to: 'AASM events such as finish_match! and close_match! are fired on the table_monitor record (a TableMonitor), not on the service.' Drop the '@party_monitor or' alternative for these specific events, or cite a real party_monitor AASM event if one is intended.

### `docs/developers/services/region-cc.en.md`

- **[GAP]** `RegionCc::GamePlanSyncer.call(... operation: :sync_game_plans ...)` — only :sync_game_plans operation shown
  - Doc-Stelle: line 85
  - Code: `app/services/region_cc/game_plan_syncer.rb:30-31 — when :sync_game_plans then sync_game_plans; when :sync_game_details then sync_game_details`
  - GamePlanSyncer dispatches two operations: :sync_game_plans and :sync_game_details. The doc only documents :sync_game_plans, omitting :sync_game_details.
  - ➜ **Fix:** Add the :sync_game_details operation to the GamePlanSyncer example.

- **[GAP]** `RegionCc::TournamentSyncer` ... 'multiple operations'; example shows only operation: :sync_tournaments
  - Doc-Stelle: line 20 (table) and line 77
  - Code: `app/services/region_cc/tournament_syncer.rb:24-28 — when :sync_tournaments; when :sync_tournament_ccs; when :sync_tournament_series_ccs; when :sync_championship_type_ccs; when :fix_tournament_structure`
  - TournamentSyncer actually dispatches five operations (:sync_tournaments, :sync_tournament_ccs, :sync_tournament_series_ccs, :sync_championship_type_ccs, :fix_tournament_structure). The doc says 'multiple operations' but only shows :sync_tournaments in the code example, so four operations are undocumented.
  - ➜ **Fix:** Enumerate all five TournamentSyncer operations in the example block, matching the treatment given to LeagueSyncer.

### `docs/developers/services/tournament-monitor.en.md`

- **[DRIFT]** processor.update_game_participations is a public entry point that 'updates GameParticipation records' (shown called with no arguments).
  - Doc-Stelle: ResultProcessor — Entry points (lines 84-86)
  - Code: `app/services/tournament_monitor/result_processor.rb:246 def update_game_participations(tabmon) -> update_game_participations_for_game(tabmon.game, tabmon.data)`
  - The method requires a mandatory positional argument (a table monitor / tabmon). The doc presents it as a zero-arg call. It is also merely a thin backward-compat delegator to the private update_game_participations_for_game. Calling it as documented (no args) raises ArgumentError.
  - ➜ **Fix:** Show the signature as update_game_participations(tabmon) and note it delegates to update_game_participations_for_game(tabmon.game, tabmon.data).

### `docs/developers/streaming-architecture.en.md`

- **[DRIFT]** scoreboard_overlay_url is .../scoreboard_overlay?table=N (table number)
  - Doc-Stelle: Section 1.2 (line 176-178), Render-Pipeline (line 661), config file (line 469)
  - Code: `app/models/stream_configuration.rb:173,194 — ".../locations/#{location.md5}/scoreboard_overlay?table_id=#{table.id}"; app/controllers/locations_controller.rb:333 — params[:table_id]`
  - The overlay URL uses table_id=<id> (DB id), not table=<number>. The controller explicitly prefers params[:table_id] and treats params[:table] (number) as a deprecated, ambiguous legacy fallback (comment at locations_controller.rb:336). Doc consistently shows ?table=N.
  - ➜ **Fix:** Change all ?table=N examples to ?table_id=<id> and note table-number is deprecated.

- **[DRIFT]** streaming_overlay_controller.js connect() calls subscribeToTableMonitor() (ActionCable real-time updates active)
  - Doc-Stelle: Section 1.6 Frontend (lines 329-360)
  - Code: `app/javascript/controllers/streaming_overlay_controller.js:9-23 — connect() sets setInterval window.location.reload() every 3s; subscribeToTableMonitor() is defined but the call is commented out ('// this.subscribeToTableMonitor()')`
  - Actual Phase-1 implementation uses 3-second full-page polling, not ActionCable. The TableMonitorChannel subscription exists as future (Phase 2) code that is explicitly NOT invoked. Doc presents the WebSocket path as the live behavior. Also includes a triggerOverlayUpdate() PNG-fetch to localhost:8888 not mentioned in the doc.
  - ➜ **Fix:** Document the polling-based Phase-1 approach as current; mark ActionCable as future/unused.

- **[DRIFT]** scoreboard_overlay.html.erb uses @game.player_a.display_name / @game.score_a / .overlay-container / .player-section / 'VS' / 'Kein aktives Spiel'
  - Doc-Stelle: Section 1.5 Overlay-View (lines 287-305)
  - Code: `app/views/locations/scoreboard_overlay.html.erb:17-22,30-31,50,61 — uses options[:player_a]/options[:player_b] with current_left_player left/right swap logic; data-controller="streaming-overlay"; data-streaming-overlay-target="scoreA"/"scoreB"`
  - The real view derives left_player/right_player from options[:current_left_player] and an options hash, not @game.player_a/score_a. None of the class names (overlay-container, player-section, vs-section, no-game) or the 'VS'/'Kein aktives Spiel' literals exist in the actual template. The doc snippet is illustrative/fabricated.
  - ➜ **Fix:** Replace the view snippet with the real options-based structure or mark it as schematic.

- **[DRIFT]** Tests written in RSpec (spec/models/stream_configuration_spec.rb, spec/jobs/..., spec/system/...)
  - Doc-Stelle: Testing-Strategie (lines 1067-1117)
  - Code: `Project uses Minitest, not RSpec (CLAUDE.md: 'Uses Minitest (not RSpec)'); no spec/ stream files exist. Test dirs are test/ with Minitest.`
  - The entire testing section is written in RSpec idiom (RSpec.describe, create(:...), expect(...).to eq). This project does not use RSpec for app tests; these spec files do not exist. The examples are aspirational and framework-mismatched.
  - ➜ **Fix:** Rewrite test examples in Minitest or mark them as illustrative pseudo-tests.

- **[GAP]** Migration/columns listed: youtube fields, camera, overlay, status, network, quality only
  - Doc-Stelle: Section 1.1 migration (lines 96-138), schema
  - Code: `db/migrate/20260122171712_add_camera_manual_settings_to_stream_configurations.rb, 20260122172221, 20260109210439_add_stream_destination...; app/jobs/stream_control_job.rb:162-172 references perspective_enabled, perspective_coords, focus_auto, exposure_auto, focus_absolute, exposure_absolute, brightness, contrast, saturation, raspi_ssh_user`
  - Later migrations added stream_destination, perspective correction (perspective_enabled/perspective_coords), camera manual settings (focus/exposure/brightness/contrast/saturation), and raspi_ssh_user. None of these appear in the doc's schema/migration snippet. The generated config file (generate_config_file) writes all of them.
  - ➜ **Fix:** Add the post-2025-12 columns to the schema section, or note the doc snapshot predates them.

### `docs/developers/test-implementation-summary.de.md`

- **[DRIFT]** Rake tasks listed: test:critical, test:coverage, test:concerns, test:scraping, test:stats, test:list, test:validate, test:rerecord_vcr.
  - Doc-Stelle: lines 63-72
  - Code: `lib/tasks/test.rake — defines tasks: coverage, critical, concerns, scraping, rerecord_vcr, list, stats, characterization, validate (no `concerns`/`scraping` shown by the oEgrep but they are namespaced `test:` tasks referenced; `characterization` exists and is undocumented).`
  - All eight documented tasks exist, but the doc omits `test:characterization`, which is defined in lib/tasks/test.rake. Minor under-documentation rather than a broken instruction.
  - ➜ **Fix:** Add `test:characterization` to the documented rake-task list.

### `docs/developers/tournament-architecture-overview.en.md`

- **[DRIFT]** TournamentMonitor handles algorithms for distributing players to groups (distribute_to_group, distribute_with_sizes), determining group ranks (group_rank), and KO rankings (ko_ranking)
  - Doc-Stelle: Section 3, TournamentMonitor bullet (line 18)
  - Code: `app/models/tournament_monitor.rb:192-197 — distribute_to_group/distribute_with_sizes are thin delegators to TournamentMonitor::PlayerGroupDistributor (the real impl is player_group_distributor.rb:57,115); group_rank is NOT defined on TournamentMonitor — def group_rank lives at app/services/tournament_monitor/ranking_resolver.rb:93; ko_ranking IS on the model (tournament_monitor.rb:204)`
  - Mixed accuracy. distribute_to_group/distribute_with_sizes exist on the model only as delegators; the actual logic was extracted to PlayerGroupDistributor. group_rank does not exist on TournamentMonitor at all (it is a RankingResolver service method). ko_ranking is correctly on the model. The doc presents all of these as TournamentMonitor methods.
  - ➜ **Fix:** Clarify that distribution/ranking logic lives in the TournamentMonitor:: services (PlayerGroupDistributor, RankingResolver) with the model delegating; move group_rank attribution to RankingResolver.

- **[DRIFT]** TournamentMonitorState (lib/tournament_monitor_state.rb) holds state machine logic ... e.g. finalize_game_result, all_table_monitors_finished?, finalize_round, group_phase_finished?
  - Doc-Stelle: Section 3, TournamentMonitorState bullet (line 19)
  - Code: `lib/tournament_monitor_state.rb defines all_table_monitors_finished? (line 4), finalize_round (line 9), group_phase_finished? (line 60); finalize_game_result is NOT defined there (only mentioned in a comment line 48). def finalize_game_result lives in app/services/tournament_monitor/result_processor.rb:294 (and party_monitor.rb:168, party_monitor/result_processor.rb:161)`
  - Three of the four listed methods do exist in TournamentMonitorState, but finalize_game_result does not — it is a ResultProcessor service method. The module is correctly included into TournamentMonitor (tournament_monitor.rb:33 include TournamentMonitorState).
  - ➜ **Fix:** Remove finalize_game_result from the TournamentMonitorState example, or attribute it to TournamentMonitor::ResultProcessor.

- **[DRIFT]** Trace TournamentMonitor methods like #rank_from_group_ranks and #distribute_to_group
  - Doc-Stelle: Cheatsheet step 2 (line 34)
  - Code: `rank_from_group_ranks defined at app/services/tournament_monitor/ranking_resolver.rb:158 (not on TournamentMonitor model); distribute_to_group on model is a delegator (tournament_monitor.rb:192) to PlayerGroupDistributor`
  - rank_from_group_ranks is a RankingResolver service method, not a TournamentMonitor model method. Calling it 'TournamentMonitor#rank_from_group_ranks' will mislead a debugger looking in the model file.
  - ➜ **Fix:** Point the reader to TournamentMonitor::RankingResolver#rank_from_group_ranks.

### `docs/developers/tournament-duplicate-handling.en.md`

- **[DRIFT]** Example log shows 'Marked cc_id 123 as abandoned ... (keeping 456)' and a per-region summary 'Processed 15 tournaments, skipped 5, abandoned 2 duplicates'.
  - Doc-Stelle: lines 117-125 (Example Output)
  - Code: `app/models/region.rb:539 actual log: `Found duplicate tournament '#{name}', marked old cc_id #{old_cc_id} as abandoned, keeping cc_id #{cc_id}` — single combined line; no separate per-cc_id 'Marked ... as abandoned' lines and no 'Processed N / skipped N / abandoned N' summary line found in the scraping path.`
  - The illustrative log output does not correspond to any emitted log statements. The real log emits one 'Found duplicate tournament ... marked old cc_id ... keeping cc_id ...' line per detected duplicate (region.rb:539) and a skip line (region.rb:509); there is no aggregate counts summary.
  - ➜ **Fix:** Replace the example block with the actual log strings from region.rb:509/539, or drop the fabricated summary line.

### `docs/reference/api.en.md`

- **[GAP]** Rate limiting (1000/100 req/hr with X-RateLimit-* headers), JS 'carambus-api-client' npm package, and Ruby 'carambus_api' gem client.
  - Doc-Stelle: api.en.md:24-25, 556-569, 621-665 (API Token Auth, Rate Limiting, SDKs)
  - Code: `No rack-attack / throttling gem in stack (CLAUDE.md gem list); no X-RateLimit header emission in app/controllers. No published carambus-api-client npm package or carambus_api gem referenced anywhere in the repo.`
  - Rate limiting and the named client SDKs are documented as existing features but have no implementation or external package backing them.
  - ➜ **Fix:** Mark rate limiting and SDKs as 'planned/example only', or remove. They mislead integrators into expecting a published client.

- **[GAP]** The external tournament bridge exposes exactly 4 endpoints: tables, seeding, round_start, round_result.
  - Doc-Stelle: api.en.md:59-62 (External Tournament Bridge endpoint table)
  - Code: `config/routes.rb:82-159 defines ~16 external_tournament/* routes: seeding, round_start, round_result, tables, tournament, lock_table, start_game, acknowledge_result, end_tournament, player_reconcile, clubs, club_players, player_rankings, disciplines, categories, registration_lists.`
  - The documented bridge table covers only 4 of ~16 actual endpoints. The newer app-driven lifecycle endpoints (start_game which the code notes 'ersetzt round_start im App-Lifecycle', lock_table, end_tournament, player_reconcile, clubs, disciplines, categories, registration_lists, etc.) are undocumented in the public API reference.
  - ➜ **Fix:** Expand the External Tournament Bridge endpoint table to cover the full route set, or explicitly scope the doc to the v0.5 subset and link to the developer doc for the rest.

## 🟡 Niedrig — kosmetisch / Naming (16)

### `docs/developers/database-design.en.md`

- **[DRIFT]** Seeding: `belongs_to :player, optional: true`
  - Doc-Stelle: lines 20-27
  - Code: `app/models/seeding.rb:34 — belongs_to :player  (no optional: true)`
  - The doc's Seeding code snippet declares `belongs_to :player, optional: true`, but the actual model declares `belongs_to :player` without optional, meaning player is required. The tournament and league_team associations in the snippet (both optional: true) do match the code.
  - ➜ **Fix:** Remove `, optional: true` from the `belongs_to :player` line in the snippet to reflect the required association.

### `docs/developers/database-partitioning.en.md`

- **[DRIFT]** RegionTaggable registers callbacks after_save :update_region_tagging and after_destroy :update_region_tagging.
  - Doc-Stelle: Sec 'RegionTaggable Concern' code block — included do after_save :update_region_tagging; after_destroy :update_region_tagging end
  - Code: `app/models/concerns/region_taggable.rb:7-8 after_save :update_version_region_data ; after_destroy :update_version_region_data (no method named update_region_tagging exists).`
  - The callback method is update_version_region_data, not update_region_tagging. The doc's illustrative method name does not exist in code.
  - ➜ **Fix:** Rename the callback to update_version_region_data in the concern example.

- **[DRIFT]** Rake task is region_taggings:update_all_region_ids (plural 'ids').
  - Doc-Stelle: Sec 'Verwendung > Rake Tasks' — rails region_taggings:update_all_region_ids
  - Code: `lib/tasks/region_taggings.rake:4 task update_all_region_id: :environment (singular 'id').`
  - Task name is update_all_region_id (singular). Doc also omits two existing tasks: update_existing_versions (l.270). Doc's 'region_taggings:update_all' (l.117), 'verify' (l.196), 'set_global_context' (l.228) match.
  - ➜ **Fix:** Fix the task name to update_all_region_id; optionally document update_existing_versions.

### `docs/developers/developer-guide.en.md`

- **[GAP]** Implies LocalProtector and SourceHandler are concerns in app/models/concerns/
  - Doc-Stelle: Architecture > Concerns (lines 61-63) / Database Design
  - Code: `module LocalProtector defined at app/models/local_protector.rb (NOT in concerns/); module SourceHandler at app/models/source_handler.rb (NOT in concerns/); app/models/concerns/ contains region_taggable.rb, searchable.rb, etc. but not these two`
  - LocalProtector and SourceHandler live directly under app/models/, not app/models/concerns/. RegionTaggable is the only one of the three listed concerns actually under concerns/. Low impact since they are still used as concerns, but the implied file location is wrong.
  - ➜ **Fix:** Note the actual paths app/models/local_protector.rb and app/models/source_handler.rb when documenting concern locations.

### `docs/developers/pool-scoreboard-changelog.en.md`

- **[DRIFT]** User manual at docs/pool_scoreboard_benutzerhandbuch.de.md
  - Doc-Stelle: New Features #2 (line 41) and Documentation (line 265)
  - Code: `File exists at docs/players/pool_scoreboard_benutzerhandbuch.de.md (and .en.md); nothing at docs/pool_scoreboard_benutzerhandbuch.de.md`
  - The manual was created but lives under docs/players/, not docs/ root. The changelog also self-references 'docs/CHANGELOG_POOL_SCOREBOARD.md - This file' (line 266) while the actual file is docs/developers/pool-scoreboard-changelog.en.md — a stale self-reference.
  - ➜ **Fix:** Fix the manual path to docs/players/... and update the self-referencing filename.

### `docs/developers/services/party-monitor.en.md`

- **[DRIFT]** The cattr_accessor value `allow_change_tables` is accessed as `PartyMonitor.allow_change_tables` (class level), not as `TournamentMonitor.allow_change_tables`.
  - Doc-Stelle: lines 97-99 — Architecture Decision c (cattr_accessor pattern)
  - Code: `app/models/party_monitor.rb:35 cattr_accessor :allow_change_tables — but no read/write of PartyMonitor.allow_change_tables exists in app/services/party_monitor/*; only a code comment at table_populator.rb:16 references it.`
  - `cattr_accessor :allow_change_tables` IS declared on the PartyMonitor model, but the PartyMonitor services never actually access it (grep for `PartyMonitor.allow_change_tables` finds only the doc-comment at table_populator.rb:16). The only live read/write of an allow_change_tables cattr is on the TournamentMonitor side (tournament_monitor/table_populator.rb:73 and :355 set TournamentMonitor.allow_change_tables). So the doc's 'is accessed as PartyMonitor.allow_change_tables' overstates reality — it is declared but unused in these services.
  - ➜ **Fix:** Soften to: 'allow_change_tables is declared as a cattr_accessor on the PartyMonitor model (party_monitor.rb:35); the analogous live usage on the TournamentMonitor side reads/writes TournamentMonitor.allow_change_tables.' Note it is currently not referenced inside the PartyMonitor services.

- **[GAP]** accumulate_results returns nil and merely aggregates GameParticipation results into @party_monitor.data["rankings"].
  - Doc-Stelle: lines 26-27 — ResultProcessor entry point `processor.accumulate_results # → nil`
  - Code: `app/services/party_monitor/result_processor.rb:252-254 @party_monitor.data_will_change!; @party_monitor.data["rankings"] = rankings; @party_monitor.save!`
  - accumulate_results is not a read-only aggregation: it calls @party_monitor.save! (line 254), persisting the party_monitor record (it sets data_will_change! then assigns data["rankings"]). The doc's 'aggregates ... into data["rankings"]' is correct on the target key, but the persistence side effect (save!) is undocumented. The source itself carries a 'Pitfall 4' note (lines 198-203) that the data mutation may not persist via the indifferent-access wrapper — neither the save! nor this pitfall is reflected in the doc.
  - ➜ **Fix:** Note that accumulate_results calls @party_monitor.save! and mention the documented Pitfall 4 (HashWithIndifferentAccess mutation) so readers don't assume it is purely in-memory.

### `docs/developers/services/table-monitor.en.md`

- **[DRIFT]** "Tischnummer" => Integer  # table ID
  - Doc-Stelle: ResultRecorder — data contract, "Tischnummer" row (line 76)
  - Code: `app/services/table_monitor/result_recorder.rb:94 "Tischnummer" => @tm.game.table_no`
  - Tischnummer is populated from game.table_no (the table NUMBER on the game), not a table record ID. The comment 'table ID' is misleading — it is a logical table number, not a Table primary key.
  - ➜ **Fix:** Change the comment from 'table ID' to 'table number (game.table_no)'.

### `docs/developers/services/tournament-monitor.en.md`

- **[GAP]** game.with_lock covers exactly: write_game_result_data + finish_match!.
  - Doc-Stelle: ResultProcessor — DB lock scope (lines 91-96) and Architecture Decision (c)
  - Code: `app/services/tournament_monitor/result_processor.rb:54-74 with_lock { table_monitor.reload; game.reload; write_game_result_data; game.reload; table_monitor.reload; if may_finish_match? finish_match! }`
  - The lock block also contains two reload pairs (table_monitor.reload + game.reload before the write, and again after it) and a may_finish_match? guard around finish_match!. The word 'exactly' undersells the scope; the file's own header comment (lines 15-16) correctly lists all six operations. finalize_game_result (the ClubCloud upload) runs OUTSIDE the lock (line 82), which the doc does not mention.
  - ➜ **Fix:** Reword to 'Covers write_game_result_data plus the surrounding reload pairs and the guarded finish_match!; the ClubCloud upload (finalize_game_result) runs outside the lock.'

### `docs/developers/services/tournament.en.md`

- **[GAP]** calculate_and_cache_rankings updates 'the tournament's data hash with calculated rankings' (no preconditions stated).
  - Doc-Stelle: lines 51-58 — RankingCalculator entry points
  - Code: `app/services/tournament/ranking_calculator.rb:22-23 return unless @tournament.organizer.is_a?(Region) && @tournament.discipline.present?; return unless @tournament.id.present? && @tournament.id >= Tournament::MIN_ID`
  - The doc documents guard conditions for PublicCcScraper and TableReservationService but omits them entirely for RankingCalculator. calculate_and_cache_rankings early-returns unless the organizer is a Region AND a discipline is present AND the tournament is local (id >= MIN_ID). It also writes to data["player_rankings"] specifically (line 63), not a generic 'rankings' key. These are verifiable behaviors the doc leaves out.
  - ➜ **Fix:** Add the three guard conditions (Region organizer, discipline present, local tournament id >= MIN_ID) and name the concrete data key data["player_rankings"].

### `docs/developers/setup/development-logging.de.md`

- **[DRIFT]** Edit config/environments/development.rb at 'Zeile 13-16' for the logger change.
  - Doc-Stelle: lines 44-47
  - Code: `config/environments/development.rb:15-23 — the BroadcastLogger block is at lines 15-23, not 13-16.`
  - Stale line-number reference (off by ~2-7 lines because a require and session_store block precede it). Cosmetic; the surrounding context is unambiguous.
  - ➜ **Fix:** Update line reference to ~15-23 or drop the explicit line numbers.

### `docs/developers/streaming-architecture.en.md`

- **[DRIFT]** streaming_overlay.html.erb layout uses body { background: rgba(0,0,0,0.75); } with fixed 1920x200 overlay dimensions
  - Doc-Stelle: Section 1.5 Layout (lines 307-319)
  - Code: `app/views/layouts/streaming_overlay.html.erb:32 — <body ... style="background-color: #000000;">; no 1920x200 declaration; defines overlay-gradient + pulse-dot animation instead`
  - Actual layout uses solid black background (#000000), not a 75% alpha. No fixed 1920x200 dimensions in the layout. It pulls in stylesheet_link_tag application + action_cable_meta_tag and defines a teal overlay-gradient and live-indicator animation the doc does not mention.
  - ➜ **Fix:** Update the layout snippet to reflect solid black background and the actual inline styles.

- **[DRIFT]** ssh_user defaults to 'pi'
  - Doc-Stelle: SSH user (line 217 vs actual)
  - Code: `app/jobs/stream_control_job.rb:218 — ssh_user defaults to 'pi'; app/jobs/stream_health_job.rb:162 — ssh_user defaults to 'www-data'`
  - StreamControlJob defaults the SSH user to 'pi' (consistent with doc), but StreamHealthJob defaults to 'www-data'. The two jobs are inconsistent and the doc only mentions pi. Minor, but a real divergence between the two SSH paths.
  - ➜ **Fix:** Align the default ssh_user across both jobs and document raspi_ssh_user override.

### `docs/reference/api.en.md`

- **[DRIFT]** PATCH /table_monitors/{id} with body {table_monitor:{balls_a, balls_b}} updates the monitor.
  - Doc-Stelle: api.en.md:398-409 (Update Table Monitor PATCH balls_a/balls_b)
  - Code: `config/routes.rb:268-291 — table_monitors member actions are set_balls, add_one, add_ten, minus_one, minus_ten, next_step, start_game, evaluate_result, undo, up, down, toggle_dark_mode. Score changes go through these POST member actions (e.g. set_balls), not a generic PATCH with balls_a/balls_b.`
  - While resources :table_monitors yields an :update (PATCH) route, the documented balls_a/balls_b param contract does not match how scores are actually mutated (set_balls / add_one etc.). The JS updateScore helper (api.en.md:719) using balls_${player} is likewise unsupported.
  - ➜ **Fix:** Document the real score-mutation member actions (set_balls, add_one, minus_one, next_step, ...) instead of an invented PATCH balls_a/balls_b contract.

### `docs/reference/search.en.md`

- **[DRIFT]** Club search searches in 'Club name (full and short name)' and 'Homepage'.
  - Doc-Stelle: search.en.md:37 (Club Search areas)
  - Code: `app/models/club.rb:78-84 text_search_sql = regions.shortname, clubs.address, clubs.shortname, clubs.email, clubs.cc_id — only shortname (NOT full clubs.name), and homepage is NOT in the free-text SQL (it's a filter column only, club.rb:72 'Homepage' => 'clubs.homepage').`
  - Club free-text search covers shortname only (not full name), and does not include homepage in the text_search_sql. Homepage is reachable only via explicit homepage:value field filter, not via general free-text.
  - ➜ **Fix:** Correct the Club Search list: free-text covers region shortname, address, club shortname, email, cc_id. Note homepage is a field-filter, not free-text.

- **[DRIFT]** Tournament free-text search searches in 'Region/Organizer'.
  - Doc-Stelle: search.en.md:48-50 (Tournament Search areas: Region/Organizer)
  - Code: `app/models/tournament.rb:204-209 text_search_sql = tournaments.ba_id, tournaments.title, tournaments.shortname, seasons.name only. Region/organizer is joined (routes via INNER JOIN regions ON organizer_id, tournament.rb:215) and filterable by region_id, but regions.shortname/name is NOT in the free-text OR-clause.`
  - Tournament general free-text matches title, shortname, season name and ba_id — not the organizer/region name. Region is only reachable via the region_id field filter, not free text.
  - ➜ **Fix:** Adjust Tournament Search list: free-text = title, short name, season, ba_id. Region/Organizer is a structured filter, not free-text.

## Doc-Gesundheit pro Datei (Verifier-Urteil)

- **tournament-monitor+table-monitor** — Both docs track the code well structurally — class names, file paths, ApplicationService vs PORO split, AASM wiring (do_reset_tournament_monitor after_enter, set_over before_save invariant), the broadcast-via-after_update_commit decision, and the German save_result data contract all verify cleanly. The notable problems are in the RankingResolver/PlayerGroupDistributor section of the tournament-monitor doc: it claims integer group-number keys when the code uses "group<n>" string keys (high), and it documents a non-existent "fin.w" winner DSL token the parser cannot match (high). Smaller drifts: update_game_participations is shown arg-less but requires a tabmon argument, the lock scope is described as 'exactly' two operations while it also contains reload pairs, and Tischnummer is table_no not a table ID.
- **tournament+party-monitor** — Both docs are structurally sound — service class names, files, superclasses, the ApplicationService-vs-PORO split, the model-resident table methods, the TournamentMonitor.transaction Pitfall, and the with_lock/finish_match! sequence all verified. Five MATCHes confirmed (more not individually reported). Three DRIFTs: (1) TablePopulator#do_placement actually takes 5 params (new_game, r_no, t_no, row, row_nr), not 3 — the two optional params are forwarded to deep_merge_data!; (2) Architecture Decision b wrongly implies finish_match!/close_match! can fire on @party_monitor — in code they fire ONLY on the TableMonitor record; (3) Decision c overstates allow_change_tables usage — it is declared on the PartyMonitor model but never read/written inside the PartyMonitor services (only TournamentMonitor uses it live). Two GAPs: RankingCalculator's guard conditions (Region organizer + discipline + local id >= MIN_ID) and its concrete data["player_rankings"] key are undocumented; and accumulate_results' @party_monitor.save! side effect plus its documented Pitfall-4 mutation caveat are omitted. No high-severity structural lies; the most important fix is the do_placement arity and the AASM-event-receiver wording.
- **region-cc+database-design** — Both docs are largely accurate. region-cc.en.md correctly describes the 10-service namespace (9 ApplicationService syncers + 1 plain ClubCloudClient), the constructor/get/post signatures, PATH_MAP [path, read_only] format, PHPSESSID session handling, and armed.blank? dry-run semantics. However it contains one HIGH drift — the central dispatch claim `RegionCc.synchronize(opts)` names a method that does not exist (only synchronize_league_structure / synchronize_league_plan_structure / synchronize_tournament_structure exist) — and one HIGH drift where MetadataSyncer's documented operation :sync_metadata is fictional (real ops: :sync_category_ccs/:sync_group_ccs/:sync_discipline_ccs). Two MEDIUM gaps: GamePlanSyncer omits :sync_game_details, and TournamentSyncer documents only 1 of 5 operations. database-design.en.md is solid: all schema columns, serializations, polymorphic/named associations, concern includes, and the Game::MIN_ID reference verify against db/schema.rb and the models, with a single LOW drift (Seeding `belongs_to :player` is required in code, not `optional: true` as the snippet shows). NOTE: region_cc.rb is 491 lines, not ~2700 — the god-object has already been decomposed into the documented services, so the doc's service-oriented description reflects current reality.
- **developer-guide+architecture-overview** — Verified ~30 concrete claims across two docs. The Extracted Services inventory (35 services / 7 namespaces) is fully accurate and is the strongest part of the developer guide. However the developer guide's Getting Started has TWO high-severity broken setup commands (config/database.yml.example and config/application.yml.example do not exist; the app uses config/carambus.yml), wrongly names RSpec as the test framework (project is Minitest), and every cross-doc relative link is broken (bare .md vs actual .en.md/.de.md). The Seeding model example wrongly includes SourceHandler and marks player optional. The scenario:deploy example passes a second arg the rake task ignores. In the architecture overview, the method-to-class attributions in Section 3 and the debugging cheatsheet have drifted post-refactor: group_rank/rank_from_group_ranks belong to RankingResolver (not TournamentMonitor), finalize_game_result belongs to ResultProcessor (not TournamentMonitorState), and the high-severity cheatsheet error points do_placement at PlayerGroupDistributor when it actually lives in TablePopulator — sending a debugger to the wrong file. Controller actions, executor_params/TournamentPlan claims, and ResultProcessor methods all match.
- **external-tournament-bridge+duplicate-handling** — The external-tournament-bridge doc is highly accurate: every spot-checked concrete claim (16 routes under /api/external_tournament/* → Api::ExternalTournamentsController, RoundStartProcessor lookup path, StartGameProcessor rule-flag inheritance, AcknowledgeResultProcessor hold/ack/close + 409, PlayerMatcher 3-path fallback, csv_export removal + AppTournamentCleaner/midnight GC) MATCHES the code — no drift found there (sampled 9 MATCH). The tournament-duplicate-handling doc, by contrast, has SYSTEMIC high-severity drift: (1) wrong rake task name (scrape:tournaments_optimized → actually scrape:scrape_tournaments_optimized); (2) wrong host method (documents Region#scrape_tournaments_optimized doing name-grouping, but the real dedup is incremental per-row and the parameterless/grouping description is wrong — also the public entry is Season#scrape_tournaments_optimized); (3) the documented selection-priority ladder (games>seedings>highest cc_id) is NOT implemented in the scraping path — the scraper unconditionally keeps the current cc_id and abandons the prior; (4) the wrong model is documented — the scraper uses the lean AbandonedTournamentCcSimple (cc_id+context+abandoned_at), not the rich AbandonedTournamentCc with audit-trail columns; (5) two named private methods (process_single_tournament/process_duplicate_tournaments) do not exist anywhere; (6) the example log output is fabricated. Recommend a substantial rewrite of the duplicate-handling doc against region.rb:507-545 and the two distinct abandoned-cc models.
- **streaming-architecture+pool-scoreboard** — streaming-architecture.en.md shows HIGH drift: it predates major schema/feature evolution. The location_id column was removed (model now uses has_one :location through: :table) yet the doc still documents belongs_to :location; the YouTube-only model has since grown stream_destination (youtube/local/custom), custom/local RTMP, perspective correction, and camera-manual columns the doc omits entirely; the overlay URL switched from ?table=N to ?table_id=<id>; the JS overlay controller actually 3s-polls (ActionCable subscription is commented out, not active); and the view/layout/test snippets are illustrative/fabricated (RSpec tests don't exist — project is Minitest). One latent bug surfaced: deploy_all enqueues a non-existent StreamDeployJob. The two jobs (StreamControlJob/StreamHealthJob) and the admin controller/routes are accurately documented (MATCH). pool-scoreboard-changelog.en.md is mostly accurate on the substantive bug fixes (timer_data fix, prepare_final_game_result, reset_party_monitor, Discipline 14/1e params, start_round 'Hauptrunde' parsing all MATCH), but has notable drift: the headline balls_left() JS method does NOT exist in table_monitor_controller.js (HIGH); start_game logic was extracted to the GameSetup service (doc still attributes it to table_monitor.rb); the pool quickstart YAML snippet uses the wrong structure/keys (sets_to_win vs sets, category/buttons array); and the user-manual/self-reference file paths are wrong. Net: changelog changes mostly landed but with one unlanded JS claim and several stale file/structure references.
- **umb-scraping** — Both UMB-scraping docs are HIGHLY ACCURATE against the post-STI-migration code. All 10 documented units (Umb::HttpClient, DisciplineDetector, DateHelpers, PlayerResolver, FutureScraper, ArchiveScraper, DetailsScraper, and the three PdfParser:: classes) exist at the documented file paths with the documented signatures. The Umb:: namespace migration is fully reflected — NO references to pre-migration / legacy names: the docs never claim a flat 'UmbScraper' or 'InternationalResult' class, and the only InternationalResult mention in code is a comment in ranking_parser.rb:11 noting the old model no longer exists. STI claims verified: InternationalTournament < Tournament (international_tournament.rb:5) and InternationalGame < Game (international_game.rb:5), with type: 'InternationalGame' explicitly set in both game-creation paths (details_scraper.rb:368, :552). All scraper entry-point signatures, return values, PDF-parser constructor signatures, output-key contracts, the +/-30-day duplicate window, the 50-consecutive-404 early exit, and the PDF-pipeline order all match. Zero DRIFT and zero GAP findings of any severity. The single near-nitpick (50-consecutive-not-found is a hardcoded constant rather than a parameter) is cosmetic, not drift. Verifier verdict: docs are trustworthy and current.
- **clubcloud+partitioning** — The two ClubCloud docs and the partitioning doc all show real drift. clubcloud-mcp-server.de.md is the worst: it is frozen at 'Phase 40' state and is now substantially stale — 11 tools documented vs 22 in code (multiple implemented write-tools still listed as future 'Phase 40.1 Roadmap'), ALLOWLIST 15 vs 26, scenario slugs 3 vs 8, and three new production files (audit_trail.rb, role_tool_map.rb, tool_registry.rb) entirely undocumented; its Reference-Manual method/constant claims (Server, CcSession, BaseTool) do still match. clubcloud-upload.en.md has two high-severity drifts: the upload call moved from lib/tournament_monitor_state.rb to app/services/tournament_monitor/result_processor.rb#finalize_game_result, and it references nonexistent RegionCc columns login_username/login_password (actual: username/userpw); the core Setting.upload_game_to_cc / mapping / DRY-RUN / schema claims are accurate. database-partitioning.en.md is mostly correct but the Version for_region scope omits the load-bearing 'OR global_context = TRUE' clause, the concern callback name is wrong (update_version_region_data not update_region_tagging), the rake task is update_all_region_id (singular), and the RegionTaggable includer list is incomplete (15 models, doc lists 13). Highest-priority fixes: correct the upload file path and RegionCc credential column names (high, user-facing breakage), then regenerate the MCP tool inventory.
- **reference** — search.en.md is the most accurate: its mechanism description (whitespace-split AND logic, fieldname:value prefix-matched syntax, ILIKE partial match, JOIN+DISTINCT, relative 'heute' dates) all verified against application_controller.rb parse_search_string, Searchable concern, and the model text_search_sql methods — 2 low-severity DRIFTs where Club free-text omits full name/homepage (club.rb:78) and Tournament free-text omits Region/Organizer (tournament.rb:204). glossary.en.md is fully sound: every defined entity maps to a real app/models file and the MIN_ID split is correct. api.en.md is the worst offender: it documents a JSON:API contract the Rails app does not implement (HTML/Turbo resources, public tournaments is index/show only), a non-existent generate_game_plan endpoint (HIGH), four non-existent /api/sync/* endpoints (HIGH), and unimplemented rate-limiting + named SDK packages; it also undercounts the external_tournament bridge (4 documented vs ~16 actual routes) and misdescribes table_monitor score updates. Recommend a substantial rewrite of api.en.md to match the real route set in config/routes.rb.
- **misc-developer-docs** — Verified 5 developer docs against code. tournament-game-protection.de.md is HIGHLY ACCURATE (block_tournament_manipulation, block_if_tournament_game!, admin_can_reset_tournament? + AASM guards, LocationsController guards, and DE/EN I18n keys all match verbatim). development-logging.de.md matches the actual BroadcastLogger config (only a stale 'Zeile 13-16' line ref). Two HIGH-severity issues: (1) websocket-logging.de.md is stale/misleading — it instructs inserting logging 'after line 71' that is in fact already present at line 85 and uses different identifiers (suppress_broadcast not skip_update_callbacks, @collected_changes not previous_changes, perform_later(id,..) not perform_later(self,..)); (2) test-implementation-summary.de.md references five contributor docs (QUICKSTART_TESTS.md, TESTING.md, INSTALL_TESTS.md, TEST_SETUP_SUMMARY.md, TEST_ERFOLG.md) that do not exist. index.en.md's bare-.md links mostly resolve via the mkdocs i18n suffix plugin, but two #frontend anchors point to a nonexistent heading and streaming-dev-setup.md has no .en.md variant (broken on the EN build). NOTE: LocalProtector/SourceHandler live in app/models/ (not app/models/concerns/ as CLAUDE.md claims).
