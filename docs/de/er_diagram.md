# ER-Diagramm der Carambus-Datenbank

Dieses Dokument zeigt das Entity-Relationship-Diagramm der Carambus-Datenbankstruktur.

## Übersicht

Das ER-Diagramm zeigt die Beziehungen zwischen den wichtigsten Entitäten im Carambus-System:
- **Regionen** organisieren Vereine, Turniere und Ligen
- **Vereine** haben Standorte und organisieren Turniere
- **Turniere** werden an Standorten ausgetragen und gehören zu Ligen
- **Ligen** haben Spieltage (Parties) und Teams
- **Spieltage** bestehen aus Spielen zwischen Teams
- **Spiele** werden von Spielern bestritten

## Vollständiges ER-Diagramm

```mermaid
erDiagram
    Region ||--o{ Club : "hat viele"
    Region ||--o{ Tournament : "organisiert"
    Region ||--o{ League : "organisiert"
    
    Club ||--o{ Location : "hat viele über club_locations"
    Club ||--o{ LeagueTeam : "hat viele"
    Club ||--o{ Tournament : "organisiert"
    Club ||--o{ SeasonParticipation : "hat viele"
    
    Tournament ||--o{ Game : "hat viele"
    Tournament ||--o{ Seeding : "hat viele"
    Tournament ||--o{ Team : "hat viele"
    Tournament ||--o{ Location : "verwendet"
    Tournament ||--o{ League : "gehört zu"
    
    League ||--o{ LeagueTeam : "hat viele"
    League ||--o{ Party : "hat viele"
    League ||--o{ Tournament : "hat viele"
    
    Party ||--o{ Game : "hat viele"
    Party ||--o{ PartyGame : "hat viele"
    Party ||--o{ Seeding : "hat viele"
    Party ||--o{ Location : "verwendet"
    Party ||--o{ LeagueTeam : "hat Teams"
    
    Location ||--o{ Party : "veranstaltet"
    Location ||--o{ Tournament : "veranstaltet"
    Location ||--o{ Club : "gehört zu vielen"
    
    LeagueTeam ||--o{ Party : "nimmt teil an"
    LeagueTeam ||--o{ Seeding : "hat viele"
    
    Game ||--o{ GameParticipation : "hat viele"
    Game ||--o{ PartyGame : "hat viele"
    
    Player ||--o{ GameParticipation : "hat viele"
    Player ||--o{ SeasonParticipation : "hat viele"
    Player ||--o{ Seeding : "hat viele"
    Player ||--o{ PartyGame : "spielt in"
    
    SeasonParticipation ||--o{ Player : "gehört zu"
    SeasonParticipation ||--o{ Club : "gehört zu"
    SeasonParticipation ||--o{ Season : "gehört zu"
    
    Seeding ||--o{ Player : "gehört zu"
    Seeding ||--o{ Tournament : "gehört zu"
    Seeding ||--o{ LeagueTeam : "gehört zu"
    Seeding ||--o{ Discipline : "hat"

    PartyGame ||--o{ Party : "gehört zu"
    PartyGame ||--o{ Player : "hat Spieler"
    PartyGame ||--o{ Discipline : "hat"
    PartyGame ||--o{ Game : "gehört zu"

    GameParticipation ||--o{ Game : "gehört zu"
    GameParticipation ||--o{ Player : "gehört zu"

    %% Entitätsdefinitionen mit ihren Schlüsselattributen
    Region {
        int id PK
        string name
        string shortname
    }

    Club {
        int id PK
        string name
        string shortname
        int region_id FK
    }

    Tournament {
        int id PK
        string title
        int organizer_id FK
        string organizer_type
        int location_id FK
        int league_id FK
    }

    League {
        int id PK
        string name
        int organizer_id FK
        string organizer_type
    }

    Party {
        int id PK
        int league_id FK
        int location_id FK
        int league_team_a_id FK
        int league_team_b_id FK
    }

    Location {
        int id PK
        string name
        int club_id FK
    }

    LeagueTeam {
        int id PK
        int league_id FK
        int club_id FK
        string name
    }

    PartyGame {
        int id PK
        int party_id FK
        int player_id FK
        int discipline_id FK
        int game_id FK
    }

    Game {
        int id PK
        int tournament_id FK
        int party_id FK
        string status
        datetime start_time
        datetime end_time
    }

    GameParticipation {
        int id PK
        int game_id FK
        int player_id FK
        string role
        int score
    }

    Player {
        int id PK
        string name
        string email
        int club_id FK
    }

    Seeding {
        int id PK
        int tournament_id FK
        int player_id FK
        int league_team_id FK
        int discipline_id FK
        int position
    }

    SeasonParticipation {
        int id PK
        int season_id FK
        int player_id FK
        int club_id FK
        string status
    }

    Discipline {
        int id PK
        string name
        string description
    }
```

## Beziehungsarten

### 1:1 (Eins-zu-Eins)
- **Ein Spieler** hat **eine E-Mail-Adresse**
- **Ein Spiel** hat **einen Status**

### 1:N (Eins-zu-Viele)
- **Eine Region** hat **viele Vereine**
- **Ein Verein** hat **viele Standorte**
- **Ein Turnier** hat **viele Spiele**

### N:M (Viele-zu-Viele)
- **Vereine** haben **viele Standorte** über `club_locations`
- **Spieler** spielen in **vielen Spielen** über `game_participations`
- **Spiele** gehören zu **vielen Spieltagen** über `party_games`

## Schlüsselattribute

### Primärschlüssel (PK)
- `id`: Eindeutige Identifikation jeder Entität
- Auto-increment Integer-Werte

### Fremdschlüssel (FK)
- `region_id`: Verweis auf die übergeordnete Region
- `club_id`: Verweis auf den zugehörigen Verein
- `tournament_id`: Verweis auf das Turnier
- `league_id`: Verweis auf die Liga
- `location_id`: Verweis auf den Standort
- `player_id`: Verweis auf den Spieler

## Datenintegrität

### Referentielle Integrität
- Alle Fremdschlüssel verweisen auf gültige Primärschlüssel
- CASCADE-Löschungen für abhängige Datensätze
- RESTRICT-Löschungen für kritische Beziehungen

### Geschäftsregeln
- Ein Spieler kann nur in einem Verein pro Saison sein
- Ein Turnier kann nur an einem Standort stattfinden
- Ein Spieltag gehört zu genau einer Liga

## Erweiterte Beziehungen

### Polymorphe Beziehungen
```ruby
# Tournament kann von Region oder Club organisiert werden
belongs_to :organizer, polymorphic: true

# Verwendung
tournament.organizer_type # "Region" oder "Club"
tournament.organizer_id   # ID der organiserenden Entität
```

### Durchgangstabellen
```ruby
# club_locations verbindet Clubs und Locations
class ClubLocation < ApplicationRecord
  belongs_to :club
  belongs_to :location
end
```

## Performance-Optimierungen

### Indizes
- Alle Fremdschlüssel sind indiziert
- Zusammengesetzte Indizes für häufige Abfragen
- Unique-Indizes für Geschäftsregeln

### Abfrageoptimierung
- Eager Loading für N+1-Problem vermeiden
- Scopes für häufige Filter
- Counter Caches für Zählungen

## Datenmodell-Änderungen

### Migrationen
```bash
# Neue Tabelle erstellen
rails generate migration CreateNewTable

# Spalte hinzufügen
rails generate migration AddColumnToTable

# Migration ausführen
rails db:migrate
```

### Rollback
```bash
# Letzte Migration rückgängig machen
rails db:rollback

# Zu bestimmter Version zurückkehren
rails db:migrate VERSION=20231201000000
```

## Monitoring und Wartung

### Datenbankgröße
- Regelmäßige Überprüfung der Tabellengrößen
- Archivierung alter Daten
- Cleanup von gelöschten Datensätzen

### Performance-Überwachung
- Langsame Abfragen identifizieren
- Indizes optimieren
- Query-Pläne analysieren

## Best Practices

### Modellierung
- **Normalisierung**: Vermeiden Sie Redundanz
- **Denormalisierung**: Für Performance bei Bedarf
- **Konsistenz**: Einheitliche Namenskonventionen

### Entwicklung
- **Migrationen**: Immer reversibel gestalten
- **Validierungen**: Auf Modell- und Datenbankebene
- **Tests**: Datenbanklogik testen

### Wartung
- **Backups**: Regelmäßige Sicherungen
- **Updates**: Datenbank-Updates planen
- **Monitoring**: Performance kontinuierlich überwachen 