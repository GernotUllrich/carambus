# RegionCc:: — Architektur

Der `RegionCc::`-Namespace synchronisiert die lokale Carambus-Datenbank mit der ClubCloud (CC) — der PHP-basierten Verwaltungsplattform des Deutschen Billard-Verbands. Die übergeordnete Synchronisation wird von drei Instanzmethoden des `RegionCc`-Modells orchestriert — `synchronize_league_structure`, `synchronize_league_plan_structure` und `synchronize_tournament_structure` (`app/models/region_cc.rb`) —, die mehrere Syncer aufrufen. Aufrufer können die einzelnen `RegionCc::*Syncer.call`-Services auch direkt nutzen; jeder Service verantwortet eine Sync-Domäne.

Der Namespace besteht aus **11 Services** in `app/services/region_cc/`.

## Namespace-Übersicht

| Klasse | Datei | Beschreibung |
|--------|-------|--------------|
| `RegionCc::ClubCloudClient` | `app/services/region_cc/club_cloud_client.rb` | Zustandsloser HTTP-Transport für die ClubCloud-Admin-Oberfläche — GET, POST, Multipart POST; sitzungsgebunden; Dry-Run-Modus |
| `RegionCc::BranchSyncer` | `app/services/region_cc/branch_syncer.rb` | Synchronisiert `BranchCc`-Datensätze (Disziplinen) aus der CC-API |
| `RegionCc::ClubSyncer` | `app/services/region_cc/club_syncer.rb` | Synchronisiert `Club`-Datensätze aus der CC-API |
| `RegionCc::CompetitionSyncer` | `app/services/region_cc/competition_syncer.rb` | Synchronisiert Wettkampf- und Saison-Daten; Operation-Dispatch (`:sync_competitions`, `:sync_seasons_in_competitions`) |
| `RegionCc::GamePlanSyncer` | `app/services/region_cc/game_plan_syncer.rb` | Synchronisiert `GamePlanCc`- und `GameDetailCc`-Datensätze inkl. HTML-Tabellen-Parsing; Operationen: `:sync_game_plans`, `:sync_game_details` |
| `RegionCc::LeagueSyncer` | `app/services/region_cc/league_syncer.rb` | Dispatcher für Liga-Sync — Operationen: `:sync_leagues`, `:sync_league_teams`, `:sync_league_teams_new`, `:sync_league_plan`, `:sync_team_players`, `:sync_team_players_structure` |
| `RegionCc::MeldelisteCreator` | `app/services/region_cc/meldeliste_creator.rb` | Erstellt die CC-Meldeliste für ein einzelnes Turnier — prüft auf eine bestehende Liste, erstellt sie dann und verifiziert sie via `post_cc`. Kein `operation`-Dispatch; erwartet ein `tournament:` statt `client:` |
| `RegionCc::MetadataSyncer` | `app/services/region_cc/metadata_syncer.rb` | Synchronisiert Metadaten-Referenzobjekte (Kategorien, Gruppen, Disziplinen); Operationen: `:sync_category_ccs`, `:sync_group_ccs`, `:sync_discipline_ccs` |
| `RegionCc::PartySyncer` | `app/services/region_cc/party_syncer.rb` | Synchronisiert `PartyCc`-Datensätze und Spielpaarungen; Operationen: `:sync_parties`, `:sync_party_games` |
| `RegionCc::RegistrationSyncer` | `app/services/region_cc/registration_syncer.rb` | Synchronisiert Meldelisteneinträge; Operationen: `:sync_registration_list_ccs`, `:sync_registration_list_ccs_detail` |
| `RegionCc::TournamentSyncer` | `app/services/region_cc/tournament_syncer.rb` | Synchronisiert Turnier-, Turnierserie- und Meisterschaftstyp-Daten; Operationen: `:sync_tournaments`, `:sync_tournament_ccs`, `:sync_tournament_series_ccs`, `:sync_championship_type_ccs`, `:fix_tournament_structure` |

## Öffentliche Schnittstelle

### ClubCloudClient

**Einstiegspunkte:**

```ruby
client = RegionCc::ClubCloudClient.new(base_url:, username:, userpw:)

res, doc = client.get("showLeagueList", {fedId: 20}, {session_id: "abc"})
  # → [Net::HTTPResponse, Nokogiri::HTML::Document]

res, doc = client.post("createLeagueSave", params, opts)
  # → [Net::HTTPResponse, Nokogiri::HTML::Document]
```

**Eingabe (Konstruktor):**

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `base_url` | `String` | Basis-URL der ClubCloud-Instanz |
| `username` | `String` | Admin-Benutzername |
| `userpw` | `String` | Admin-Passwort |

**Eingabe (get/post):**

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| Erster Arg | `String` | Aktionsname — wird über `PATH_MAP` auf URL-Pfad gemappt |
| Zweiter Arg | `Hash` | Query-/Formular-Parameter |
| `opts` | `Hash` | Optionen; `opts[:session_id]` wird als PHPSESSID-Cookie gesendet |

### Syncer-Muster

Alle Syncer-Services folgen dem gleichen Muster: Klassenmethode `.call` mit `region_cc:`, `client:` und optionalen kwargs.

```ruby
# Einfache Syncer (keine Operation notwendig)
RegionCc::BranchSyncer.call(region_cc: rc, client: cc_client, **opts)
  # → Array synchronisierter Branch-Objekte (wirft ArgumentError bei unbekanntem Branch-Namen)

RegionCc::ClubSyncer.call(region_cc: rc, client: cc_client, **opts)
  # → Array synchronisierter Club-Objekte

# Syncer mit Operation-Dispatch
RegionCc::CompetitionSyncer.call(region_cc: rc, client: cc_client, operation: :sync_competitions, **opts)
RegionCc::CompetitionSyncer.call(region_cc: rc, client: cc_client, operation: :sync_seasons_in_competitions, **opts)

RegionCc::LeagueSyncer.call(region_cc: rc, client: cc_client, operation: :sync_leagues, **opts)
RegionCc::LeagueSyncer.call(region_cc: rc, client: cc_client, operation: :sync_league_teams, **opts)
RegionCc::LeagueSyncer.call(region_cc: rc, client: cc_client, operation: :sync_league_teams_new, **opts)
RegionCc::LeagueSyncer.call(region_cc: rc, client: cc_client, operation: :sync_league_plan, **opts)
RegionCc::LeagueSyncer.call(region_cc: rc, client: cc_client, operation: :sync_team_players, **opts)
RegionCc::LeagueSyncer.call(region_cc: rc, client: cc_client, operation: :sync_team_players_structure, **opts)

RegionCc::TournamentSyncer.call(region_cc: rc, client: cc_client, operation: :sync_tournaments, **opts)

RegionCc::PartySyncer.call(region_cc: rc, client: cc_client, operation: :sync_parties, **opts)
RegionCc::PartySyncer.call(region_cc: rc, client: cc_client, operation: :sync_party_games, **opts)

RegionCc::RegistrationSyncer.call(region_cc: rc, client: cc_client, operation: :sync_registration_list_ccs, **opts)
RegionCc::RegistrationSyncer.call(region_cc: rc, client: cc_client, operation: :sync_registration_list_ccs_detail, **opts)

RegionCc::TournamentSyncer.call(region_cc: rc, client: cc_client, operation: :sync_tournament_ccs, **opts)
RegionCc::TournamentSyncer.call(region_cc: rc, client: cc_client, operation: :sync_tournament_series_ccs, **opts)
RegionCc::TournamentSyncer.call(region_cc: rc, client: cc_client, operation: :sync_championship_type_ccs, **opts)
RegionCc::TournamentSyncer.call(region_cc: rc, client: cc_client, operation: :fix_tournament_structure, **opts)

RegionCc::GamePlanSyncer.call(region_cc: rc, client: cc_client, operation: :sync_game_plans, **opts)
RegionCc::GamePlanSyncer.call(region_cc: rc, client: cc_client, operation: :sync_game_details, **opts)

RegionCc::MetadataSyncer.call(region_cc: rc, client: cc_client, operation: :sync_category_ccs, **opts)
RegionCc::MetadataSyncer.call(region_cc: rc, client: cc_client, operation: :sync_group_ccs, **opts)
RegionCc::MetadataSyncer.call(region_cc: rc, client: cc_client, operation: :sync_discipline_ccs, **opts)
```

### MeldelisteCreator (abweichende Signatur)

`MeldelisteCreator` folgt nicht dem `region_cc:`/`client:`/`operation:`-Muster. Er erwartet ein `tournament:` und erstellt die CC-Meldeliste für genau dieses Turnier, wobei Region und Client aus dem Organizer des Turniers aufgelöst werden. Die HTTP-Aufrufe erfolgen über `region_cc.post_cc`; aufgerufen wird er von `synchronize_tournament_structure`.

```ruby
RegionCc::MeldelisteCreator.call(tournament: tournament, **opts)
  # → erstellt und verifiziert die Meldeliste; wirft "Error: Synchronization failed", falls die Verifikation fehlschlägt
```

**Gemeinsame Eingabe-Parameter:**

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `region_cc` | `RegionCc` | ActiveRecord-Instanz der Region |
| `client` | `RegionCc::ClubCloudClient` | Bereits initialisierter HTTP-Client |
| `operation` | `Symbol` | Dispatch-Schlüssel (bei Syncern mit mehreren Operationen) |
| `opts[:armed]` | `Boolean/nil` | `blank?` → Dry-Run; gesetzt → Schreibmodus |
| `opts[:session_id]` | `String` | PHPSESSID-Cookie-Wert für die HTTP-Anfrage |

## Architektur-Entscheidungen

### a. ClubCloudClient ohne ORM-Kopplung

`ClubCloudClient` enthält keine Modell-Aufrufe — reines HTTP. Dieses Design hält den Transport-Layer testbar und wiederverwendbar für unterschiedliche Sync-Kontexte.

### b. Dry-Run-Modus

`opts[:armed].blank?` bedeutet Dry-Run: Schreiboperationen werden übersprungen, Leseanfragen weiterhin durchgeführt. Dies ermöglicht sichere Vorab-Prüfungen vor einem echten Sync.

### c. Sitzungsverwaltung via PHPSESSID-Cookie

ClubCloud verwendet PHP-Sitzungen. `opts[:session_id]` wird als `PHPSESSID`-Cookie bei jeder Anfrage mitgesendet. Der Client übernimmt keine automatische Sitzungserneuerung — die Sitzungs-ID muss von außen übergeben werden.

### d. PATH_MAP-Konstante

`ClubCloudClient` enthält eine `PATH_MAP`-Konstante, die Aktionsnamen auf URL-Pfade und ein `read_only`-Flag mappt. Das `read_only`-Flag verhindert POST-Anfragen im Dry-Run-Modus für schreibende Aktionen.

### e. Alle Syncer als ApplicationService

Alle 10 Services (9 Syncer plus `MeldelisteCreator`) erben von `ApplicationService`, da sie Datenbank-/CC-Änderungen vornehmen. `ClubCloudClient` erbt nicht von `ApplicationService` — er ist ein zustandsloser HTTP-Transport.

## Querverweise

- Übergeordneter Leitfaden: [Developer Guide — Extrahierte Services](../developer-guide.de.md#extrahierte-services)
