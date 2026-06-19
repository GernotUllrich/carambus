# Drift-Report: Dokumentation vs. Code — Abschluss

> Vollständiger Code-↔-Docs-Abgleich von `docs/` gegen den Code (Stand origin/master @ `b0ddcd68` + lokale Commits). Methodik: pro Doc konkrete Claims (Assoziationen, AASM-States, Methoden/Signaturen, Routes, Rake-Tasks, Skripte, Config-Keys) gegen die echte Quelle prüfen → MATCH / DRIFT / GAP, jeder Befund mit `Datei:Zeile` belegt. Verifier-Fan-out (general-purpose-Agenten), verify-before-edit, de/en synchron.

**Status: alle geplanten Batches abgeschlossen und committet.** Bewusst NICHT geprüft: historische Postmortems in `docs/internal/bug-fixes` + `implementation-notes` (changelog-artig, beschreiben absichtlich einen vergangenen Stand) sowie `archive/obsolete/changelog`.

## Gesamtbilanz

- **163 handlungsrelevante Befunde** (DRIFT + GAP) über alle Batches — davon **142 behoben**, Rest als „bereits korrekt" verifiziert oder bewusst zurückgestellt (siehe je Batch).
- **~188 Aussagen als korrekt verifiziert** (MATCH / already-correct) — die Docs sind strukturell überwiegend solide.
- Die wenigen verbleibenden Punkte sind **Code-Bugs**, kein Doku-Drift mehr — an PAUL übergeben (s. u.).

## Coverage & Auflösung pro Batch

| Batch | Scope | Befunde (DRIFT/GAP) | behoben | MATCH/ok | Commit |
|---|---|--:|--:|--:|---|
| **Batch 1** | developers/ + reference/ | 71 | 71 | ~159 | `c8f17259 (high) · f394c189 (medium) · b0ddcd68 (low)` |
| **Batch 2** | Architektur-/Struktur-Docs (training_database, *-architecture, monitoring, Ops-Guides) | 29 | 28 | ~58 | `7597dd8a` |
| **Batch 3a** | managers/ (Nutzer-/Workflow-Docs) | 31 | 20 | ~85 | `528b3d0d` |
| **Batch 3b** | administrators/ (Server-/Deployment-/Streaming-/Raspi-Ops) | 32 | 23 | ~76 | `ebf485d9` |

## Behobene Befunde im Detail

### Batch 1 — developers/ + reference/

**`docs/developers/clubcloud-mcp-server.de.md`**

- `[DRIFT·high]` The MCP server has 11 tool classes (10 Read-Tools + 1 Write-Tool cc_finalize_teilnehmerliste).
- `[DRIFT·medium]` ApiSurface exposes 15 cc://api/{action} resources with a 15-entry ALLOWLIST.
- `[DRIFT·medium]` WorkflowScenarios whitelists 3 scenario slugs.
- `[GAP·medium]` The file layout block enumerates the lib/mcp_server/ source files (server.rb, cc_session.rb, transport/boot.rb, tools/, resources/) with no other top-level lib files.

**`docs/developers/clubcloud-upload.en.md`**

- `[DRIFT·high]` The auto-upload call (Setting.upload_game_to_cc) lives in lib/tournament_monitor_state.rb#finalize_game_result.
- `[DRIFT·high]` RegionCc holds credentials in region_cc.login_username and region_cc.login_password.

**`docs/developers/database-design.en.md`**

- `[DRIFT·low]` Seeding: `belongs_to :player, optional: true`

**`docs/developers/database-partitioning.en.md`**

- `[DRIFT·medium]` The Version for_region scope is: where("region_id IS NULL OR region_id = ?", region_id).
- `[DRIFT·medium]` 13 models include RegionTaggable, including PartyGame and Location.
- `[DRIFT·low]` RegionTaggable registers callbacks after_save :update_region_tagging and after_destroy :update_region_tagging.
- `[DRIFT·low]` Rake task is region_taggings:update_all_region_ids (plural 'ids').

**`docs/developers/debugging/websocket-logging.de.md`**

- `[DRIFT·high]` Manual change required in app/models/table_monitor.rb: insert logging lines after line 71 'after_update_commit lambda {'; uses skip_update_callbacks flag and previous_changes.inspect.
- `[DRIFT·medium]` Callback enqueues jobs via `TableMonitorJob.perform_later(self, "table_scores")` etc., and contains a line `TableMonitorJob.perform_later(self, "")` (line 88) with empty string that 'should maybe b…

**`docs/developers/developer-guide.en.md`**

- `[GAP·high]` cp config/database.yml.example config/database.yml
- `[GAP·high]` cp config/application.yml.example config/application.yml; Edit application.yml with your configuration
- `[DRIFT·high]` RSpec: Unit and integration tests
- `[DRIFT·medium]` class Seeding includes SourceHandler (include SourceHandler) and belongs_to :player, optional: true
- `[DRIFT·medium]` rake scenario:deploy[scenario_name,target_environment] (two args); link to scenario-management.md
- `[GAP·medium]` Links to database-setup.md, scoreboard-autostart.md, database-design.md, tournament-management.md, installation-overview.md, developer-guide.md#operations
- `[GAP·low]` Implies LocalProtector and SourceHandler are concerns in app/models/concerns/

**`docs/developers/index.en.md`**

- `[GAP·high]` Link '[YouTube Streaming Development Setup](streaming-dev-setup.md)' references an existing doc.
- `[GAP·medium]` Links '[Developer Guide - Frontend](developer-guide.en.md#frontend)' (twice) point to a Frontend section anchor.

**`docs/developers/pool-scoreboard-changelog.en.md`**

- `[DRIFT·high]` Added balls_left() method to app/javascript/controllers/table_monitor_controller.js that calls this.stimulate('TableMonitor#balls_left', this.element)
- `[DRIFT·medium]` start_game() in app/models/table_monitor.rb checks existing_party_game = game if game.present? && game.tournament_type.present?
- `[DRIFT·medium]` Pool quickstart config in config/carambus.yml.erb uses keys 'sets:' / 'kickoff_switches_with' under flat pool: 8-Ball: hash with 'Best of N' labels
- `[DRIFT·low]` User manual at docs/pool_scoreboard_benutzerhandbuch.de.md

**`docs/developers/services/party-monitor.en.md`**

- `[DRIFT·medium]` do_placement takes exactly 3 parameters: game, r_no (round number), t_no (table number).
- `[DRIFT·medium]` All AASM events (e.g., `finish_match!`, `close_match!`) are fired on `@party_monitor` or the respective `table_monitor` record.
- `[DRIFT·low]` The cattr_accessor value `allow_change_tables` is accessed as `PartyMonitor.allow_change_tables` (class level), not as `TournamentMonitor.allow_change_tables`.
- `[GAP·low]` accumulate_results returns nil and merely aggregates GameParticipation results into @party_monitor.data["rankings"].

**`docs/developers/services/region-cc.en.md`**

- `[DRIFT·high]` All sync operations are dispatched via `RegionCc.synchronize(opts)` on the model
- `[DRIFT·high]` `RegionCc::MetadataSyncer.call(... operation: :sync_metadata ...)` — operation key is :sync_metadata
- `[GAP·medium]` `RegionCc::GamePlanSyncer.call(... operation: :sync_game_plans ...)` — only :sync_game_plans operation shown
- `[GAP·medium]` `RegionCc::TournamentSyncer` ... 'multiple operations'; example shows only operation: :sync_tournaments

**`docs/developers/services/table-monitor.en.md`**

- `[DRIFT·low]` "Tischnummer" => Integer  # table ID

**`docs/developers/services/tournament-monitor.en.md`**

- `[DRIFT·high]` distribute_to_group / distribute_with_sizes return Hash { Integer => Array<Integer> }, i.e. keys are the integer group number (group_no => [player_ids]).
- `[GAP·high]` "fin.w" is a valid rule_str meaning 'Winner of the final (KO bracket reference)'.
- `[DRIFT·medium]` processor.update_game_participations is a public entry point that 'updates GameParticipation records' (shown called with no arguments).
- `[GAP·low]` game.with_lock covers exactly: write_game_result_data + finish_match!.

**`docs/developers/services/tournament.en.md`**

- `[GAP·low]` calculate_and_cache_rankings updates 'the tournament's data hash with calculated rankings' (no preconditions stated).

**`docs/developers/setup/development-logging.de.md`**

- `[DRIFT·low]` Edit config/environments/development.rb at 'Zeile 13-16' for the logger change.

**`docs/developers/streaming-architecture.en.md`**

- `[DRIFT·high]` stream_configurations has a location reference / belongs_to :location, and t.references :location null:false foreign_key:true
- `[GAP·high]` StreamConfiguration only encrypts youtube_stream_key and only supports YouTube RTMP; rtmp_url generates rtmp://a.rtmp.youtube.com/live2/:stream_key
- `[GAP·high]` deploy_all action deploys all streams (doc lists it as a valid custom action)
- `[GAP·medium]` Migration/columns listed: youtube fields, camera, overlay, status, network, quality only
- `[DRIFT·medium]` scoreboard_overlay_url is .../scoreboard_overlay?table=N (table number)
- `[DRIFT·medium]` streaming_overlay_controller.js connect() calls subscribeToTableMonitor() (ActionCable real-time updates active)
- `[DRIFT·medium]` scoreboard_overlay.html.erb uses @game.player_a.display_name / @game.score_a / .overlay-container / .player-section / 'VS' / 'Kein aktives Spiel'
- `[DRIFT·medium]` Tests written in RSpec (spec/models/stream_configuration_spec.rb, spec/jobs/..., spec/system/...)
- `[DRIFT·low]` streaming_overlay.html.erb layout uses body { background: rgba(0,0,0,0.75); } with fixed 1920x200 overlay dimensions
- `[DRIFT·low]` ssh_user defaults to 'pi'

**`docs/developers/test-implementation-summary.de.md`**

- `[GAP·high]` References docs contributors should read: QUICKSTART_TESTS.md, TESTING.md, INSTALL_TESTS.md, TEST_SETUP_SUMMARY.md, TEST_ERFOLG.md.
- `[DRIFT·medium]` Rake tasks listed: test:critical, test:coverage, test:concerns, test:scraping, test:stats, test:list, test:validate, test:rerecord_vcr.

**`docs/developers/tournament-architecture-overview.en.md`**

- `[DRIFT·high]` Inspect TournamentMonitor::PlayerGroupDistributor#do_placement to step through how the next Game is actively scheduled
- `[DRIFT·medium]` TournamentMonitor handles algorithms for distributing players to groups (distribute_to_group, distribute_with_sizes), determining group ranks (group_rank), and KO rankings (ko_ranking)
- `[DRIFT·medium]` TournamentMonitorState (lib/tournament_monitor_state.rb) holds state machine logic ... e.g. finalize_game_result, all_table_monitors_finished?, finalize_round, group_phase_finished?
- `[DRIFT·medium]` Trace TournamentMonitor methods like #rank_from_group_ranks and #distribute_to_group

**`docs/developers/tournament-duplicate-handling.en.md`**

- `[DRIFT·high]` The duplicate-handling system runs automatically via `rake scrape:tournaments_optimized`.
- `[DRIFT·high]` `Region#scrape_tournaments_optimized` now groups tournaments by name before processing, detects duplicates and applies selection logic, marking abandoned cc_ids.
- `[DRIFT·high]` Selection prioritizes in order: 1) Has games, 2) Has seedings, 3) No seedings/games, 4) Highest cc_id.
- `[DRIFT·high]` Abandoned cc_ids are stored in `abandoned_tournament_ccs` via the `AbandonedTournamentCc` model with fields region_shortname/season_name/tournament_name/reason/replaced_by_cc_id/replaced_by_tournam…
- `[GAP·high]` New private methods `process_single_tournament` and `process_duplicate_tournaments` handle individual tournaments and duplicate groups.
- `[DRIFT·medium]` Example log shows 'Marked cc_id 123 as abandoned ... (keeping 456)' and a per-region summary 'Processed 15 tournaments, skipped 5, abandoned 2 duplicates'.

**`docs/reference/api.en.md`**

- `[DRIFT·high]` POST /tournaments/{id}/generate_game_plan endpoint generates a tournament game plan.
- `[DRIFT·high]` REST CRUD endpoints: POST /tournaments, PATCH /tournaments/{id}, DELETE /tournaments/{id}, and list/get for players and parties returning JSON:API-style {data:{type,attributes,relationships}} paylo…
- `[GAP·high]` POST /api/sync/ba/players, /api/sync/ba/tournaments, /api/sync/cc/competitions, /api/sync/cc/results sync endpoints exist.
- `[GAP·medium]` Rate limiting (1000/100 req/hr with X-RateLimit-* headers), JS 'carambus-api-client' npm package, and Ruby 'carambus_api' gem client.
- `[GAP·medium]` The external tournament bridge exposes exactly 4 endpoints: tables, seeding, round_start, round_result.
- `[DRIFT·low]` PATCH /table_monitors/{id} with body {table_monitor:{balls_a, balls_b}} updates the monitor.

**`docs/reference/search.en.md`**

- `[DRIFT·low]` Club search searches in 'Club name (full and short name)' and 'Homepage'.
- `[DRIFT·low]` Tournament free-text search searches in 'Region/Organizer'.

### Batch 2 — Architektur-/Struktur-Docs (training_database, *-architecture, monitoring, Ops-Guides)

**`both`**

- `[DRIFT·high]` Sync API->Local via 'rake sync:from_api[region_id]'
- `[DRIFT·high]` Upload Local->API via 'rake sync:to_api[local_data]'
- `[DRIFT·medium]` FAQ: A Local Server can filter multiple regions, configurable via 'region_ids' array

**`docs/administrators/server-architecture.de.md`**

- `[DRIFT·high]` Local data upload via 'POST /api/tournaments' (DE-only 'Synchronisation von Local Data' block)

**`docs/internal/implementation-notes/monitoring-architecture.md`**

- `[DRIFT·high]` CLI rake tasks: scrape:stats, scrape:health, scrape:errors, scrape:export
- `[DRIFT·medium]` ScrapingMonitor is the Concern with track_scraping/record_* methods
- `[DRIFT·medium]` scrape_monitored.rake contains [7 Tasks]
- `[DRIFT·medium]` Production cron: daily scraping 3:00 AM; health check 6:00 AM; weekly cleanup Sunday 4:00 AM
- `[GAP·medium]` scraping_logs SQL schema columns and indexes (errors_json, executed_at, etc.) — no model_stats column
- `[GAP·medium]` Migrations list only create_scraping_logs and add_unchanged_count_to_scraping_logs
- `[DRIFT·medium]` Documentation files: docs/SCRAPING_MONITORING.md, docs/SCRAPING_MONITORING_QUICKSTART.md, docs/MONITORING_ARCHITECTURE.md, MONITORING_SYSTEM.md, test/README.md
- `[GAP·low]` check_anomalies performs 3 checks: error rate, slow duration, and 'no recent runs'

**`docs/internal/performance-analysis/PERFORMANCE_MEASUREMENT_GUIDE.md`**

- `[GAP·medium]` Cross-reference 'docs/JSON_BROADCASTING_FINAL_SUCCESS.md' and 'JSON_BROADCASTING_FINAL_SUCCESS.md' for JSON Broadcasting which is 'bereits implementiert, nur aktivieren'

**`docs/internal/performance-analysis/SCOREBOARD_ARCHITECTURE.md`**

- `[DRIFT·high]` Client channel app/javascript/channels/table_monitor_channel.js is 25 lines, a simple channel that just performs CableReady operations with no filtering/context awareness/complex logic.
- `[DRIFT·high]` Background job perform signature is perform(table_monitor, operation_type) and calls table_monitor.reload for fresh data; ~115 lines.
- `[DRIFT·high]` Lessons Learned: Optimistic UI and JSON Broadcasting did NOT work and were removed/avoided.
- `[DRIFT·high]` Callback config: after_update_commit enqueues TableMonitorJob.perform_later(self, 'table_scores') or perform_later(self, 'score_update') based on relevant_keys.any?.
- `[GAP·medium]` Configuration defines a Ruby constant STREAM_NAME = "table-monitor-stream".
- `[GAP·medium]` Server-side ActionCable channel (app/channels/table_monitor_channel.rb) is not documented.
- `[DRIFT·medium]` Reflex file is 674 lines; add_n is a minimal method (find, add_n_balls, do_play, save!).
- `[DRIFT·medium]` ~258 lines of core code (vs ~1,500+ in complex version).
- `[DRIFT·low]` Client controller table_monitor_controller.js is 118 lines; add_n reads n then stimulates.

**`docs/training_database_implementation.md`**

- `[DRIFT·medium]` TrainingConcept declares `has_many :tags, as: :taggable` (polymorphic tags association)
- `[GAP·medium]` TrainingConcept/TrainingExample/StartPosition model snippets only `include Translatable` (Taggable omitted); associations missing training_concept_disciplines, source_attributions/training_sources
- `[DRIFT·medium]` Routes: only nested shots have move_up/move_down; training_concepts has no member routes; no tags resource
- `[GAP·medium]` test/fixtures/shots.yml exists as a fixture
- `[GAP·medium]` test/models/shot_test.rb exists with shot_type/sequence_number tests
- `[DRIFT·low]` TrainingSource through-associations written without source:/source_type:

### Batch 3a — managers/ (Nutzer-/Workflow-Docs)

**`docs/managers/AUTO_RESERVE_README.md`**

- `[DRIFT·medium]` Criterion #1 '✅ single_or_league = single' as a selection filter for auto-reservation.

**`docs/managers/admin-roles.de.md / admin-roles.en.md`**

- `[DRIFT·high]` Permission check example uses `current_user.can_create_tournaments?`
- `[DRIFT·high]` Permission check example uses `current_user.is_system_admin?`

**`docs/managers/automatische_tischreservierung.de.md`**

- `[DRIFT·medium]` Criterion #1 'Turniertyp: Nur Einzelmeisterschaften (keine Ligen)' — i.e. the task filters to single tournaments only, excluding leagues.

**`docs/managers/clubcloud-integration.de.md / .en.md`**

- `[DRIFT·medium]` Automatic daily scrape is triggered via 'rake regions:scrape_all'.
- `[DRIFT·medium]` Manual scraping via UI is done by calling model methods: Region#reload_from_cc, Tournament#reload_from_cc, League#reload_from_cc_with_details.

**`docs/managers/clubcloud-mcp-cloud-quickstart.de.md`**

- `[DRIFT·high]` Tool-Anzahl je nach Rolle: LSW 22, Turnierleiter 19, Sportwart 16 Tools.

**`docs/managers/clubcloud-mcp-klickreduktion-anmeldung-aus-email.de.md`**

- `[DRIFT·medium]` Workflow runs 'in Claude Desktop' (intro, Nachher-section, Vorher/Nachher table, spickzettel sentence, image alt-text).

**`docs/managers/clubcloud-mcp-setup-service.de.md`**

- `[DRIFT·high]` Section 5 Authority table: Sportwart=16, Turnierleiter=19, LSW=22 Tools; intro 'welche der 22 MCP-Tools sichtbar sind'.
- `[DRIFT·high]` Section 5.3 + Section 6: verification expects subset 16 / 19 / 22; Troubleshooting row 'Tool-Anzahl falsch (16 statt 22 fuer LSW)'.

**`docs/managers/clubcloud-scenarios/cc-roles.de.md`**

- `[DRIFT·high]` MCP-Server has '22 MCP-Tools'; per-role Tool-Subsets: Sportwart 16, Turnierleiter 19, LSW 22.

**`docs/managers/clubcloud-scenarios/endrangliste-eintragen.de.md`**

- `[DRIFT·high]` Die Endranglisten-Funktion (`cc_submit_endrangliste`) ist Teil der Phase-40.1-Erweiterung. — presented as a concrete/named tool tied to a phase.

**`docs/managers/external-tournament-bridge.de.md`**

- `[DRIFT·medium]` Smoke-Test zeigt '5 Schritte mit ✓ (Login → Tournament-Lookup → Seeding → Round-Start → Round-Result)'.

**`docs/managers/external-tournament-bridge.en.md`**

- `[DRIFT·medium]` Smoke test 'prints five ✓ steps (login → tournament lookup → seeding → round start → round result)'.

**`table_reservation_heating_control.de.md`**

- `[DRIFT·medium]` Vorheizzeit Match Billard / Snooker = 3 Stunden (Regel 1, System-Parameter, Beispiel ab 15:00)
- `[DRIFT·medium]` Event-Window: Events werden bis zu 3 Stunden im Voraus geprüft

**`table_reservation_heating_control.en.md`**

- `[DRIFT·high]` Heaters deactivated if no Scoreboard activity 'for one hour' after reservation start / without reservation
- `[DRIFT·medium]` Heaters activated 2 hours (3 hours for match billards) before a reservation

**`tischreservierung_heizungssteuerung.de.md`**

- `[DRIFT·high]` Heaters on 2 hours before reservation; off if no activity 'for one hour'

**`tischreservierung_heizungssteuerung.en.md`**

- `[DRIFT·high]` Same as tischreservierung_heizungssteuerung.de.md (file is mislabeled — contains German content identical to the .de.md sibling)

### Batch 3b — administrators/ (Server-/Deployment-/Streaming-/Raspi-Ops)

**`docs/administrators/MIGRATION_NEW_TO_PRODUCTION_DOMAINS.de.md`**

- `[DRIFT·high]` bundle exec rails prepare_development (to auto-update config from master)

**`docs/administrators/index.de.md`**

- `[DRIFT·medium]` Links to installation-overview.de.md#cloud-hosting (x2), #on-premise (x2), #sicherheit

**`docs/administrators/index.en.md`**

- `[DRIFT·medium]` Links to installation-overview.en.md#cloud-hosting (x2), #on-premise (x2), #security

**`docs/administrators/installation-overview.de.md / .en.md`**

- `[DRIFT·high]` rake "scenario:setup[carambus_location_5101,development]" to set up the development environment
- `[DRIFT·high]` rake "scenario:create[carambus_location_5101]" to create a new scenario
- `[DRIFT·medium]` Service status check: systemctl status puma-carambus
- `[DRIFT·medium]` Production deployment is done via a single rake "scenario:deploy[...]" command

**`docs/administrators/raspberry-pi-client.en.md`**

- `[DRIFT·low]` EN integration link annotated '(German only for now)'

**`docs/administrators/raspberry-pi-quickstart.de.md, docs/administrators/raspberry-pi-quickstart.en.md`**

- `[DRIFT·high]` rake "scenario:deploy_complete[carambus_bcw]" performs the full one-shot deployment (quickstart Step 3.2 + 'COMPLETE WORKFLOW SUCCESSFUL' expected-output block)
- `[DRIFT·high]` Base server provisioning via: ansible-playbook -i ansible/inventory/production.yml ansible/playbooks/raspberry_pi_server.yml (quickstart Step 2.1)
- `[DRIFT·medium]` rake "scenario:deploy[carambus_bcw,production]" (Update Application Code section)

**`docs/administrators/raspberry_pi_client_integration.de.md, docs/administrators/raspberry_pi_client_integration.en.md`**

- `[DRIFT·medium]` Scoreboard URL = http://host:port/locations/<md5>?sb_state=welcome (integration doc URL example + embedded Ruby snippet)

**`docs/administrators/raspberry_pi_scripts.{de,en}.md`**

- `[DRIFT·high]` bin/install-scoreboard-client.sh installs scoreboard client software

**`docs/administrators/server-scripts.{de,en}.md`**

- `[DRIFT·high]` Rails console wrappers bin/console-api.sh, bin/console-local.sh, bin/console-production.sh exist and are runnable
- `[DRIFT·high]` bin/debug-production.sh <scenario_name> collects production debug info and is runnable

**`docs/administrators/streaming-comparison.de.md`**

- `[DRIFT·medium]` Support-Liste verweist auf Repo-Datei `STREAMING_OVERLAY_README.md` - Overlay-System.
- `[GAP·low]` Alle Streaming-Ansaetze streamen '-> YouTube RTMP'; das Dokument beschreibt nur YouTube als Ziel.
- `[GAP·low]` Beispiel-Views app/views/locations/scoreboard_overlay_multi.html.erb und _scoreboard_compact.html.erb (Multi-Table 2x2 Grid).

**`docs/administrators/streaming-consolidation-testing-guide.md`**

- `[DRIFT·high]` Streaming software installed via `rake streaming:setup_raspi`
- `[DRIFT·medium]` Local RTMP stream URL is `rtmp://<ip>:1935/live/table<id>` (OBS Media Source input, ffplay test commands, multi-stream table)

**`streaming-setup.de.md / streaming-setup.en.md`**

- `[DRIFT·medium]` Overlay/scoreboard URL uses query param `?table=1` (in troubleshooting curl example and Quick Reference 'Overlay-Vorschau/Overlay Preview').
- `[DRIFT·medium]` Admin config 'Basis-Einstellungen / Basic Settings' presents only a 'YouTube-Konfiguration / YouTube Configuration' block (Stream-Key, Channel-ID). Implies YouTube is the only destination.
- `[DRIFT·medium]` Document title and Overview frame the feature as 'YouTube Live Streaming ... directly to YouTube'.

## Bewusst zurückgestellt (niedrig / out-of-scope)

- `Batch 2` `docs/internal/performance-analysis/PERFORMANCE_MEASUREMENT_GUIDE.md` — Client log format: '⚡ Performance [#full_screen_table_monitor_50000001]: { network: "125ms", dom: "1234ms", total: "1359ms" }'
- `Batch 3b` `docs/administrators/streaming-production-deployment.md` — Architecture/overlay mechanism: Pi runs a background curl to the scoreboard_text endpoint every 1 second and feeds an FFmpeg drawtext filter; key file locati…
- `Batch 3b` `docs/administrators/streaming-production-deployment.md` — Manual Pi config file keys: YOUTUBE_KEY, CAMERA_*, OVERLAY_WIDTH, TABLE_ID, TABLE_NUMBER, LOCATION_MD5, SERVER_URL.
- `Batch 3b` `CODE BUG (not documented in either file)` — admin/stream_configurations#deploy_all (route collection POST deploy_all) enqueues StreamDeployJob.perform_later

## Verbleibende Code-Punkte → an PAUL übergeben (TDD)

Diese sind reine Code-Bugs (keine Doku); Handoff: `carambus_gu/.paul/handoffs/HANDOFF-2026-06-08-code-fixes-from-docs-audit.md`.

1. **`StreamDeployJob` fehlt** → `deploy_all` wirft NameError (`config/routes.rb:544`, `admin/stream_configurations_controller.rb:127`). Job implementieren oder tote Route/Action entfernen.
2. **`Shot include Translatable` ohne `source_language`-Spalte** (`app/models/shot.rb:2`, `translatable.rb:5`). `shots` hat bereits das `_de/_en`-Muster → Fix-Richtung: Spalte ergänzen.
3. **`Table#pre_heating_time_in_hours` Token-Bug** (`app/models/table.rb:225`): `%w[Match Billard Snooker]` statt `["Match Billard", "Snooker"]` → Match-Billard-Tische bekommen 2h statt 4h.

_Nicht (mehr) zu tun:_ MCP-Tool-Registry-Smoke-Test ist synchron (EXPECTED_TOOL_NAMES = 23 = reale Tools). Das Cheatsheet `docs/managers/clubcloud-scenarios/meldeliste-finalisieren.de.json` (falsche Parameternamen) ist ein kleiner Doc-Artefakt-Fix, offen.

## Wichtige Einordnung (graphify-Caveat)

Der graphify-Wissensgraph ist eine **Landkarte/Discovery-Hilfe, kein Drift-Detektor**: seine `INFERRED`-Kanten (besonders `calls`) sind verrauscht und blähen God-Node-/Bridge-Rankings auf (an `Current`/`Game` verifiziert — Phantom-Edges; die echten Kopplungen stehen in den ActiveRecord-Assoziationen). Der belastbare Abgleich gelang nur durch Ground-Truth-Prüfung gegen den Code. Für Rails gilt: nur `EXTRACTED`-Struktur + echtem Code trauen.
