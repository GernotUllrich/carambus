# Carambus API — Troubleshooting- & Interventions-Guide

Nachschlagewerk für den **Betrieb des Authority-Servers** (`api.carambus.de`).
Tritt ein Sonderfall/Problem auf, findet man hier schnell das passende
rake-Task oder `bin/*.sh`-Script — sortiert nach Problembereich.

> Bewusst **nicht** in `docs/` (nicht Teil der öffentlichen mkdocs-Site) —
> nur über das Repo zugänglich.

> 🌐 **Gerenderte, navigierbare Fassung** (Sidebar-TOC + Live-Filter, privat):
> <https://claude.ai/code/artifact/73a33b4e-7b55-4a70-afe4-c2f33a167e97>
> — oder in der Artifact-Galerie: <https://claude.ai/code/artifacts>.

Task-Namen ohne `bin/rails`-Präfix, nur `namespace:task`. Aufruf lokal per
`bin/rails <task>` bzw. `bundle exec rake <task>`.

---

## Konventionen (zuerst lesen)

- **dry-run vs ARMED** — Import-/Schreib-Tasks (LigaManager, NuLiga u.a.) laufen
  per Default als **dry-run** (Report, keine Änderung) und schreiben erst mit
  `ARMED=1`. Manche Cleanup-Tasks nutzen `WRITE=true` bzw. `DRY=1`/`DRY_RUN=true`.
  **Immer zuerst dry-run**, Report prüfen, dann scharf schalten.
- **Prod ausführen** — `ssh -p 8910 www-data@api.carambus.de`, dann:
  ```bash
  export PATH=/var/www/.rbenv/shims:$PATH && \
  cd /var/www/carambus_api/current && \
  RAILS_ENV=production bundle exec rake <task>
  ```
  Die nicht-interaktive ssh-Shell hat rbenv **nicht** im PATH — der `export` ist nötig.
- **Prod-Backup + Dev-Spiegel** — aus dem `carambus_master`-Checkout:
  ```bash
  rake 'scenario:sync_production_db[carambus_api]'
  ```
  Erzeugt einen **Prod-Dump** (Restore-Punkt) UND frischt `carambus_api_development`
  als Prod-Spiegel auf (drop/create/restore). Kanonischer Weg — kein manuelles `pg_dump`.
- **Cron** — aus `~/DEV/carambus/carambus_api`:
  ```bash
  bundle exec cap production whenever:clear_crontab    # aus
  bundle exec cap production whenever:update_crontab   # an
  ```
  Betrifft nur den carambus_api-Block.
  ⚠️ **`cap production deploy` ruft `whenever:update_crontab` automatisch mit auf →
  reaktiviert den Cron.** Nach einem Deploy ggf. erneut `clear_crontab`.
- **Scenario-Management (Pflicht bei Code-Änderungen)** — KEINE Edits ohne
  Mode-Deklaration (`start master mode` ODER
  `start feature branch mode <topic> in <scenario>`).
  Siehe `.agents/skills/scenario-management/SKILL.md`.
- **Global vs Local Records** — `id < 50_000_000` (`MIN_ID`) = **global**
  (Authority→Regional-Sync via PaperTrail); `id >= MIN_ID` = **local**.
  `LocalProtector` schützt globale Records vor Änderung auf Local-Servern —
  destruktive Cleanup-/Import-Tasks daher grundsätzlich auf der **Authority** laufen lassen.
- **Runbooks/Memories** — für spezielle Vorfälle (CC-Saison-Rollover-Kontamination,
  Prod-Cutover TBV/LigaManager, UMB-Parallel-Scrape-Kollision) siehe `.paul/`-Runbooks
  und die Auto-Memory unter `~/.claude/projects/.../memory/`.

---

## 1. Scraping & externe Quellen

### ClubCloud / CC (`cc:*`, `clubcloud:*`, `scrape:*`)

Zentraler CC-Scrape läuft über den `scrape:`-Namespace (Monitoring bevorzugt).

| Task | Was | Wann/Hinweis |
|---|---|---|
| `scrape:daily_update_monitored` | Täglicher CC-Update **mit Monitoring** | **Empfohlener** Standard-Scrape; Cron-Ziel |
| `scrape:daily_update` | Täglicher CC-Update (ohne Monitoring) | Fallback / manuell |
| `scrape:optimized_daily_update` | Nur Änderungen seit letzter Synchronisation | schneller Inkrement-Scrape |
| `scrape:scrape_clubs` / `scrape:scrape_clubs_optimized` | Vereine scrapen | |
| `scrape:scrape_leagues_optimized` | Ligen scrapen (optimiert) | |
| `scrape:scrape_tournaments_optimized` | Turniere scrapen (optimiert) | |
| `scrape:update_seasons` | Saisons aktualisieren | bei Saison-Rollover |
| `scrape:check_health` | Scraping-Gesundheit / Anomalien prüfen | erste Diagnose bei Verdacht |
| `scrape:recent_errors` | Letzte Scraping-Errors zeigen | |
| `scrape:stats[operation]` | Scraping-Statistiken | opt. `operation_name` |
| `scrape:export_stats[since_days]` | Statistiken als CSV exportieren | |
| `scrape:cleanup_logs[keep_days]` | Alte Scraping-Logs löschen | Default 90 Tage |
| `scrape:analyze_duplicates` | Duplikat-Turniere je Region/Saison analysieren | read-only Analyse |
| `scrape:fix_tournament_cc_associations` | Falsche tournament_cc-Zuordnungen korrigieren | |
| `scrape:list_abandoned_tournaments` | Verwaiste Turniere auflisten | |
| `scrape:mark_tournament_abandoned` / `scrape:mark_abandoned_simple` | tournament_cc als „abandoned" markieren | |
| `scrape:cleanup_abandoned_tournaments` | Alte abandoned tournament_cc-Records aufräumen | |
| `cc:synchronize_everything` | Komplette CC-Struktur synchronisieren | Voll-Sync (teuer) |
| `cc:synchronize_*_structure` | Einzelne CC-Strukturen (region/season/club/league/team/party/party_game/group/category/branch/discipline/competition/championship_type/tournament/tournament_series/registration_list/game_plan/league_plan/league_team/team_players) | gezielter Teil-Sync |
| `cc:synchronize_game_details` | Spieldetails synchronisieren | |
| `cc:scrape_cc_tournament_structure` | CC-Turnierstruktur scrapen | |
| `cc:fix_tournament_structure` | Turnierstruktur reparieren | |
| `cc:delete_tournament_results` | Turnierergebnisse löschen | destruktiv |
| `cc:upload_tournament_results` | Turnierergebnisse zu CC hochladen | Schreibt nach extern |
| `cc:release_registration_list_structure` | Meldeliste freigeben | |
| `cc:remove_duplicate_players` | Doppelte Player entfernen | |
| `cc:remove_local_objects` | Lokale Objekte entfernen | |
| `cc:login_to_cc` / `cc:logoff_from_cc` | CC-Login/-Logoff | `login_to_cc` [DEPRECATED Plan 21-11] |
| `clubcloud:scrape_admin_params[region,season]` | 4 Admin-Params (shot_clock/points_to_win/best_of/plan) aus `showMeisterschaft.php` in `tournament_ccs` | Plan 21-03 |

CC-Credentials-Setup/Test: `bin/setup-cc-credentials.sh`, `bin/test-cc-login.sh`.

### NuLiga — BBV (`nu_liga:*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `nu_liga:compare_bbv` | Struktur-/Deckungs-Abgleich Carambus↔NuLiga (Clubs/Ligen/Teams/Player), **read-only** | ENV `FEDERATION=BBV REGION_ID=3 SEASON_ID=17 BRANCHES=Pool,Snooker` |
| `nu_liga:import_bbv` | Struktur-/Ergebnis-Import NuLiga→Carambus | **dry-run default; `ARMED=1` schreibt.** ENV `REGION_ID=3 BRANCHES=…`; Saison via `SEASONS=14,15,16,17` (Multi) oder `SEASON_ID=`. ⚠️ Ohne Saison-Angabe → `current_season` (auf re-synctem Dev außerhalb der NuLiga-Range) → **explizit `SEASONS` setzen** |

### LigaManager — TBV (`liga_manager:*`)

TBV läuft seit dem Cutover (2026-07-15) live über LigaManager (ersetzt den CC-Scrape für TBV).

| Task | Was | Wann/Hinweis |
|---|---|---|
| `liga_manager:compare_tbv` | Struktur-Abgleich CC↔LM (Clubs/Ligen/Teams), **read-only** | ENV `ASSOCIATION_ID=1 REGION_ID=16 SEASON_ID=17` |
| `liga_manager:compare_tbv_results` | Ergebnis-Abgleich (Begegnungen + Mannschaftsergebnisse), **read-only** | gleiche ENV |
| `liga_manager:import_structure` | Struktur-Import LM→Carambus (Clubs/Ligen/Teams source_url, Seedings, Parties, Einzelspiele) | **dry-run default; `ARMED=1` schreibt.** ENV `ASSOCIATION_ID=1 REGION_ID=16 SEASON_ID=` (ohne → current). Nur Authority. cc_id/ba_id/dbu_nr unangetastet |
| `liga_manager:daily_import` | Laufender TBV-Import (ARMED fix, current season) | **Cron-Ziel-Task**; TBV=assoc 1/region 16; Saison rollt automatisch |
| `liga_manager:check_game_plans` | **READ-ONLY** Abgleich bestehender GamePlans gegen LM-Struktur | erwartet 0 Diskrepanzen; ENV `REGION_ID=16 SEASON_ID=17`. Bewusst **kein** Rekonstruieren |
| `liga_manager:fix_club_identity` | Kuratierter Club-Identitäts-Fix `cc_id=asso_no` (z.B. SV Sömmerda→1567) | **dry-run default; `ARMED=1` schreibt** |
| `liga_manager:reconstruct_game_plans` | GamePlan-Rekonstruktion aus Carambus-Spieldaten | dry-run default; `ARMED=1`. ⚠️ saisonweit/alle Regionen — Footgun |

### UMB (`umb:*`)

International (UMB Cuesco/Five&Six). UMB = Region 25. ⚠️ carambus.de kann lokale UMB-Turniere
(50000001+) haben, die mit dem Authority-Sync über `shortname` kollidieren — siehe Memory.

| Task | Was | Wann/Hinweis |
|---|---|---|
| `umb:status` | Umfassender UMB-Statusreport | erste Diagnose |
| `umb:stats` / `umb:discipline_stats` | UMB-Statistiken / Disziplin-Statistik | |
| `umb:check_new` | Schnellcheck auf neue UMB-Turniere (neueste IDs) | |
| `umb:update` | Inkrementeller UMB-Update | Standard-Update |
| `umb:import_all` | Alle gültigen UMB-Turniere importieren (neueste zuerst) | |
| `umb:scrape_future` | Zukünftige UMB-Turniere scrapen | |
| `umb:scrape_archive[start_id,end_id]` | UMB-Archiv nach ID-Range | |
| `umb:scrape_details[start_id,end_id]` | Details + Spielergebnisse sequenziell | |
| `umb:scrape_all_details` | Details für alle UMB-Turniere | |
| `umb:scrape_all_historical[max_id]` | Voller sequenzieller Scan | teuer |
| `umb:scrape_tournament_details[tournament_id]` | Details eines Turniers | |
| `umb:rescrape_missing_locations` | Turniere ohne location_id neu scrapen | |
| `umb:fix_tournaments` | Fehlende location_id/season_id fixen | |
| `umb:fix_disciplines` / `umb:fix_organizers` / `umb:fix_locations` | Disziplinen/Organizer/Locations korrigieren | `fix_locations` z.B. „A" aus N/A-Parsing |
| `umb:debug_import[ids]` | Debug-Import für bestimmte IDs | |
| `umb:test_scrape[external_id,parse_pdfs]` | Einzelnes Turnier testweise scrapen | |
| `umb:test_improvements` | Scraper-Verbesserungen testen (Disziplin/Knockout) | |
| `umb:setup` | UMB-Infrastruktur (Organizer-Region anlegen) | einmalig |

### Cuesco / Five&Six (`cuesco:*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `cuesco:scrape_live` | Live/aktuelle Turniere+Spiele scrapen und syncen | |
| `cuesco:scrape_tournament[tournament_id,cuesco_idx]` | Bestimmtes Turnier direkt scrapen | |

### DBU / regionale Scrapes (`carambus:scrape_*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `carambus:scrape_dbu_leagues` | DBU-Ligen scrapen | |
| `carambus:scrape_leagues` | Ligen scrapen | |
| `carambus:scrape_tournaments` | Turniere scrapen | |
| `carambus:scrape_new_tournaments` | Neue Turniere scrapen | |
| `carambus:scrape_regional_club_ids` | Regionale Club-IDs scrapen | |

---

## 2. Sync, Replikation & Szenarien

### Szenarien (`scenario:*`)

Multi-Tenant-Deployment (mehrere Checkouts). Meiste Tasks nehmen `[scenario_name]`, oft `[…,environment]`.

| Task | Was | Wann/Hinweis |
|---|---|---|
| `scenario:list` | Verfügbare Szenarien auflisten | |
| `scenario:sync_production_db[scenario_name]` | **Prod-DB → lokale Dev-DB** (Dump erzeugen + drop/create/restore) | **Prod-Backup + Dev-Spiegel** in einem Schritt; aus `carambus_master` |
| `scenario:create_database_dump[name,env]` | DB-Dump erzeugen | |
| `scenario:restore_database_dump[name,env]` | DB-Dump zurückspielen | |
| `scenario:reset_server_db[name]` | **DESTRUKTIV**: Server-DB zurücksetzen + neu befüllen | Migrations + Dump + DB-Reset auf Server |
| `scenario:prepare_development[name,env]` | Dev vorbereiten (Config + DB + Rails-Root) | |
| `scenario:prepare_deploy[name]` | Deploy vorbereiten (Config, DB, Transfers, Server) | |
| `scenario:deploy[name]` | Deploy (reines Capistrano + Service-Mgmt) | |
| `scenario:quick_deploy[name]` | Nur Code-Deploy ohne Config-Regenerierung | schnell |
| `scenario:update[name]` | git pull (bewahrt local changes) | |
| `scenario:generate_configs[name,env]` | Config-Dateien generieren | aus `carambus_data/scenarios/` |
| `scenario:generate_credentials[name,env]` | Verschlüsselte Credentials generieren/mergen | |
| `scenario:push_credentials[name]` | Soft-Credentials additiv auf Server mergen | dry-run default; `WRITE=true` (+`RESTART=true`); bewahrt secret_key_base/AR/devise_jwt |
| `scenario:configure_rails_app[name,env,ssh_host,ssh_port]` | Rails-App für Prod konfigurieren | |
| `scenario:create[name,location_id,context]` | Neues Szenario anlegen | |
| `scenario:create_rails_root[name]` | Rails-Root-Ordner anlegen | |
| `scenario:check_compatibility[name]` | Kompatibilität + local data prüfen | |
| `scenario:backup_local_data[name]` / `scenario:restore_local_data[name,backup_file]` | Local data von/zu Server sichern/zurückspielen | |
| `scenario:get_location_md5[name]` | MD5-Hash der Location | |
| `scenario:sync_nginx_conf[name,env]` | nginx.conf auf Server syncen | → `/etc/nginx/sites-available/<name>` |
| `scenario:install_bot_block[name,env]` | `carambus_bot_block.conf` auf Server installieren | Bot-/Scraper-Abwehr |
| `scenario:list_table_scoreboards[name]` | Tische + IP-Adressen listen | |
| `scenario:setup_raspberry_pi_client[name]` / `scenario:deploy_raspberry_pi_client[name]` / `scenario:restart_raspberry_pi_client[name]` / `scenario:test_raspberry_pi_client[name]` | Raspberry-Pi-Client Setup/Deploy/Restart/Test | Scoreboard-Kiosk |
| `scenario:restart_table_scoreboard[name,table_name]` | Einzelnes Scoreboard-Kiosk neustarten | |
| `scenario:preview_autostart_script[name]` | Autostart-Script anzeigen | |

### Deployment-Modi & Templates (`mode:*`, `data:*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `mode:status[detailed,source]` | Aktuellen Modus zeigen | |
| `mode:help` | Hilfe zu den mode-Named-Parametern | |
| `mode:api` / `mode:local` / `mode:local_dev` | Nach API- / LOCAL- / LOCAL-DEV-Modus wechseln | named params |
| `mode:save[name]` / `mode:load[name]` / `mode:list` | Konfiguration speichern/laden/listen | |
| `mode:backup` | Backup der aktuellen Konfiguration | |
| `mode:backup_local_changes` / `mode:restore_local_changes[backup_file]` | Local changes (ID > 50 Mio) vor/nach DB-Ersatz sichern | |
| `mode:prepare_deployment` / `mode:full_deploy` | Deploy-Vorbereitung / komplette Ausführung | |
| `mode:prepare_db_dump` / `mode:deploy_db_dump[dump_file]` / `mode:restore_db_dump[dump_file]` | DB-Dump vorbereiten/deployen/restoren (Prod) | mit Safety-Check |
| `mode:download_db_dump` / `mode:list_db_dumps` | Prod-Dump herunterladen / Dumps listen | |
| `mode:restore_local_db[dump_file]` | Lokale Dev-DB aus Prod-Dump (drop+replace) | |
| `mode:restore_local_db_with_preservation[dump_file]` | … mit Erhalt der local changes | |
| `mode:restore_local_db_with_region_reduction[dump_file]` | … mit Region-Reduktion | |
| `mode:check_version_safety[dump_file]` | Version-Sequenznummern auf Sicherheit prüfen | vor Restore |
| `mode:generate_templates` / `mode:copy_templates` / `mode:deploy_templates` | Templates generieren/kopieren/deployen | |
| `mode:pre_deploy_status` / `mode:post_deploy_status` / `mode:validate_deployment` | Pre-/Post-Deploy-Validierung | |
| `mode:deploy_config` | DEPLOYMENT-Configs generieren | |
| `data:deploy` / `data:generate_templates` / `data:set_directory[env]` | Aus/in externes Data-Directory | |
| `data:convert_yaml_to_json` | Restliche YAML-kodierte Game-Daten → JSON | einmalige Konvertierung |

### PaperTrail-Version-Sync (`version_cleanup:*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `version_cleanup:copy_region_data_sql` | region_id/global_context von Items → Versions kopieren (SQL) | **schnellster** Weg |
| `version_cleanup:copy_region_data` | dito (Ruby-basiert) | langsamer |
| `version_cleanup:stats` | Statistik über Version-Region-Daten | |
| `version_cleanup:verify` | Prüfen, ob alle Versions korrekte Region-Daten haben | |

### Weitere Sync/Update (`carambus:*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `carambus:retrieve_updates` | Updates vom API-Server holen | Local-Server-Seite |
| `carambus:update_carambus` | Carambus aktualisieren | |
| `carambus:filter_local_changes_from_sql_dump` / `carambus:filter_local_changes_from_sql_dump_new` | Local changes aus SQL-Dump filtern (Alt-/Neu-Variante) | vor Prod-Restore |

---

## 3. Daten-Bereinigung & Korrekturen

### Cleanup (`cleanup:*`, `party_cleanup:*`)

⚠️ `cleanup:*`-Tasks wirken **direkt** (kein dry-run) und löschen abhängige Daten — auf der **Authority** laufen lassen, vorher Backup (`scenario:sync_production_db`).

| Task | Was | Wann/Hinweis |
|---|---|---|
| `cleanup:remove_non_region_records` | Records ohne Region des Local-Servers entfernen | Region-Reduktion |
| `cleanup:remove_duplicate_games` | Doppelte Games entfernen (behält beste/früheste) | |
| `cleanup:cleanup_paper_trail_versions` | PaperTrail-Versions mit reinen Timestamp-Änderungen entfernen | Ballast |
| `cleanup:remove_regional_league_duplicates` | Regionale Liga-Duplikate bei gleichnamiger DBU-Liga entfernen | löscht abh. Parties/PartyGames/LeagueTeams |
| `cleanup:remove_bundesliga_regionalliga_non_dbu` | Bundesliga/Regionalliga mit Organizer≠DBU entfernen | löscht abh. Daten |
| `cleanup:remove_dbu_leagues_without_cc_id` | DBU-Ligen mit `cc_id=nil` entfernen | inkl. abh. Daten |
| `cleanup:parties` | Parties mit nil-Team-Refs + Duplikate aufräumen | |
| `cleanup:club_locations` | Doppelte ClubLocation-Records (behält neueste) | |
| `party_cleanup:phantoms` | Phantom-Duplikat-Parties (leere Dubletten je Termin) entfernen | **DRY-RUN default; `WRITE=true` führt aus**; `LEAGUE_ID=` grenzt ein; nur Authority. ⚠️ zuerst Scraper-Idempotenz-Fix deployen |

### Region-Tagging (`region_taggings:*`)

Scrape-Zeit-Tagging ist kanonisch. Re-Tag-Tasks (`update_all`/`set_global_context`/`update_existing_versions`)
sind **geguardet** (Recurrence-Schutz), weil sie kuratierte globale Taggung (dt. LV 1–17, DBU=17, UMB=25) herunterreißen.

| Task | Was | Wann/Hinweis |
|---|---|---|
| `region_taggings:update_all_region_id` | **Kanonische** DE-Region-Taggung (org. Abhängigkeit top-down) | Source of Truth. Danach zwingend `fix_international_organizer_context ARMED=1 REDELIVER_CHILDREN=1` |
| `region_taggings:fix_international_organizer_context` | Int. Organizer-Regions `global_context=true` + hängende int. Turniere/Ligen redelivern | **dry-run default; `ARMED=1`; `REDELIVER_CHILDREN=1`**. Nur Authority; PaperTrail muss aktiv sein |
| `region_taggings:verify` | Region-Taggung verifizieren | read-only |
| `region_taggings:update_all` | ⚠️ **GEGUARDET** (derivation-basiert, reißt Taggung herunter) | nur mit `FORCE_DERIVATION_RETAG=1` — normalerweise NICHT nutzen |
| `region_taggings:set_global_context` | ⚠️ **GEGUARDET** | dito |
| `region_taggings:update_existing_versions` | ⚠️ **GEGUARDET** | dito |

### Placeholder-Records (`placeholders:*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `placeholders:stats` | Statistik zur Placeholder-Nutzung | |
| `placeholders:list_incomplete` | Records mit Placeholder-Referenzen listen | |
| `placeholders:check_suspicious` | Verdächtige Placeholder-Nutzung (first-record-IDs) | |
| `placeholders:create` | Placeholder-Records für fehlende Referenzen anlegen | |
| `placeholders:migrate_to_placeholders` | `.first`-Records auf Placeholder umstellen | |
| `placeholders:fix_interactive` | Unvollständige Records interaktiv fixen | |
| `placeholders:auto_fix_disciplines` | Disziplin aus Turniertitel auto-fixen | |

### Disziplinen (`disciplines:*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `disciplines:backfill_from_title` | Unbranchten Turnieren exakte Disziplin aus Titel zuweisen | discipline_id nil / „Unknown Discipline" |
| `disciplines:extend_title_synonyms` | Titel-Synonyme an Disziplinen ergänzen (idempotent) | **DRY-RUN default; `ARMED=1` mutiert** |

### SeasonParticipations

⚠️ Copy-Task erzeugt „temporary"-Records, die der CC-Scrape nie aufräumt — siehe Memory.

| Task | Was | Wann/Hinweis |
|---|---|---|
| `season_participations:copy_to_next_season[from,to]` | SeasonParticipations 2025/26 → 2026/27 kopieren | sync_date = heute 16:00 |
| `carambus:copy_season_participations_to_next_season` | dito (carambus-Variante) | |
| `carambus:remove_duplicate_season_participations` | Doppelte SeasonParticipations entfernen | |

### Player-Duplikate (`players:*` merge)

Mehrstufiger Merge-Prozess (Phase 2–5). Vorher `players:analyze_duplicates`, danach `players:verify_merges`.

| Task | Was | Wann/Hinweis |
|---|---|---|
| `players:analyze_duplicates` | Player-Duplikate im Detail analysieren | read-only, zuerst |
| `players:merge_clean_duplicates` | Phase 2: saubere Duplikate mergen (1 Master, N mit ba_id>999000000) | |
| `players:merge_multiple_masters` | Phase 3: mehrere Master-Kandidaten | |
| `players:merge_without_master` | Phase 4: ohne Master-Kandidat | |
| `players:merge_safe_remaining` | Phase 5: verbleibende sichere Fälle | |
| `players:verify_merges` | Merges verifizieren (orphaned assoc / broken refs) | danach |

### Weitere Korrekturen (`carambus:*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `carambus:check_consitency` | DB-Konsistenz prüfen | Diagnose |
| `carambus:eliminate_location_duplicates` | Location-Duplikate entfernen | |
| `carambus:generate_locations` | Locations generieren | |
| `carambus:fix_game_participations` | GameParticipations reparieren | |
| `carambus:fix_tournament_discipline_by_name` | Turnier-Disziplin nach Name fixen | |
| `carambus:update_disciplines_in_party_games` | Disziplinen in PartyGames aktualisieren | |
| `carambus:init_disciplines` | Disziplinen initialisieren | einmalig/Setup |
| `carambus:create_countries` | Länder anlegen | einmalig/Setup |

### Ad-hoc (`adhoc:*`)

Grab-bag für Einmal-Interventionen — vor Nutzung kurz die `.rake`-Quelle prüfen.

| Task | Was |
|---|---|
| `adhoc:find_orphaned_club_ids` | club_ids aus season_participations ohne Club finden |
| `adhoc:fix_season_participations` | SeasonParticipations fixen |
| `adhoc:fix_source_urls` | source_urls fixen |
| `adhoc:sequence_reset` | Sequence-Reset |
| `adhoc:populate_tables` | Tische befüllen |
| `adhoc:list_module_types` | module_type-Häufigkeiten listen |
| `adhoc:player_cc_matching` | Spielerabgleich mit CC |
| `adhoc:player_from_seeding_data` | Player aus Seeding-Daten |
| `adhoc:scrape_downloads` / `adhoc:scrape_ndbv_de` / `adhoc:scrape_ndbv_de_images` | NDBV-Downloads/Website/Images scrapen |
| `adhoc:test` / `adhoc:test_old` / `adhoc:test_setting` / `adhoc:test_add_tournament` / `adhoc:test_version_update` | Diverse Einmal-Tests |
| `adhoc:test_league8` / `adhoc:test_league_scraping` | Liga-Scraping-Experimente (test_league 8 / Liga-Scraping) |
| `adhoc:clean_local` | ⚠️ **Wegwerf/experimentell**: löscht ALLE local records (id>50 Mio) für TournamentMonitor/TableMonitor/Game/GameParticipation/Account/User | destruktiv — nur bewusst auf Dev |
| `adhoc:test_ko_plans` | Experiment: `TournamentPlan.ko(20)` | Wegwerf |
| `adhoc:test_player_id_from_ranking` | Experiment: `TournamentMonitor#player_id_from_ranking` an Beispiel-Turnier | Wegwerf |
| `adhoc:test_accumulate_results` | Experiment: `TournamentMonitor#accumulate_results` an Beispiel-Turnier | Wegwerf |

---

## 4. Spieler: Klassen / Alter / Identität

Kontext: `ba_id` zentral (BA/DBU), `cc_id` regionsspezifisch, `Player#dbu_nr` eindeutig — siehe Memory.

| Task | Was | Wann/Hinweis |
|---|---|---|
| `player_class:calculate[region_shortname]` | PlayerRanking.player_class_id aus max(btg) der 2 abgeschl. Vorsaisons (STO-BTK §1.4) | ENV `DRY=1` für dry-run |
| `tournaments:backfill_player_class` | Tournament#player_class aus Titel backfillen | `DRY_RUN=true` für Preview |
| `players:heuristic_age_class_gender[region]` | age_class/gender-Heuristik aus Seedings/category_ccs | Plan 21-04, NBV-Pilot |
| `carambus:init_player_classes` | PlayerClass initialisieren | einmalig/Setup |
| `carambus:read_regional_player_ids` | Regionale Player-IDs lesen | |
| `user:export[email,outfile]` | User in portable JSON exportieren | User-Transfer |
| `user:import[file]` | User aus JSON importieren | ENV `ON_CONFLICT=abort\|update\|skip` |
| `users:purge_unconfirmed[older_than_days]` | Unbestätigte Bot-/Karteileichen-Accounts löschen | Default 7 Tage |
| `service_accounts:create[region_shortname]` | Regionalen Sync-Service-Account anlegen/rotieren | |
| `service_accounts:create_carambus_app[region_shortname]` | carambus-app-bridge-Service-Account (External-Tournament-Bridge) | |

---

## 5. Turniere & GamePlans

### GamePlans (`carambus:*reconstruct*`, `carambus:*game_plan*`)

⚠️ GamePlan ist saisonstabil (ändert sich CC→LM nicht) — bevorzugt nur read-only prüfen (siehe Memory).
`reconstruct_game_plans` (ohne Args) wirkt saisonweit/alle Regionen — Footgun.

| Task | Was | Wann/Hinweis |
|---|---|---|
| `carambus:reconstruct_game_plans[season_name,region_shortname,discipline]` | GamePlans aus vorhandenen Daten rekonstruieren | gezielt mit Args |
| `carambus:clean_reconstruct_game_plans[season,region,discipline]` | Clean + Reconstruct für eine Saison | |
| `carambus:delete_game_plans[season,region,discipline]` | GamePlans löschen | destruktiv |
| `carambus:reconstruct_league_game_plan[league_id]` | GamePlan einer Liga rekonstruieren | präzise, ungefährlich |

### Tournament-Plans (`tournament_plans:*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `tournament_plans:analyze` | Alle Tournament-Plans + Gruppierungs-Algorithmen analysieren | |
| `tournament_plans:validate_executor_params` | executor_params-Konsistenz prüfen | |
| `tournament_plans:fix_executor_params[plan_names]` | executor_params-Tabellenkonflikte auto-fixen | |
| `tournament_plans:test_grouping[plan_name]` | Gruppierungs-Algorithmus testen | |
| `carambus:update_executor_params` | tournament_plan executor_params aktualisieren | |

### Seeding-Versions (`tournament:*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `tournament:check_seeding_versions[tournament_id]` | Problematische Version-Records finden (löschen Seedings) | Diagnose |
| `tournament:cleanup_seeding_versions[tournament_id]` | Problematische destroy-Version-Records aufräumen | Fix |

### KO-Turniere (`ko:*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `ko:generate_plan[nplayers]` | KO-Turnierplan für N Spieler generieren | |
| `ko:inspect[tournament_id]` | KO-Turnierstruktur inspizieren | |
| `ko:test_tournament_17405` | KO-Test mit Tournament[17405] | Referenz-Test |

### External-Tournament-Bridge (`external_tournament:*`)

Lokale App-Turniere (TableMonitor-Welt). ⚠️ TableMonitor-Refactoring gehört in `carambus_nbv`, nicht hier (siehe Memory).

| Task | Was | Wann/Hinweis |
|---|---|---|
| `external_tournament:end[tournament_id]` | Sysadmin: lokales App-Turnier beenden + Tische freigeben | manueller Eingriff |
| `external_tournament:release_stale_local_tables` | Mitternachts-Auto-Abbruch + GC hängender Tische/Turniere | Cron |
| `external_tournament:smoke_test[region_shortname]` | Bridge-Endpoints smoke-testen | Diagnose |

### Weitere Turnier-Ops (`carambus:*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `carambus:update_tournaments` | Turniere aktualisieren | |
| `carambus:update_ranking_tables` | Ranking-Tabellen aktualisieren | |
| `carambus:auto_reserve_tables` | Tische für anstehende Turniere nach Meldeschluss auto-reservieren | |
| `carambus:check_reservations` | Reservierungen via Google Calendar 'BC Wedel' prüfen | |
| `carambus:delete_non_conforming_calendar_entries` | Nicht-konforme Kalender-Events löschen | |

---

## 6. Prod-Betrieb & Diagnose (`bin/*.sh`, `unicorn:*`, `scoreboard*:*`)

Shell-Scripts unter `bin/`. Vor Ausführung Header/Quelle prüfen (viele sind server-/host-spezifisch).

### Puma / App-Server

| Script/Task | Was |
|---|---|
| `bin/manage-puma.sh` / `bin/manage-puma-api.sh` | Puma verwalten (start/stop/status) |
| `bin/puma-wrapper.sh` | Puma-Wrapper für systemd |
| `bin/check-puma-logs.sh` | Puma-Logs prüfen |
| `bin/restart-puma-carambus.sh` | Puma für carambus.de neustarten |
| `bin/restart-puma-and-clients.sh` | Puma + alle Scoreboard-Kiosk-Clients neustarten |
| `bin/restart-carambus.sh` / `bin/restart-scoreboard.sh` | Carambus / Scoreboard neustarten |
| `bin/diagnose-puma-carambus.sh` | carambus.de Puma-Verbindungsprobleme diagnostizieren |
| `bin/diagnose-socket-issue.sh` / `bin/fix-socket-issue.sh` | Puma-Socket-Problem (carambus_bcw) diagnostizieren/fixen |
| `bin/fix-puma-config.sh` | Puma-Config fixen (problematischen TCP-Bind Port 81 entfernen) |
| `bin/cleanup_rails.sh` | Stale Rails-Prozesse + PID-Files aufräumen |
| `unicorn:restart` | Anwendung neustarten (rake) |

### Nginx / SSL

| Script | Was |
|---|---|
| `bin/diagnose-nginx.sh` | nginx-Config-Probleme (Hetzner API-Server) diagnostizieren |
| `bin/fix-nginx-config.sh` / `bin/fix-nginx-hetzner.sh` | nginx-Configs auf API-Server fixen |
| `bin/fix-api-nginx.sh` | Fehlende api.carambus.de nginx-Config quick-fixen |
| `bin/migrate-to-production-domains.sh` | Migration newapi/new.carambus.de → api/carambus.de |
| `bin/generate-ssl-cert.sh` | SSL-Zertifikat generieren |
| `bin/check-actioncable-status.sh` | ActionCable-Redis-Config schnell prüfen |
| `bin/test-actioncable-redis.rb` | ActionCable/Redis-Verbindung diagnostizieren (Ruby) |

### DB-Sync / Backup / Versionen

| Script | Was |
|---|---|
| `bin/check_database_sync.sh` | Datenbank-Synchronisation prüfen (generalisiert) |
| `bin/check-database-states.sh` | Aktuelle DB-States für Deploy-Szenario-Analyse |
| `bin/get_versions.sh` | Versionen (IP-Adresse) |
| `bin/cleanup_versions.sh` | Version-Cleanup für Carambus |

### Deploy

| Script | Was |
|---|---|
| `bin/deploy.sh` / `bin/deploy-carambus_api-complete.sh` | Deployment-Workflow (carambus_api) |
| `bin/deploy-scenario.sh` | Generischer Szenario-Deploy-Workflow |
| `bin/deploy-prep.sh` | Prod-Config-Dateien für Szenario re-generieren + Stage-File kopieren (Plan 21-10) |
| `bin/build-docker-image.sh` | Docker-Image bauen |
| `bin/kamal` | Kamal-Wrapper (Docker-Container-Deploy) |
| `bin/mcp-server` | MCP-Server starten (Model-Context-Protocol) |
| `bin/rebuild_js.sh` | JavaScript schnell neu bauen |

### E-Mail / Postfix

| Script | Was |
|---|---|
| `bin/configure-postfix-relay.sh` / `bin/setup-postfix-bcw.sh` | Postfix-Relay konfigurieren / Mailserver (carambus_bcw) einrichten |
| `bin/fix-postfix-sender.sh` | Postfix-Sender-Adresse für GMX-Relay fixen |

### Bot-/Scraper-IP-Blocking

| Script | Was |
|---|---|
| `bin/analyze_scrapers.sh` | Scraping-Aktivität aus nginx-Access-Logs analysieren |
| `bin/extract_scraper_ips.sh` | Wahrscheinliche Scraper-IPs aus nginx-Logs extrahieren |
| `bin/find_unclassified_ips.sh` | IPs finden, die weder in WHITELIST noch BLACKLIST |
| `bin/block_scraper_ips.sh` | Scraper-IPs in nginx blocken |
| `bin/check-ip-literals.sh` | IPv4-Literale in Source/Templates aufspüren |

### Scoreboard / Chromium / Raspberry Pi

| Script/Task | Was |
|---|---|
| `bin/autostart-scoreboard.sh` / `bin/start-scoreboard.sh` / `bin/exit-scoreboard.sh` | Scoreboard Autostart/Start/Exit |
| `bin/scoreboard-browser-restart.sh` / `bin/scoreboard-browser-watchdog.sh` | Scoreboard-Browser Restart / Watchdog |
| `bin/install-browser-watchdog.sh` | Browser-Watchdog auf Raspberry-Pi-Table-Client installieren |
| `bin/cleanup-chromium.sh` | Chromium für Scoreboard aufräumen |
| `bin/find-raspberry-pi.sh` | Raspberry Pi finden |
| `bin/setup-raspberry-pi.sh` / `bin/setup-raspi-table-client.sh` / `bin/setup-table-raspi.sh` | Raspberry Pi / Table-Client Setup |
| `bin/prepare-sd-card.sh` | SD-Karte für Raspberry Pi 4 vorbereiten |
| `bin/fix-raspi-network.sh` | Raspberry-Pi-Netzwerkstabilität fixen |
| `bin/measure-raspi-performance.sh` | Raspberry-Pi-Performance messen |
| `bin/setup-phillips-table-ssh.sh` | SSH-Enable für Phillip's Table Raspberry Pi |
| `bin/test-raspberry-pi.sh` / `bin/test-raspberry-pi-restart.sh` | Raspberry-Pi-Docker-Deployment / Client-Restart testen |
| `bin/test-startup.sh` | Scoreboard-Startup-Debug |
| `bin/tplink.rb` | TP-Link-Smart-Plug steuern (Tisch-Strom/Reset) |
| `bin/carambus-overlay-updater.service` / `bin/carambus-stream.service` | systemd-Unit-Templates (Overlay-Updater / YouTube-Stream) |
| `scoreboard:update_defaults` (rake) | Scoreboard-User auf Dark-Mode default setzen |
| `scoreboard_messages:list` / `scoreboard_messages:stats` / `scoreboard_messages:cleanup` (rake) | Scoreboard-Messages listen / Statistik / aufräumen (abgelaufene auto-acknowledge + broadcast) |

### Installation / Setup / Lokalisierung

| Script/Task | Was |
|---|---|
| `bin/carambus-install.sh` / `bin/install-client-only.sh` | Carambus-Installation / Client-Only |
| `bin/setup-local-dev.sh` | Lokale Dev-Umgebung (carambus_local_hetzner) |
| `bin/start-api-server.sh` / `bin/start-local-server.sh` / `bin/start-both-servers.sh` | API- / LOCAL- / beide Server starten |
| `bin/backup-localization.sh` / `bin/restore-localization.sh` | Lokalisierung sichern/wiederherstellen |
| `carambus:installation:status` / `carambus:installation:check_prerequisites` / `carambus:installation:create_backup` (rake) | Installations-Status / System-Voraussetzungen prüfen / vollständiges System-Backup |
| `carambus:installation:setup_localization` / `carambus:installation:export_localization` / `carambus:installation:import_localization[file]` / `carambus:installation:validate_localization` (rake) | Standard-Lokalisierung anlegen / als JSON exportieren / aus JSON importieren / validieren |

---

## 7. AI / Übersetzung / i18n / Docs

| Task | Was | Wann/Hinweis |
|---|---|---|
| `ai_usage:report` | AI-Chat-Kosten/Tokens pro Scenario+Modell über Zeit | ENV `SINCE=YYYY-MM-DD UNTIL=… BUCKET=day\|week` |
| `deepl:test` / `deepl:test_custom[text,source,target]` | DeepL-Übersetzung testen | |
| `glossary:update` | Alle Billard-Glossare erstellen/aktualisieren | |
| `glossary:list` / `glossary:stats` / `glossary:test` | Glossare listen / Statistik / Übersetzung testen | |
| `i18n:check` | Alle Übersetzungsdateien auf Fehler prüfen | |
| `i18n:sort[path_to_yaml_file]` | i18n-YAML alphabetisch sortieren | |
| `mkdocs:build` / `mkdocs:deploy` | MkDocs bauen / bauen+deployen | öffentliche Doku-Site |
| `mkdocs:serve` | MkDocs lokal servieren | Entwicklung |
| `mkdocs:check` | MkDocs validieren (strict, CI-ready) | |
| `mkdocs:clean` | MkDocs-Build-Artefakte aufräumen | |
| `ui:no_hardcoded_hex` | **Wache**: failt bei neuen hartkodierten Farb-Hex / inline color-styles | pre-commit + CI (Phase-7 Hex-Migration) |
| `ui:no_hardcoded_hex:baseline` | Ratchet-Baseline neu erzeugen | `config/ui_hex_baseline.yml` |

**Docs-Guards / Fixer & Bild-Tooling (Scripts):**

| Script | Was |
|---|---|
| `bin/deploy-docs.sh` | MkDocs deployen |
| `bin/test-docs-structure.sh` | Doku-Struktur testen |
| `bin/check-docs-coderef.rb` | Doku-Code-Referenzen gegen Codebase prüfen |
| `bin/check-docs-links.rb` / `bin/fix-docs-links.rb` | Doku-Links prüfen / reparieren |
| `bin/check-docs-translations.rb` | Doku-Übersetzungen prüfen |
| `bin/ui-hex-guard` | Binstub für die Hex-Guard (`ui:no_hardcoded_hex`) |
| `bin/clean_images.py` | Bilder bereinigen |
| `bin/resize_images.py` / `bin/resize_with_dpi.py` | Bilder skalieren / mit DPI skalieren |

---

## 8. Video / Streaming / YouTube

### International-Pipeline (`international:*`)

YouTube-/UMB-Video-Pipeline (internationale Turniere).

| Task | Was | Wann/Hinweis |
|---|---|---|
| `international:daily_scrape` | Täglicher automatisierter Scrape | Cron |
| `international:full_pipeline[days_back]` | Voll-Pipeline: scrape→process→discover→translate | |
| `international:scrape_all[days_back]` | Alle bekannten YouTube-Kanäle scrapen | |
| `international:scrape_umb` | Offizielle UMB-Turnierdaten scrapen | |
| `international:process_all_videos` / `international:process_untagged_videos` | Videos auto-taggen (alle / untagged für Cron) | |
| `international:discover_tournaments` | Turniere aus vorhandenen Videos entdecken | |
| `international:translate_videos[limit]` | Video-Titel ins Englische übersetzen | |
| `international:update_statistics` | Video-Statistik + Tag-Counts aktualisieren | Cron |
| `international:cleanup_umb_fragments` | Fehlerhafte UMB-Turnier-Einträge aufräumen | |
| `international:stats` | Statistiken zeigen | |
| `international:find_channel_id[handle]` | YouTube-Channel-ID aus Handle finden | |
| `international:test_api` / `international:test_channel[channel_id,days_back]` | YouTube-API / Kanal-Scrape testen | Diagnose |

### Videos (`videos:*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `videos:analyze` | Video-Content-Typen + Disziplinen analysieren | |
| `videos:tag_disciplines` | Videos mit Disziplin taggen (Content-Analyse) | |
| `videos:match_to_games` | Unzugeordnete Videos zu Games matchen (UMB/Cuesco/fivensix) | Spielernamen + Datum |
| `videos:match_tournaments` | Videos zu InternationalTournaments matchen | >0.75 Confidence |
| `videos:find_full_games` | Potentielle Full-Game-Videos finden | |
| `videos:translate` / `videos:translate_video[video_id]` | Nicht-englische Titel übersetzen | |
| `videos:test_translation[text]` / `videos:translation_stats` | Übersetzung testen / Statistik | |
| `videos:migrate_from_production` / `videos:migrate_via_ssh` | international_videos aus Prod migrieren | |
| `videos:preview` / `videos:dry_run` | Migration Preview / Dry-Run | |

### Streaming (`streaming:*`)

Raspberry-Pi-Kamera-Streaming (YouTube Live).

| Task | Was | Wann/Hinweis |
|---|---|---|
| `streaming:status` | Status aller Streams | Diagnose |
| `streaming:help` | Streaming-Doku anzeigen | |
| `streaming:setup[raspi_ip]` / `streaming:test[raspi_ip]` | Infrastruktur auf Raspberry Pi einrichten/testen | |
| `streaming:deploy[table_id]` / `streaming:deploy_all` | Stream-Config auf Raspberry Pi deployen | |
| `streaming:ssh_test[table_id]` | SSH-Verbindung zum Raspberry Pi testen | Key-Auth-Setup |
| `streaming:camera_calibrate[table_id]` / `streaming:camera_save[table_id]` / `streaming:camera_set[table_id,control,value]` | Kamera kalibrieren / Werte vom Raspberry Pi speichern / Control-Wert setzen | |
| `streaming:perspective_calibrate[table_id]` / `streaming:perspective_set[table_id,coords]` | Perspektiv-Korrektur kalibrieren / Koordinaten setzen | |

Zugehörige Scripts: `bin/carambus-stream.sh`, `bin/carambus-overlay-updater.sh`.

### YouTube (`youtube:*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `youtube:list_channels` | Bekannte YouTube-Kanäle listen | |
| `youtube:add_source[name,channel_id]` | Kanal als InternationalSource hinzufügen | |
| `youtube:find_channel[handle]` | Channel-ID aus Handle finden | |
| `youtube:scrape_all[days_back]` / `youtube:scrape_channel[channel_id,days_back]` | Alle / einen Kanal scrapen | |
| `youtube:search[max_results]` | YouTube nach Carom-Videos durchsuchen | |
| `youtube:stats` / `youtube:test` | Statistik / API-Zugriff testen | |

---

## 9. Dev / Test / Fixtures

### Tests (`test:*`)

| Task | Was | Wann/Hinweis |
|---|---|---|
| `test` | Alle Tests (außer System) | |
| `test:critical` | Nur kritische Tests (concerns + scraping) | schneller Smoke |
| `test:concerns` / `test:scraping` | Concern- / Scraping-Tests | |
| `test:characterization` | Characterization-Tests (Behavior-Pins für Extraction-Safety) | vor Refactoring |
| `test:ko_tournaments` / `test:ko_tournaments_coverage` | KO-Turnier-Tests (+ Coverage) | |
| `test:coverage` | Tests mit Coverage-Report | |
| `test:db` / `test:reset` / `test:clean` | Test-DB reset + Tests / DB reset / Test-Daten löschen | |
| `test:setup_all` | Test-DBs für alle Szenarien einrichten | |
| `test:validate` / `test:verify` | Test-Setup validieren / Test-DB-Setup verifizieren | |
| `test:list` / `test:stats` | Test-Dateien listen / Statistik | |
| `test:collect_fixtures` | ClubCloud-HTML-Fixtures sammeln (interaktiv) | |
| `test:list_fixtures` / `test:show_fixture_urls` / `test:validate_fixtures` | Fixtures listen / Beispiel-URLs / validieren | |
| `test:rerecord_vcr` | VCR-Cassettes clean + neu aufnehmen | |
| `db:test:prepare_with_fixtures` | Test-DB vorbereiten (create/schema/fixtures) | |
| `players:test_finder` | PlayerFinder-Concern mit Sample-Daten testen | |

### Training-Data (`training_data:*`)

| Task | Was |
|---|---|
| `training_data:export` / `training_data:import` | Training-Daten exportieren/importieren (`db/seeds/training_data.rb`) |
| `training_data:copy_storage` | ActiveStorage-Files für Training-Sources kopieren |

### Dev-Tools / Setup (`carambus:*`, sonstige)

| Task | Was |
|---|---|
| `carambus:erd` | rails-erd → `docs/erd.pdf` generieren (braucht rails-erd + graphviz) |
| `carambus:list_scaffolds` | Liste der Scaffolds |
| `carambus:create_local_seed` | Lokalen Seed erzeugen |
| `bin/setup-cc-credentials.sh` / `bin/test-cc-login.sh` | CC-Credentials einrichten / Login testen |
| `bin/test-cc-name-mapping.rb` | CC-Name-Mapping testen (Ruby) |
| `bin/disable-unused-stuff-in-client.sh` | Ungenutztes im Client deaktivieren |

---

## Ad-hoc-Skripte / Einmal-Interventionen

- Einmalige, nicht wiederkehrende Skripte liegen im **scratchpad** der jeweiligen
  Session oder in `.paul/`-Runbooks — sie sind bewusst nicht als rake-Task
  festgeschrieben.
- Der `adhoc:`-Namespace ist ein Grab-bag; Tasks dort können veraltet sein —
  vor Nutzung immer die `.rake`-Quelle prüfen.
- **Regel:** Wird eine Intervention **wiederkehrend**, gehört sie als benannter
  rake-Task nach `lib/tasks/` **und** in diesen Guide. Reine Einmal-Fälle bleiben
  im scratchpad/`.paul/` dokumentiert (mit Datum + Anlass), damit der nächste
  Vorfall den Kontext findet.
- Vorfall-spezifische Runbooks/Memories (CC-Saison-Rollover-Kontamination,
  TBV/LigaManager-Cutover, UMB-Parallel-Scrape-Kollision, SeasonParticipation-
  Phantom-temporary) siehe `.paul/` bzw. Auto-Memory.

> Hinweis: `bin/setup-raspi-table-client.sh.backup` ist eine `.backup`-Leiche
> (kein aktives Script) — nicht ausführen.
