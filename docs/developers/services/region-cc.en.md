# RegionCc:: — Architecture

The `RegionCc::` namespace synchronises the local Carambus database with ClubCloud (CC) — the PHP-based German billiards federation management platform. High-level synchronisation is orchestrated by three instance methods on the `RegionCc` model — `synchronize_league_structure`, `synchronize_league_plan_structure`, and `synchronize_tournament_structure` (`app/models/region_cc.rb`) — which call multiple syncers. Callers may also invoke the individual `RegionCc::*Syncer.call` services directly; each service handles one sync domain.

The namespace consists of **11 services** in `app/services/region_cc/`.

## Namespace Overview

| Class | File | Description |
|-------|------|-------------|
| `RegionCc::ClubCloudClient` | `app/services/region_cc/club_cloud_client.rb` | Stateless HTTP transport for the ClubCloud admin interface — GET, POST, multipart POST; session-aware; dry-run mode |
| `RegionCc::BranchSyncer` | `app/services/region_cc/branch_syncer.rb` | Syncs `BranchCc` records (disciplines) from the CC API |
| `RegionCc::ClubSyncer` | `app/services/region_cc/club_syncer.rb` | Syncs `Club` records from the CC API |
| `RegionCc::CompetitionSyncer` | `app/services/region_cc/competition_syncer.rb` | Syncs competition and season data; operation dispatch (`:sync_competitions`, `:sync_seasons_in_competitions`) |
| `RegionCc::GamePlanSyncer` | `app/services/region_cc/game_plan_syncer.rb` | Syncs `GamePlanCc` and `GameDetailCc` records including HTML table parsing; operations: `:sync_game_plans`, `:sync_game_details` |
| `RegionCc::LeagueSyncer` | `app/services/region_cc/league_syncer.rb` | Dispatcher for league sync — operations: `:sync_leagues`, `:sync_league_teams`, `:sync_league_teams_new`, `:sync_league_plan`, `:sync_team_players`, `:sync_team_players_structure` |
| `RegionCc::MeldelisteCreator` | `app/services/region_cc/meldeliste_creator.rb` | Creates a CC entry list (Meldeliste) for a single tournament — checks for an existing list, then creates and verifies it via `post_cc`. No `operation` dispatch; takes a `tournament:` instead of `client:` |
| `RegionCc::MetadataSyncer` | `app/services/region_cc/metadata_syncer.rb` | Syncs metadata reference objects (categories, groups, disciplines); operations: `:sync_category_ccs`, `:sync_group_ccs`, `:sync_discipline_ccs` |
| `RegionCc::PartySyncer` | `app/services/region_cc/party_syncer.rb` | Syncs `PartyCc` records and match data; operations: `:sync_parties`, `:sync_party_games` |
| `RegionCc::RegistrationSyncer` | `app/services/region_cc/registration_syncer.rb` | Syncs registration list records; operations: `:sync_registration_list_ccs`, `:sync_registration_list_ccs_detail` |
| `RegionCc::TournamentSyncer` | `app/services/region_cc/tournament_syncer.rb` | Syncs tournament, tournament series, and championship type data; operations: `:sync_tournaments`, `:sync_tournament_ccs`, `:sync_tournament_series_ccs`, `:sync_championship_type_ccs`, `:fix_tournament_structure` |

## Public Interface

### ClubCloudClient

**Entry points:**

```ruby
client = RegionCc::ClubCloudClient.new(base_url:, username:, userpw:)

res, doc = client.get("showLeagueList", {fedId: 20}, {session_id: "abc"})
  # → [Net::HTTPResponse, Nokogiri::HTML::Document]

res, doc = client.post("createLeagueSave", params, opts)
  # → [Net::HTTPResponse, Nokogiri::HTML::Document]
```

**Input (constructor):**

| Parameter | Type | Description |
|-----------|------|-------------|
| `base_url` | `String` | Base URL of the ClubCloud instance |
| `username` | `String` | Admin username |
| `userpw` | `String` | Admin password |

**Input (get/post):**

| Parameter | Type | Description |
|-----------|------|-------------|
| First arg | `String` | Action name — mapped to URL path via `PATH_MAP` |
| Second arg | `Hash` | Query/form parameters |
| `opts` | `Hash` | Options; `opts[:session_id]` sent as PHPSESSID cookie |

### Syncer Pattern

All syncer services follow the same pattern: class method `.call` with `region_cc:`, `client:`, and optional kwargs.

```ruby
# Simple syncers (no operation required)
RegionCc::BranchSyncer.call(region_cc: rc, client: cc_client, **opts)
  # → Array of synced Branch objects (raises ArgumentError on unknown branch name)

RegionCc::ClubSyncer.call(region_cc: rc, client: cc_client, **opts)
  # → Array of synced Club objects

# Syncers with operation dispatch
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

### MeldelisteCreator (different signature)

`MeldelisteCreator` does not follow the `region_cc:`/`client:`/`operation:` pattern. It takes a `tournament:` and creates the CC entry list (Meldeliste) for that single tournament, resolving the region and client from the tournament's organizer. It performs its HTTP calls via `region_cc.post_cc` and is invoked by `synchronize_tournament_structure`.

```ruby
RegionCc::MeldelisteCreator.call(tournament: tournament, **opts)
  # → creates and verifies the Meldeliste; raises "Error: Synchronization failed" if verification fails
```

**Common input parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `region_cc` | `RegionCc` | ActiveRecord instance of the region |
| `client` | `RegionCc::ClubCloudClient` | Already-initialised HTTP client |
| `operation` | `Symbol` | Dispatch key (for syncers with multiple operations) |
| `opts[:armed]` | `Boolean/nil` | `blank?` → dry run; set → write mode |
| `opts[:session_id]` | `String` | PHPSESSID cookie value for the HTTP request |

## Architecture Decisions

### a. ClubCloudClient with no ORM coupling

`ClubCloudClient` contains no model calls — pure HTTP. This design keeps the transport layer testable and reusable across different sync contexts.

### b. Dry-run mode

`opts[:armed].blank?` means dry run: write operations are skipped while read requests still execute. This enables safe pre-flight checks before a real sync.

### c. Session management via PHPSESSID cookie

ClubCloud uses PHP sessions. `opts[:session_id]` is sent as a `PHPSESSID` cookie on every request. The client does not handle automatic session renewal — the session ID must be supplied externally.

### d. PATH_MAP constant

`ClubCloudClient` contains a `PATH_MAP` constant mapping action names to URL paths and a `read_only` flag. The `read_only` flag prevents POST requests in dry-run mode for write actions.

### e. All syncers as ApplicationService

All 10 services (9 syncers plus `MeldelisteCreator`) inherit from `ApplicationService` because they make database/CC changes. `ClubCloudClient` does not inherit from `ApplicationService` — it is a stateless HTTP transport.

## Cross-References

- Parent guide: [Developer Guide — Extracted Services](../developer-guide.en.md#extracted-services)
