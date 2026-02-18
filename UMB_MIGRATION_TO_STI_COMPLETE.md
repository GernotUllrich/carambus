# UMB Migration zu STI - Abgeschlossen

## Datum: 2026-02-18

## Was wurde gemacht

### 1. Schema-Erweiterungen

**Migrations erfolgreich ausgeführt:**
- `AddStiFieldsToTournaments` - Tournament Tabelle um STI vorbereitet
  - `type` (string) - für STI
  - `external_id` (string) - für UMB Tournament ID
  - `international_source_id` (bigint) - Referenz zu InternationalSource
  - Indexes für alle neuen Spalten

**Alte Tabellen entfernt:**
- `international_tournaments` → jetzt Teil von `tournaments` (via STI)
- `international_participations` → jetzt `seedings`
- `international_results` → wird `game_participations` (finale Rankings)
- `international_videos` → nicht mehr gebraucht
- `games.international_tournament_id` → nicht mehr gebraucht

**Behalten:**
- `international_sources` - für Data Source Tracking (UMB, CPB, etc.)
- `players.umb_player_id` - für UMB Player ID
- `players.nationality` - für Nationalität

### 2. STI Model erstellt

**`InternationalTournament < Tournament`**
```ruby
class InternationalTournament < Tournament
  belongs_to :international_source
  
  # Erbt von Tournament:
  # - has_many :seedings
  # - has_many :games
  # - has_many :players, through: :seedings
  
  # Helper für JSON data:
  # - tournament_type
  # - country
  # - organizer
  # - pdf_links
end
```

### 3. Carambus Datenmodell

```
InternationalTournament (type='InternationalTournament' in tournaments)
  ├─ Seeding (Teilnehmerliste/Players List)
  │    └─ Player (mit umb_player_id, nationality)
  └─ Game (Einzelspiele)
       └─ GameParticipation (Spieler-Teilnahme an Game, für Rankings)
```

## Nächste Schritte

### 4. UmbScraper anpassen

Der Scraper muss umgeschrieben werden um:
- `InternationalTournament.new` statt eigene Tabelle
- `Seeding.new` statt `InternationalParticipation`
- `Game.new` + `GameParticipation.new` für Spiele

### 5. PDF Parsing für Games

Players List PDF → Seedings ✓ (bereits vorhanden)
Final Ranking PDF → Games + GameParticipations (TODO)
Groups PDF → Games + GameParticipations (TODO)

### 6. Testing

- 2 Test-Turniere komplett scraen
- Prüfen: Seedings, Games, GameParticipations
- Rankings berechnen

## Vorteile des neuen Modells

1. **Einheitliche Struktur** - Internationale und deutsche Turniere nutzen gleiche Tabellen
2. **Weniger Komplexität** - Keine parallelen Modelle mehr
3. **Ranking-Berechnung** - Funktioniert sofort mit bestehendem Code
4. **Synchronisation** - Über Version records (papertrail) zu anderen Instanzen möglich

## Lessons Learned

- Bei wenig Daten: Neustart ist besser als Migration
- STI ist die richtige Wahl für ähnliche Entities
- Carambus Datenmodell (Tournament/Seeding/Game/GameParticipation) ist sehr flexibel
