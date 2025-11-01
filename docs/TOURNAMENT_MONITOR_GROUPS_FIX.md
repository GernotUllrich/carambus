# Fix: Falsche Spielerzuordnung im Tournament Monitor (Halbfinale)

## Problem

**Symptom:** Im Halbfinale 2 (hf2) erschien plötzlich "Michael Ernst", der nicht in der ursprünglichen Setzliste war.

**Tournament:** ID 17068, TournamentMonitor ID 50000002, Plan: T10

### Root Cause Analyse

1. **Das Kernproblem:** Player-Objekte wurden als JSON-Hashes serialisiert
   - `distribute_to_group()` gab Player-Objekte zurück
   - Diese wurden in `data["groups"]` als JSON-Hashes gespeichert
   - Beim Laden aus der Datenbank waren es Hashes statt Objekte

2. **Die Inkonsistenz:**
   - `group_rank()` Methode rief `distribute_to_group()` NEU auf → Player-Objekte → `.id` funktionierte
   - `tournament_monitor_support.rb` las aus `data["groups"]` → JSON-Hashes → `a["id"]` wurde verwendet
   - Beim Speichern wurden Player-Objekte zu Hashes konvertiert, was zu falschen IDs führte

3. **Der spezifische Fall:**
   - hf2 sollte: `["g2.rk1", "g1.rk2"]` = [1. Platz Gruppe 2, 2. Platz Gruppe 1]
   - `g1.rk2` wurde via `ko_ranking()` aus `data["rankings"]["groups"]["group1"]` geholt
   - Das Ranking war falsch, weil Michael Ernst (64636) fälschlicherweise auf Rang 2 stand
   - Michael Ernst hatte KEINE GameParticipations in Gruppe 1!

## Lösung

### Geänderte Dateien

1. **`app/models/tournament_monitor.rb`**
   - `distribute_to_group()`: Speichert jetzt Player-IDs (Integer) statt Player-Objekte
   - `group_rank()`: Gibt jetzt direkt die ID zurück (keine `.id` Aufruf mehr)

2. **`lib/tournament_monitor_support.rb`**
   - Drei Stellen, wo auf `data["groups"]["group#{group_no}"]` zugegriffen wird
   - Geändert von `a["id"] == winner1` zu `player_id == winner1`
   - Die Arrays enthalten jetzt direkt Integer-IDs statt JSON-Hashes

### Technische Details

**Vorher:**
```ruby
# distribute_to_group gab Player-Objekte zurück
groups["group1"] = [<Player:264>, <Player:258>, <Player:257>]

# Nach JSON-Serialisierung:
data["groups"]["group1"] = [
  {"id"=>264, "lastname"=>"Smrcka", ...},
  {"id"=>258, "lastname"=>"Meyer", ...},
  {"id"=>257, "lastname"=>"Meißner", ...}
]

# Zugriff war inkonsistent:
a["id"]  # in tournament_monitor_support.rb
obj.id   # in group_rank nach Neuberechnung
```

**Nachher:**
```ruby
# distribute_to_group gibt IDs zurück
groups["group1"] = [264, 258, 257]

# Nach JSON-Serialisierung (unverändert):
data["groups"]["group1"] = [264, 258, 257]

# Zugriff ist konsistent:
player_id  # überall
```

## Test-Anleitung

### 1. Backup der aktuellen Datenbank

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
RAILS_ENV=development rails db:dump  # oder entsprechendes Backup
```

### 2. Code nach carambus_bcw deployen

```bash
# Im carambus_master (wo die Änderungen sind):
git add .
git commit -m "Fix: Tournament Monitor speichert Player-IDs statt Player-Objekte in groups"
git push

# Im carambus_bcw:
git pull
```

### 3. Neues Test-Turnier erstellen

**WICHTIG:** Das bestehende Turnier 17068 ist bereits korrumpiert. Man muss ein NEUES Turnier erstellen!

```ruby
# Rails Console in carambus_bcw
t = Tournament.find(17068)

# Neues Test-Turnier erstellen
new_t = t.dup
new_t.title = "TEST - #{t.title}"
new_t.save!

# Seedings kopieren
t.seedings.each do |s|
  new_s = s.dup
  new_s.tournament = new_t
  new_s.save!
end

# TournamentMonitor erstellen und initialisieren
tm = new_t.create_tournament_monitor!
tm.reset_tournament_monitor!

puts "Neues Tournament: #{new_t.id}"
puts "Neuer TournamentMonitor: #{tm.id}"
```

### 4. Verifikation

```ruby
# Prüfe groups Datenstruktur
tm = TournamentMonitor.find(NEUE_TM_ID)
groups = tm.data['groups']

# SOLLTE jetzt sein: Arrays von Integer-IDs
groups['group1']  # => [264, 258, 257]  (NICHT Hashes!)

# Teste ein Spiel durchführen
# ... (Gruppenspiele spielen)

# Nach Gruppenphase: Prüfe Halbfinale
tm.reload
hf2_game = tm.tournament.games.find_by(gname: 'hf2')

# Prüfe ob die richtigen Spieler zugeordnet sind
puts "hf2 playera: #{hf2_game.game_participations.find_by(role: 'playera').player.name}"
puts "hf2 playerb: #{hf2_game.game_participations.find_by(role: 'playerb').player.name}"

# Sollte sein:
#  playera: 1. Platz aus Gruppe 2 (laut Rankings)
#  playerb: 2. Platz aus Gruppe 1 (laut Seedings-Position!)
```

### 5. Erwartetes Ergebnis

- `data["groups"]["group1"]` enthält `[264, 258, 257]` (Integer-IDs)
- Keine Player-Hashes mehr
- hf2 hat die korrekten Spieler basierend auf Setzliste, nicht auf falschen Rankings

## Migrations-Hinweis

**Alte Turniere (bereits korrumpiert):**
- Können NICHT automatisch repariert werden
- `data["groups"]` enthält bereits falsche Hashes
- Müssen entweder manuell korrigiert oder neu gestartet werden

**Neue Turniere (nach dem Fix):**
- Funktionieren korrekt
- `data["groups"]` enthält nur Integer-IDs

## Commit Info

**Branch:** master
**Files geändert:**
- `app/models/tournament_monitor.rb`
- `lib/tournament_monitor_support.rb`

**Datum:** 2025-11-01

