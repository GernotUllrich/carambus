# Automatische Setzlisten-Extraktion aus Einladungen

## Feature Overview

Dieses Feature ermöglicht das **automatische Auslesen der Setzliste** aus der offiziellen Turnier-Einladung (PDF oder Screenshot).

### Vorher (manuell):
1. PDF-Einladung öffnen
2. Jeden Spieler einzeln abtippen
3. Reihenfolge manuell setzen
4. ⏱️ Zeit: 5-10 Minuten

### Nachher (automatisch):
1. PDF oder Screenshot hochladen
2. Automatische Extraktion
3. Prüfen & bestätigen  
4. ⏱️ Zeit: 30 Sekunden

## Workflow

### Neue Schritte-Reihenfolge

**VORHER:**
1. Setzliste aktualisieren
2. Mit ClubCloud synchronisieren
3. Nach Rangliste sortieren
4. Rangliste abschließen

**NACHHER:**
1. **Meldeliste** von ClubCloud laden (wer hat sich angemeldet)
2. **Setzliste** aus Einladung übernehmen (offizielle Reihenfolge) ← NEU!
3. **Teilnehmerliste** bearbeiten (wer ist tatsächlich da, am Turniertag)
4. **Teilnehmerliste** finalisieren
5. Turniermodus wählen
6. Turnier starten

### Begriffsklärung

- **Meldeliste** = Anmeldungen aus ClubCloud
- **Setzliste** = Offizielle Reihenfolge nach Ranking (aus Einladung)
- **Teilnehmerliste** = Tatsächliche Teilnehmer (Setzliste ± Änderungen vor Ort)

## Technische Implementierung

### Komponenten

1. **SeedingListExtractor Service**
   - Extrahiert Text aus PDF (`pdf-reader` gem)
   - Extrahiert Text aus Screenshots via OCR (`rtesseract` gem)
   - Parst Spielerliste mit Regex
   - Matched mit Datenbank

2. **Controller Actions**
   - `compare_seedings` - Vergleichsansicht
   - `upload_invitation` - Upload-Handler
   - `parse_invitation` - Automatische Extraktion
   - `apply_seeding_order` - Reihenfolge übernehmen

3. **Views**
   - `compare_seedings.html.erb` - Upload-Interface
   - `parse_invitation.html.erb` - Ergebnis-Anzeige

### Abhängigkeiten

#### Ruby Gems

```ruby
# Gemfile
gem 'pdf-reader', '~> 2.12'       # PDF-Text-Extraktion
gem 'rtesseract', '~> 3.1'        # OCR für Screenshots
```

#### System-Pakete (für OCR)

**macOS:**
```bash
brew install tesseract
brew install tesseract-lang  # für deutsche Texte
```

**Ubuntu/Debian:**
```bash
sudo apt-get install tesseract-ocr
sudo apt-get install tesseract-ocr-deu
```

### Installation

```bash
# 1. Gems installieren
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
bundle install

# 2. Tesseract installieren (für Screenshot-OCR)
brew install tesseract tesseract-lang

# 3. Assets kompilieren
yarn build:css
```

## Verwendung

### 1. PDF hochladen

```
Tournament → Schritt 2: "Setzliste aus Einladung übernehmen"
→ "Einladung hochladen"
→ PDF oder Screenshot auswählen
→ "Hochladen & automatisch parsen"
```

### 2. Ergebnis prüfen

Das System zeigt:
- ✅ **Erfolgreich zugeordnete Spieler** (grün)
- ⚠️ **Vermutete Zuordnungen** (gelb, unsicher)
- ❌ **Nicht gefundene Spieler** (rot, müssen manuell hinzugefügt werden)

### 3. Bestätigen

```
→ Liste prüfen
→ "Setzliste übernehmen"
→ Fertig!
```

## Parsing-Logik

Der Extractor sucht nach diesem Pattern:

```
Setzliste
---------
1. Smrcka, Martin
2. Kiehn, Ulf
3. Lorkowski, Joshua
...
```

**Unterstützte Formate:**
- `1. Nachname, Vorname`
- `1 Nachname Vorname`
- `1. Vorname Nachname`

**Stoppt bei:**
- "Gruppenbildung"
- "Turniermodus"
- Anderen Überschriften

## Edge Cases

### Fall 1: Spieler nicht in Meldeliste

```
Erkannt: "Ernst, Michael"
Status: ❌ Nicht in Meldeliste

→ Lösung: In Schritt 3 manuell hinzufügen
```

### Fall 2: Name falsch erkannt (OCR-Fehler)

```
Erkannt: "Sch röder" (Leerzeichen durch OCR-Fehler)
Zugeordnet: "Schröder, Hans-Jörg" (⚠️ Vermutung)

→ Lösung: Manuell prüfen, ggf. korrigieren
```

### Fall 3: PDF ist Scan (Bild in PDF)

```
→ PDF-Reader kann keinen Text extrahieren
→ Automatischer Fallback auf OCR
→ Funktioniert wie bei Screenshot
```

## Testing

### Test mit Beispiel-PDF

```ruby
# Rails Console
t = Tournament.find(17068)
file_path = '/path/to/einladung.pdf'

result = SeedingListExtractor.extract_from_file(file_path)
puts result.inspect

# Sollte zeigen:
# {
#   success: true,
#   players: [
#     { position: 1, lastname: "Smrcka", firstname: "Martin", ... },
#     ...
#   ],
#   count: 7
# }
```

### Test mit Screenshot

```ruby
# Rails Console
file_path = '/path/to/screenshot.png'
result = SeedingListExtractor.extract_from_file(file_path)
```

## Bekannte Limitationen

1. **OCR-Qualität**
   - Hängt von Screenshot-Qualität ab
   - Deutsche Umlaute (ä, ö, ü) manchmal problematisch
   - Funktioniert am besten mit klaren, hochauflösenden Screenshots

2. **PDF-Struktur**
   - Funktioniert nur bei Text-PDFs
   - Gescannte PDFs werden automatisch per OCR verarbeitet
   - Layout muss "Setzliste" Header haben

3. **Name-Matching**
   - Exact Match bevorzugt
   - Fuzzy-Match für Tippfehler
   - Bei mehreren Spielern mit ähnlichem Namen: Manuelle Prüfung

## Fallback

Falls automatische Extraktion fehlschlägt:

```
❌ Extraktion fehlgeschlagen

Alternativen:
[Andere Datei hochladen]
[Manuell sortieren]
[ClubCloud-Reihenfolge verwenden]
```

## Future Improvements

- [ ] ML-basierte Extraktion (bessere Genauigkeit)
- [ ] Unterstützung für mehr PDF-Layouts
- [ ] Automatische Korrektur von OCR-Fehlern
- [ ] Batch-Processing für mehrere Turniere
- [ ] Vorschau des hochgeladenen PDFs in der UI

## Commit Info

**Branch:** feature/tournament-wizard-ui  
**Files:**
- `app/services/seeding_list_extractor.rb` - Extraktions-Logik
- `app/controllers/tournaments_controller.rb` - Upload & Processing
- `app/views/tournaments/compare_seedings.html.erb` - Upload-UI
- `app/views/tournaments/parse_invitation.html.erb` - Ergebnis-Anzeige
- `config/routes.rb` - Neue Routes
- `Gemfile` - PDF/OCR Gems

## New Features: Rankings & Tournament Plan Preview (2025-11)

### Overview

Enhanced the tournament wizard with:
1. **Effective Ranking Display** in participant list
2. **Real-time Tournament Plan Preview** with group assignments
3. **Alternative Path:** Proceed without invitation using Carambus rankings
4. **Performance Optimization:** Ranking caching

### 1. Effective Ranking Calculation

**Problem:** Rankings were based on a single season, outdated for players who didn't play recently.

**Solution:** `effective_gd` logic - uses newest available season from last 2-3 years.

**Implementation:**

```ruby
# app/models/tournament.rb
def calculate_and_cache_rankings
  current_season = Season.current_season
  seasons = Season.where('id <= ?', current_season.id).order(id: :desc).limit(3).reverse
  
  # Load all rankings for discipline and region
  all_rankings = PlayerRanking.where(
    discipline_id: discipline_id,
    season_id: seasons.pluck(:id),
    region_id: organizer_id
  ).to_a
  
  # Group by player
  rankings_by_player = all_rankings.group_by(&:player_id)
  
  # Calculate effective_gd for each player
  player_effective_gd = {}
  rankings_by_player.each do |player_id, rankings|
    gd_values = seasons.map do |season|
      ranking = rankings.find { |r| r.season_id == season.id }
      ranking&.gd
    end
    # Take newest available season
    effective_gd = gd_values[2] || gd_values[1] || gd_values[0]
    player_effective_gd[player_id] = effective_gd if effective_gd.present?
  end
  
  # Sort players by effective_gd and assign ranks
  sorted_players = player_effective_gd.sort_by { |player_id, gd| -gd }
  player_rank = {}
  sorted_players.each_with_index do |(player_id, gd), index|
    player_rank[player_id] = index + 1
  end
  
  # Cache in tournament.data
  self.data['player_rankings'] = player_rank
  save!
end
```

**Triggered by:**
- State machine: `after_enter` callback on `tournament_seeding_finished`
- Fallback: `before_action :ensure_rankings_cached` in show action
- Only for local tournaments (`id >= Tournament::MIN_ID`)

### 2. Tournament Plan Preview

**Feature:** Shows possible tournament plans with dynamic group assignments in Step 3.

**Implementation:**

```ruby
# app/controllers/tournaments_controller.rb - define_participants action
@participant_count = @tournament.seedings.where.not(state: "no_show").where(@seeding_scope).count

# Find proposed plan (from invitation or automatic)
@proposed_discipline_tournament_plan = ::TournamentPlan.joins(:discipline_tournament_plans)
  .where(discipline_tournament_plans: {
    players: @participant_count,
    discipline_id: @tournament.discipline_id
  }).first

# Calculate group assignments using NBV algorithm
@groups = TournamentMonitor.distribute_to_group(
  @tournament.seedings.where.not(state: "no_show").order(:position).map(&:player), 
  @proposed_discipline_tournament_plan.ngroups,
  @proposed_discipline_tournament_plan.group_sizes
)

# Find alternatives (same discipline, other disciplines)
@alternatives_same_discipline = ::TournamentPlan.joins(:discipline_tournament_plans)
  .where.not(id: @proposed_discipline_tournament_plan.id)
  .where(discipline_tournament_plans: { players: @participant_count, discipline_id: @tournament.discipline_id })
  .limit(3)

@alternatives_other_disciplines = ::TournamentPlan
  .where.not(name: ['Default%', 'KO%'])  # Exclude default and KO plans
  .where(players: @participant_count)
```

**Real-time Updates:**

```ruby
# app/reflexes/tournament_reflex.rb
def change_seeding
  # ... update seeding ...
  morph :page  # Re-render entire page to update group assignments
end

def move_up / move_down
  # ... move seeding ...
  morph :page  # Re-render to show new group assignments
end
```

### 3. Alternative Path: No Invitation

**Problem:** Not all tournaments have invitations uploaded.

**Solution:** Button "→ Mit Meldeliste zu Schritt 3" in Step 2.

**Implementation:**

```ruby
# app/controllers/tournaments_controller.rb
def use_clubcloud_as_participants
  # Convert ClubCloud seedings to local seedings
  clubcloud_seedings.each do |cc_seeding|
    @tournament.seedings.create!(
      player_id: cc_seeding.player_id,
      balls_goal: cc_seeding.balls_goal
    )
  end
  
  # Sort by effective ranking (same logic as calculate_and_cache_rankings)
  # Calculate effective rankings for all players
  # ... (ranking calculation) ...
  
  # Sort seedings by effective ranking
  sorted.each_with_index do |a, ix|
    seeding, = a
    seeding.update(position: ix + 1)
  end
  
  redirect_to define_participants_tournament_path(@tournament)
end
```

### 4. Performance Optimization

**Problem:** Expensive ranking calculation on every page load.

**Solution:** Cache rankings in `tournament.data['player_rankings']`.

**Benefits:**
- Rankings calculated once (when seedings finalized)
- Read from cache on every subsequent access
- No DB queries for ranking calculation during tournament
- Rankings don't change during tournament → safe to cache

**Files:**
- `app/models/tournament.rb` - Ranking calculation & caching
- `app/controllers/tournaments_controller.rb` - Fallback for old tournaments
- `app/views/tournaments/define_participants.html.erb` - Ranking display
- `app/views/tournaments/_tournament_status.html.erb` - Tournament status with rankings
- `app/reflexes/tournament_reflex.rb` - Real-time updates

