# League:: — Architektur

Der `League::`-Namespace enthält Services für Liga-Operationen — das Scrapen externer Ligadaten (ClubCloud und BBV), die Rekonstruktion von Spielplänen aus vorhandenen Daten sowie die Berechnung von Tabellen.

Der Namespace besteht aus **4 Services** in `app/services/league/`.

## Namespace-Übersicht

| Klasse | Datei | Beschreibung |
|--------|-------|--------------|
| `League::BbvScraper` | `app/services/league/bbv_scraper.rb` | Scrapt BBV-spezifische Ligadaten (Mannschaften und Ergebnisse) von bbv-billard.liga.nu |
| `League::ClubCloudScraper` | `app/services/league/club_cloud_scraper.rb` | Scrapt Ligadaten von ClubCloud — Mannschaften, Spieltage, Spielpläne |
| `League::GamePlanReconstructor` | `app/services/league/game_plan_reconstructor.rb` | Rekonstruiert `GamePlan` aus vorhandenen `Party`- und `PartyGame`-Records; mehrere Betriebsmodi |
| `League::StandingsCalculator` | `app/services/league/standings_calculator.rb` | Berechnet Tabellen für Karambol-, Snooker- und Pool-Ligen |

## Öffentliche Schnittstelle

### BbvScraper

**Einstiegspunkte:**

```ruby
League::BbvScraper.call(league: league, region: region)
  # → Seiteneffekte: erstellt/aktualisiert League-, LeagueTeam-, Party-Records

League::BbvScraper.scrape_all(region: region, season: season, opts: {})
  # → Array von records_to_tag (für RegionTaggable)
```

**Eingabe:**

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `league` | `League` | ActiveRecord-Instanz der zu scrapenden Liga |
| `region` | `Region` | Zugeordnete Region für Tagging |
| `season` | `Season` | Saison für Mehrfach-Liga-Scraping |

**Konstante:**

```ruby
League::BbvScraper::BBV_BASE_URL = "https://bbv-billard.liga.nu"
```

Der Endpunkt ist fest codiert — keine konfigurierbare Alternative vorgesehen.

### ClubCloudScraper

**Einstiegspunkte:**

```ruby
League::ClubCloudScraper.call(league: league, league_details: true)
  # → nil (Seiteneffekte: erstellt LeagueTeam-, Party-, PartyGame-Records)
```

**Eingabe:**

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `league` | `League` | ActiveRecord-Instanz der zu scrapenden Liga |
| `league_details` | `Boolean` | Ob Spielplan-Details abgerufen werden sollen |

### GamePlanReconstructor

**Einstiegspunkte — drei Betriebsmodi:**

```ruby
League::GamePlanReconstructor.call(league: league, operation: :reconstruct)
  # → nil; erstellt GamePlan-Records aus vorhandenen Party/PartyGame-Daten

League::GamePlanReconstructor.call(season: season, operation: :reconstruct_for_season)
  # → nil; rekonstruiert GamePlan für alle Ligen einer Saison

League::GamePlanReconstructor.call(league: league, season: season, operation: :delete_for_season)
  # → nil; löscht GamePlan-Records für alle Ligen einer Saison
```

**Eingabe:**

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `league` | `League` | ActiveRecord-Instanz (für `:reconstruct` und `:delete_for_season`) |
| `season` | `Season` | Saison (für `:reconstruct_for_season` und `:delete_for_season`) |
| `operation` | `Symbol` | Betriebsmodus: `:reconstruct`, `:reconstruct_for_season` oder `:delete_for_season` |

### StandingsCalculator

**Hinweis:** `StandingsCalculator` ist ein PORO (kein `ApplicationService`). Es wird instanziiert, nicht via `.call` aufgerufen.

**Einstiegspunkte:**

```ruby
calculator = League::StandingsCalculator.new(league)

calculator.karambol
  # → Array von Team-Stat-Hashes (Karambol-Bewertungssystem)

calculator.snooker
  # → Array von Team-Stat-Hashes (Snooker-Bewertungssystem)

calculator.pool
  # → Array von Team-Stat-Hashes (Pool-Bewertungssystem)

calculator.schedule_by_rounds
  # → Hash { Rundenname => Array<Party> } — Spielplan gruppiert nach Runden
```

**Rückgabeformat der Tabellen-Methoden:**

```ruby
[
  {
    team:          LeagueTeam,  # ActiveRecord-Instanz
    name:          String,      # Mannschaftsname
    spiele:        Integer,     # Gespielte Partien
    gewonnen:      Integer,
    unentschieden: Integer,
    verloren:      Integer,
    punkte:        Integer,     # 2 pro Sieg, 1 pro Unentschieden
    diff:          Integer,     # Differenz (for/against)
    platz:         Integer,     # Tabellenrang (ab 1)
    # Karambol/Pool:
    partien:       String,      # Format "erzielt:kassiert"
    # Snooker:
    frames:        String       # Format "erzielt:kassiert"
  },
  ...
]
```

Sortierung: Punkte absteigend, dann Differenz absteigend.

## Architektur-Entscheidungen

### a. ApplicationService vs. PORO

`BbvScraper`, `ClubCloudScraper` und `GamePlanReconstructor` erben von `ApplicationService`, da sie Datenbankänderungen vornehmen (Schreiboperationen mit Seiteneffekten). `StandingsCalculator` ist ein PORO — er liest und berechnet nur, führt keine DB-Schreibvorgänge durch.

### b. BBV_BASE_URL fest codiert

`BBV_BASE_URL = "https://bbv-billard.liga.nu"` ist als Konstante in `BbvScraper` fest codiert. Es gibt keine konfigurierbare Alternative, da BBV nur einen einzigen öffentlichen Endpunkt betreibt.

### c. Mehrere Betriebsmodi in GamePlanReconstructor

`GamePlanReconstructor` unterstützt drei Betriebsmodi via `:operation`-Parameter, da die drei Anwendungsfälle (Einzelliga-Rekonstruktion, Saison-weite Rekonstruktion, Saison-weites Löschen) dieselbe Kernlogik teilen. Ein einzelnes `call`-Interface mit Operationsparameter ist kompakter als drei separate Service-Klassen.

### d. Kein direkter Broadcast-Aufruf

Keiner der League-Services ruft CableReady oder ActionCable direkt auf. Broadcasts erfolgen über Modell-Callbacks.

## Querverweise

- Übergeordneter Leitfaden: [Developer Guide — Extrahierte Services](../developer-guide.de.md#extrahierte-services)
