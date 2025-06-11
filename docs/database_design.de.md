# Carambus API Datenbank-Design Dokumentation

## Kernmodelle und ihre Beziehungen

### Seeding-Modell - Doppelte Funktionalität
Das `Seeding`-Modell erfüllt zwei verschiedene Zwecke im System:

1. **Team-Kaderverwaltung**
   - Verbunden mit `LeagueTeam` über `league_team_id`
   - Dient zur Verwaltung des vollständigen Spielerkaders eines Ligateams
   - Wird während der initialen Liga/Team-Einrichtung und beim Scraping erstellt
   - Beispiel: `Seeding.where(league_team: league_team, player: player)`

2. **Spielbeteiligungsverfolgung**
   - Verbunden mit `Party` über polymorphe `tournament_id` und `tournament_type`
   - Verfolgt, welche Spieler an bestimmten Spielen teilnehmen
   - Wird bei der Einrichtung einzelner Spiele erstellt
   - Beispiel: `party.seedings.where("id > #{Game::MIN_ID}")`

```ruby
class Seeding < ApplicationRecord
  belongs_to :player, optional: true
  belongs_to :tournament, polymorphic: true, optional: true
  belongs_to :league_team, optional: true
  # ...
end
```

### Party und LeagueTeam Beziehung
Die Beziehung zwischen `Party` und `LeagueTeam` ist für die Spielplanung und Team-Beteiligung konzipiert:

```ruby
class Party < ApplicationRecord
  belongs_to :league_team_a, class_name: "LeagueTeam"
  belongs_to :league_team_b, class_name: "LeagueTeam"
  belongs_to :host_league_team, class_name: "LeagueTeam"
  belongs_to :no_show_team, class_name: "LeagueTeam"
  has_many :seedings, as: :tournament
  # ...
end

class LeagueTeam < ApplicationRecord
  has_many :parties_a, class_name: "Party", foreign_key: :league_team_a_id
  has_many :parties_b, class_name: "Party", foreign_key: :league_team_b_id
  has_many :parties_as_host, class_name: "Party", foreign_key: :host_league_team_id
  has_many :no_show_parties, class_name: "Party", foreign_key: :no_show_team_id
  has_many :seedings
  # ...
end
```

## Datenspeicherungsmuster

### Flexible Datenspeicherung
Mehrere Modelle verwenden serialisierte Spalten für flexible Datenspeicherung:

1. **JSON-Serialisierung**
   ```ruby
   serialize :data, coder: JSON, type: Hash
   ```
   Verwendet in:
   - `Party` - Speichert spielspezifische Daten
   - `Seeding` - Speichert Spielergebnisse und Ranglisten
   - `LeagueTeam` - Speichert teamspezifische Metadaten

2. **YAML-Serialisierung**
   ```ruby
   serialize :remarks, coder: YAML, type: Hash
   ```
   Verwendet in:
   - `Party` - Speichert Spielbemerkungen und Notizen

### Region-Tagging-System
Das `RegionTaggable`-Concern bietet intelligente Regionsverwaltung:

```ruby
# Beispiel aus RegionTaggable
when Seeding
  if tournament_id.present?
    # Behandlung des tournament-basierten Region-Taggings
    tournament ? [
      tournament.region_id,
      (tournament.organizer_type == "Region" ? tournament.organizer_id : nil),
      find_dbu_region_id_if_global
    ].compact : []
  elsif league_team_id.present?
    # Behandlung des league-team-basierten Region-Taggings
    league_team&.league ? [
      (league_team.league.organizer_type == "Region" ? league_team.league.organizer_id : nil),
      find_dbu_region_id_if_global
    ].compact : []
  end
```

## Datenschutz und Synchronisation

### Lokaler Schutz
Das `LocalProtector`-Concern schützt lokale Daten vor externen Änderungen:

```ruby
class Party < ApplicationRecord
  include LocalProtector
  # ...
end

class LeagueTeam < ApplicationRecord
  include LocalProtector
  # ...
end

class Seeding < ApplicationRecord
  include LocalProtector
  # ...
end
```

### Quellenverwaltung
Das `SourceHandler`-Concern verwaltet die externe Datensynchronisation:

```ruby
class Party < ApplicationRecord
  include SourceHandler
  # ...
end

class LeagueTeam < ApplicationRecord
  include SourceHandler
  # ...
end
```

## Wichtige Arbeitsabläufe

### Team-Einrichtung und Spielerstellung
1. Ligateams werden mit ihrem Basis-Kader erstellt (Seedings mit `league_team_id`)
2. Bei der Erstellung eines Spiels:
   - Eine neue `Party` wird erstellt, die zwei `LeagueTeam`s verbindet
   - Spezifische Seedings werden für das Spiel erstellt (mit `tournament_id`)
   - Diese Seedings verfolgen, welche Spieler aus dem Team-Kader an diesem Spiel teilnehmen

### Datensynchronisation
1. Externe Daten (von BA/CC) werden über den `SourceHandler` synchronisiert
2. Lokale Daten werden vor externen Änderungen durch `LocalProtector` geschützt
3. Region-Tagging wird automatisch basierend auf dem Kontext (Tournament oder Ligateam) behandelt

## Wichtige Hinweise für Entwickler

1. **Seeding-Erstellung**
   - Immer berücksichtigen, ob ein Team-Kadereintrag oder ein Spielbeteiligungseintrag erstellt wird
   - Passende Assoziationen verwenden (`league_team_id` vs `tournament_id`)

2. **Datenschutz**
   - Den `LocalProtector` bei der Änderung von Datensätzen beachten
   - `unprotected = true` verwenden, wenn lokale Änderungen notwendig sind

3. **Regionsverwaltung**
   - Region-Tagging ist automatisch, aber kontextabhängig
   - Unterschiedliche Logik für tournament-basierte vs. league-team-basierte Seedings

4. **Datenspeicherung**
   - Passende Serialisierung (JSON vs YAML) für verschiedene Datentypen verwenden
   - Struktur der gespeicherten Daten in serialisierten Spalten beachten

## Datenbankschema-Highlights

### Seeding-Modell
```ruby
create_table "seedings" do |t|
  t.string "ba_state"
  t.integer "balls_goal"
  t.text "data"
  t.integer "position"
  t.integer "rank"
  t.string "role"
  t.string "state"
  t.string "tournament_type"
  t.integer "league_team_id"
  t.integer "player_id"
  t.integer "playing_discipline_id"
  t.integer "tournament_id"
  # ...
end
```

### Party-Modell
```ruby
create_table "parties" do |t|
  t.datetime "date"
  t.integer "league_id"
  t.text "remarks"
  t.integer "league_team_a_id"
  t.integer "league_team_b_id"
  t.integer "host_league_team_id"
  t.integer "no_show_team_id"
  t.text "data"
  # ... weitere Felder ...
end
```

### LeagueTeam-Modell
```ruby
create_table "league_teams" do |t|
  t.string "name"
  t.string "shortname"
  t.integer "league_id"
  t.integer "ba_id"
  t.integer "cc_id"
  t.integer "club_id"
  t.text "data"
  # ... weitere Felder ...
end
``` 