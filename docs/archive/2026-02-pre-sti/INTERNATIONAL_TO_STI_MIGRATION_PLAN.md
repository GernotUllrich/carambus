# Migration Plan: International* Models → Tournament/Game STI

## 🎯 Ziel

Bestehende parallele International* Models in das Hauptsystem mit Single Table Inheritance (STI) migrieren.

## 📊 Aktuelle Situation

### Bestehende Daten:
```
InternationalTournaments: 47
InternationalParticipations: 322
InternationalResults: 0
InternationalPlayers: 250
InternationalSources: 19

Tournaments: 17,689 (Deutsche Turniere)
Games: 292,694
GameParticipations: 494,457
Players: 61,736 (250 davon international)
```

### Bestehende Struktur:
```
International* (Parallel System)          →    Haupt-System (STI)
─────────────────────────────────────────     ────────────────────────
InternationalTournament                   →    Tournament (type: 'InternationalTournament')
InternationalParticipation                →    GameParticipation (für Seeding/Anmeldung)
InternationalResult                       →    Game + GameParticipation (für finale Platzierung)
InternationalGame (nicht existent)        →    Game (type: 'InternationalGame')
InternationalSource                       →    Bleibt bestehen (Metadaten-Quelle)
InternationalVideo                        →    Bleibt bestehen (Video-Archiv)
Player.international_player               →    Player (bleibt, kein STI nötig)
```

## 🗺️ Mapping-Strategie

### 1. Tournament Mapping

**InternationalTournament → Tournament:**
```ruby
InternationalTournament:
  - name                     → title
  - discipline_id            → discipline_id (1:1)
  - tournament_type          → data['tournament_type']
  - start_date               → date
  - end_date                 → end_date (1:1)
  - location                 → location_text (oder location_id?)
  - country                  → data['country']
  - organizer                → data['organizer']
  - prize_money              → data['prize_money']
  - source_url               → source_url (1:1)
  - external_id              → data['external_id']
  - international_source_id  → data['international_source_id']
  - data                     → data (merge)
  
  NEU:
  - type                     → 'InternationalTournament'
  - modus                    → 'international' (oder aus tournament_type)
  - single_or_league         → 'single'
```

### 2. Participation Mapping

**Problem:** `InternationalParticipation` ist **keine Partie**, sondern nur die **Anmeldung/Seeding**.

**Lösungen:**

**Option A: Behalten als Seeding-Information**
- `InternationalParticipation` bleibt für Seeding/Anmeldungen
- Erst wenn Spiele geparst werden, entstehen `Games` + `GameParticipations`

**Option B: Als "Pseudo-Game" speichern**
- Jede Participation wird zu einem `Game` (type: 'SeedingEntry')
- Mit einer `GameParticipation` pro Spieler

**Option C: Neues Seeding-Model**
- `TournamentSeeding` (STI von `Game`?)
- Oder separates Model

**Empfehlung:** Option A - InternationalParticipation BEHALTEN für Seedings

### 3. Game Mapping (NEU zu implementieren)

**PDF Results → Game + GameParticipation:**

**Beispiel aus Semi-Final PDF:**
```
TRAN Thanh Luc    VN    50    27    0    1.851    2    8
JASPERS Dick      NL    37    27    0    1.370    0    6
```

**Wird zu:**
```ruby
Game:
  - tournament_id: (aus InternationalTournament)
  - type: 'InternationalGame'
  - round_no: 'Semi_Final' (oder numerisch?)
  - seqno: 1
  - data: { round_name: 'Semi_Final', pdf_source: '...' }

GameParticipation (für TRAN):
  - game_id: (von oben)
  - player_id: (TRAN's Player)
  - points: 50 (T-Car)
  - innings: 27 (T-Inn)
  - result: 'won' (MP=2)
  - data: { penalty: 0, average: 1.851, match_points: 2, highest_run: 8 }

GameParticipation (für JASPERS):
  - game_id: (von oben)
  - player_id: (JASPERS's Player)
  - points: 37
  - innings: 27
  - result: 'lost' (MP=0)
  - data: { penalty: 0, average: 1.370, match_points: 0, highest_run: 6 }
```

## 🔧 Migrations-Schritte

### Phase 1: Schema erweitern

#### Migration 1: Tournament erweitern für STI
```ruby
# db/migrate/YYYYMMDDHHMMSS_add_sti_to_tournaments.rb
class AddStiToTournaments < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    # Add type column for STI
    add_column :tournaments, :type, :string unless column_exists?(:tournaments, :type)
    add_index :tournaments, :type, algorithm: :concurrently
    
    # Add international_source_id to tournaments
    add_reference :tournaments, :international_source, foreign_key: true, index: false
    add_index :tournaments, :international_source_id, algorithm: :concurrently
    
    # Add external_id for international tournaments
    add_column :tournaments, :external_id, :string
    add_index :tournaments, [:external_id, :international_source_id], 
              unique: true, 
              name: 'idx_tournaments_on_external_id_and_source',
              algorithm: :concurrently
  end
end
```

#### Migration 2: Game erweitern (bereits teilweise gemacht)
```ruby
# Already have: add_international_tournament_id_to_games
# Need: ensure type column exists
```

### Phase 2: Daten migrieren

#### Migration 3: Daten von InternationalTournament → Tournament
```ruby
class MigrateInternationalTournamentsToTournaments < ActiveRecord::Migration[7.2]
  def up
    # Migrate each InternationalTournament to Tournament
    InternationalTournament.find_each do |intl_t|
      tournament = Tournament.new(
        type: 'InternationalTournament',
        title: intl_t.name,
        discipline_id: intl_t.discipline_id,
        date: intl_t.start_date,
        end_date: intl_t.end_date,
        location_text: intl_t.location,
        source_url: intl_t.source_url,
        international_source_id: intl_t.international_source_id,
        external_id: intl_t.external_id,
        modus: 'international',
        single_or_league: 'single',
        data: {
          tournament_type: intl_t.tournament_type,
          country: intl_t.country,
          organizer: intl_t.organizer,
          prize_money: intl_t.prize_money&.to_s,
          original_international_tournament_id: intl_t.id,
          migrated_from_international: true,
          **intl_t.data
        }.to_json
      )
      
      if tournament.save(validate: false)
        # Store mapping for later reference
        intl_t.update_column(:data, intl_t.data.merge(migrated_to_tournament_id: tournament.id))
      end
    end
  end
  
  def down
    Tournament.where(type: 'InternationalTournament').delete_all
  end
end
```

### Phase 3: Cleanup

#### Migration 4: Drop International* Tables (optional - erst nach Tests!)
```ruby
class DropInternationalTables < ActiveRecord::Migration[7.2]
  def up
    drop_table :international_participations
    drop_table :international_results
    drop_table :international_tournaments
  end
  
  def down
    # Cannot restore - backup first!
    raise ActiveRecord::IrreversibleMigration
  end
end
```

## ⚠️ Wichtige Überlegungen

### 1. InternationalParticipation vs GameParticipation

**Problem:** 
- `InternationalParticipation` = Seeding/Anmeldung (kein Spiel!)
- `GameParticipation` = Teilnahme an einem konkreten Spiel

**Sind das die gleichen Dinge?** NEIN!

**Lösung:** 
- InternationalParticipation BEHALTEN für Seedings
- Erst wenn Games aus PDFs geparst werden → GameParticipations erstellen

### 2. InternationalResult vs Game

**Problem:**
- `InternationalResult` = Finale Platzierung (Rank 1, 2, 3...)
- `Game` = Ein konkretes Spiel (Player A vs Player B)

**Sind das die gleichen Dinge?** NEIN!

**Lösung:**
- InternationalResult könnte als `data` in Tournament gespeichert werden
- ODER: InternationalResult BEHALTEN für Ranglisten
- Games werden separat aus Match-PDFs geparst

### 3. Welche Models brauchen wir wirklich?

**BEHALTEN:**
- ✅ `InternationalSource` - Metadaten für Scraping-Quellen
- ✅ `InternationalVideo` - Video-Archiv
- ✅ `InternationalParticipation` - Seeding/Anmeldungen (KEIN Spiel!)
- ✅ `InternationalResult` - Finale Ranglisten (KEIN Spiel!)

**MIGRIEREN zu Tournament (STI):**
- ✅ `InternationalTournament` → `Tournament` (type: 'InternationalTournament')

**NEU ERSTELLEN (aus PDFs):**
- ✅ `Game` (type: 'InternationalGame') - für Match-Results aus PDFs
- ✅ `GameParticipation` - für Spieler in Games

## 🤔 Frage zur Klärung

Bevor ich weitermache - bitte bestätige:

### Frage 1: InternationalParticipation
**Was ist das genau?**
- A) Nur Seeding/Anmeldung (kein Spiel) → BEHALTEN
- B) Ein "Pseudo-Spiel" für Platzierung → zu Game migrieren
- C) Etwas anderes?

### Frage 2: InternationalResult
**Was ist das genau?**
- A) Finale Rangliste (1. Platz, 2. Platz...) → BEHALTEN
- B) Ein Spiel-Ergebnis → zu Game migrieren
- C) Etwas anderes?

### Frage 3: Migration-Umfang
**Was soll migriert werden?**
- A) NUR InternationalTournament → Tournament (STI)
- B) InternationalTournament → Tournament + neue Games aus PDFs
- C) ALLES (Tournament, Participation, Result)

## 💡 Meine Empfehlung

**Minimale Migration (Empfohlen):**

1. ✅ `InternationalTournament` → `Tournament` (type: 'InternationalTournament')
2. ✅ BEHALTEN: `InternationalParticipation` (für Seedings)
3. ✅ BEHALTEN: `InternationalResult` (für finale Ranglisten)
4. ✅ NEU: `Game` (type: 'InternationalGame') für Match-Results aus PDFs
5. ✅ `InternationalSource` & `InternationalVideo` bleiben

**Begründung:**
- Participation und Result sind **Meta-Daten**, keine Spiele
- Games aus PDFs sind **echte Spiele** (Player vs Player)
- Minimaler Migrations-Aufwand
- Keine Datenverluste

**Bitte bestätige oder korrigiere meinen Plan!**
