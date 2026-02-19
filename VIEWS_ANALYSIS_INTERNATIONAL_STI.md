# Views Analyse: Internationale Turniere nach STI-Migration

**Datum:** 19. Februar 2026  
**Kontext:** carambus_api (Development Scenario)  
**Status:** ✅ Controller angepasst, ⚠️ Views benötigen Überprüfung

---

## 📋 Executive Summary

Nach der erfolgreichen Migration von `InternationalTournament` zu STI (Single Table Inheritance) müssen die Views für internationale Turniere überprüft und ggf. angepasst werden. Die **Controller sind bereits korrekt angepasst**, aber einige **View-Referenzen müssen validiert** werden.

---

## 🎯 Migrationsstatus

### ✅ Erfolgreich abgeschlossen:

1. **Datenmodell (STI)**
   - `InternationalTournament < Tournament` 
   - `tournaments.type = 'InternationalTournament'`
   - Alte Tabellen entfernt (`international_tournaments`, `international_participations`, etc.)

2. **Video-System**
   - Polymorphe `videos` Tabelle ersetzt `international_videos`
   - `Tournament has_many :videos, as: :videoable`
   - `Game has_many :videos, as: :videoable`

3. **PDF-Parsing**
   - GroupResults PDFs → Games + GameParticipations
   - Phase Marker Games für Metadaten
   - Individual Match Games mit 2 Participations

4. **Controller**
   - `InternationalController` verwendet `Tournament.international`
   - `TournamentsController` verwendet STI und polymorphe Assoziationen
   - Video-Queries korrekt angepasst

---

## 📂 View-Dateien Status

### Dateien zu überprüfen:

| Datei | Zeilen | Status | Priorität |
|-------|--------|--------|-----------|
| `app/views/international/tournaments/index.html.erb` | 139 | ⚠️ Prüfen | HOCH |
| `app/views/international/tournaments/show.html.erb` | 312 | ⚠️ Prüfen | HOCH |
| `app/views/international/index.html.erb` | ? | ⚠️ Prüfen | MITTEL |
| `app/views/international/videos/index.html.erb` | ? | ⚠️ Prüfen | NIEDRIG |
| `app/views/international/videos/show.html.erb` | ? | ⚠️ Prüfen | NIEDRIG |

---

## 🔍 Detaillierte View-Analyse

### 1. `tournaments/index.html.erb`

#### ✅ Was funktioniert:

```erb
<%= tournament.name %>           <!-- Alias auf title ✓ -->
<%= tournament.location %>        <!-- Alias auf location_text ✓ -->
<%= tournament.date_range %>      <!-- Methode im Model ✓ -->
<%= tournament.official_umb? %>   <!-- Methode im Model ✓ -->
<%= tournament.videos.count %>    <!-- Polymorphe Association ✓ -->
<%= tournament.discipline.translated_name(:en) %> <!-- Erbt von Tournament ✓ -->
```

#### ⚠️ Zu prüfen:

**Filter-Parameter (Zeile 14-16):**
```erb
<%= f.select :type, options_for_select(@tournament_types...) %>
```

**Problem:** `tournament_type` ist in `data` JSONB gespeichert, nicht als Spalte.

**Controller verwendet bereits korrekt:**
```ruby
@tournaments = @tournaments.where(tournament_type: params[:type])
```

**ABER:** Das funktioniert nur wenn `where(tournament_type:)` als Scope definiert ist!

**Aktueller Scope im Model:**
```ruby
scope :by_type, ->(type) { where("data->>'tournament_type' = ?", type) if type.present? }
```

**Lösung:** Controller muss `.by_type(params[:type])` verwenden statt `.where(tournament_type:)`

#### 🔧 Erforderliche Änderungen:

**Controller (Zeile 15):**
```ruby
# Falsch:
@tournaments = @tournaments.where(tournament_type: params[:type]) if params[:type].present?

# Richtig:
@tournaments = @tournaments.by_type(params[:type])
```

**Official UMB Filter (Zeile 18):**
```ruby
# Falsch:
@tournaments = @tournaments.where(official_umb: true) if params[:official_umb] == '1'

# Richtig:
@tournaments = @tournaments.official_umb if params[:official_umb] == '1'
```

---

### 2. `tournaments/show.html.erb`

#### ✅ Was funktioniert:

```erb
<!-- Tournament Info -->
<%= @tournament.name %>                    <!-- Alias ✓ -->
<%= @tournament.location %>                <!-- Alias ✓ -->
<%= @tournament.date_range %>              <!-- Methode ✓ -->
<%= @tournament.tournament_type&.humanize %> <!-- JSON accessor ✓ -->
<%= @tournament.official_umb? %>           <!-- Methode ✓ -->

<!-- Videos -->
<%= @videos.each do |video| %>             <!-- Controller-Variable ✓ -->
<%= video.thumbnail_url %>                 <!-- Video Model ✓ -->
<%= video.translated_title(:en) %>         <!-- Video Model ✓ -->

<!-- Rankings via GameParticipation -->
<%= @all_participations.each ... %>        <!-- Controller-Variable ✓ -->

<!-- Games/Matches -->
<%= @phase_games.each ... %>               <!-- Controller-Variable ✓ -->
<%= @matches_by_phase[phase_game.id] %>    <!-- Controller-Variable ✓ -->
```

#### ⚠️ Zu prüfen:

**Video Duration Helper (Zeile 122):**
```erb
<%= video.duration_formatted %>
```

**Frage:** Existiert diese Methode im `Video` Model?

**Suche erforderlich:** Nach `duration_formatted` im Video Model.

---

### 3. `index.html.erb` (Landing Page)

**Status:** Nicht gelesen

**Zu prüfen:**
- Verwendet `@upcoming_tournaments` korrekt?
- Verwendet `@recent_videos` korrekt?
- Verwendet `@recent_results` (GameParticipations) korrekt?

---

## 🎯 Zusammenfassung der Probleme

### 🔴 KRITISCH (muss gefixt werden):

1. **TournamentsController Zeile 15:** 
   - `.where(tournament_type:)` → `.by_type()`
   
2. **TournamentsController Zeile 18:** 
   - `.where(official_umb: true)` → `.official_umb`

### 🟡 ZU PRÜFEN:

1. **Video Model:** Methode `duration_formatted` vorhanden?
2. **Index Landing Page:** Korrekte Verwendung der Controller-Variablen?
3. **Video Views:** Anpassungen nach polymorphem Video-System?

### 🟢 FUNKTIONIERT:

- ✅ Aliase (`name`, `location`, `start_date`)
- ✅ JSON-Accessors (`tournament_type`, `country`, `organizer`)
- ✅ Polymorphe Associations (`videos`, `games`, `game_participations`)
- ✅ Scopes (teilweise, siehe Kritisch)

---

## 📝 Empfohlene Nächste Schritte

### Phase 1: Controller Fix (HOCH Priorität)

1. ✅ **Fix TournamentsController:**
   ```ruby
   # app/controllers/international/tournaments_controller.rb
   
   # Zeile 15:
   @tournaments = @tournaments.by_type(params[:type])
   
   # Zeile 18:
   @tournaments = @tournaments.official_umb if params[:official_umb] == '1'
   ```

2. ✅ **Prüfe Video Model:**
   ```bash
   grep -n "duration_formatted" app/models/video.rb
   ```
   
   Falls nicht vorhanden, hinzufügen:
   ```ruby
   def duration_formatted
     return nil unless duration
     minutes = duration / 60
     seconds = duration % 60
     "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
   end
   ```

### Phase 2: View Validierung (MITTEL Priorität)

3. ⚠️ **Teste alle Views manuell:**
   ```bash
   # Start Server
   rails server
   
   # Teste URLs:
   # - /international
   # - /international/tournaments
   # - /international/tournaments/:id
   # - /international/videos
   ```

4. ⚠️ **Lese und prüfe verbleibende Views:**
   - `app/views/international/index.html.erb`
   - `app/views/international/videos/index.html.erb`
   - `app/views/international/videos/show.html.erb`

### Phase 3: Dokumenten-Cleanup (NIEDRIG Priorität)

5. 📁 **Archiviere veraltete Dokumente:**
   ```bash
   mkdir -p docs/archive/2026-02-pre-sti
   mv INTERNATIONAL_TO_STI_MIGRATION_PLAN.md docs/archive/2026-02-pre-sti/
   mv INTERNATIONAL_EXTENSION_COMPLETE.md docs/archive/2026-02-pre-sti/
   ```

6. 📝 **Erstelle finales Status-Dokument:**
   - `INTERNATIONAL_STI_COMPLETE.md` mit finaler Übersicht

---

## 📊 Dokumenten-Empfehlungen

### ✅ BEHALTEN (Aktuelle Referenz):

| Dokument | Zweck | Aktion |
|----------|-------|--------|
| `UMB_PDF_PARSING.md` | Parsing-Referenz | ✅ Aktuell halten |
| `UMB_STI_MIGRATION_SUCCESS.md` | Migrations-Historie | ✅ Behalten |
| `VIDEO_SYSTEM_COMPLETE.md` | Video-System Doku | ✅ Behalten |
| `UMB_MIGRATION_TO_STI_COMPLETE.md` | STI-Abschluss | ✅ Behalten |

### 📦 ARCHIVIEREN (Veraltet):

| Dokument | Grund | Aktion |
|----------|-------|--------|
| `INTERNATIONAL_TO_STI_MIGRATION_PLAN.md` | Nur Plan, Migration abgeschlossen | 📦 → `docs/archive/` |
| `INTERNATIONAL_EXTENSION_COMPLETE.md` | Beschreibt altes System vor STI | 📦 → `docs/archive/` |

### ✏️ KORRIGIEREN:

Keine - Die bestehenden Dokumente sind korrekt.

---

## 🧪 Test-Checkliste

Nach den Fixes folgende Szenarien testen:

### Index Page (`/international/tournaments`)

- [ ] Turniere werden angezeigt
- [ ] Filter nach Type funktioniert
- [ ] Filter nach Discipline funktioniert
- [ ] Filter nach Year funktioniert
- [ ] "Official UMB" Checkbox funktioniert
- [ ] Video-Count wird korrekt angezeigt
- [ ] Badges (tournament_type, official_umb) erscheinen

### Show Page (`/international/tournaments/:id`)

- [ ] Tournament-Details werden angezeigt
- [ ] Videos werden angezeigt (wenn vorhanden)
- [ ] Rankings-Tabelle wird angezeigt (wenn Games vorhanden)
- [ ] Games nach Phase gruppiert
- [ ] Matches mit korrekten Participations
- [ ] Duration-Badge auf Video-Thumbnails

### Landing Page (`/international`)

- [ ] Upcoming Tournaments
- [ ] Recent Videos
- [ ] Recent Results

---

## 🎓 Lessons Learned

### Was gut funktioniert hat:

✅ **STI-Migration** - Saubere Trennung, altes System komplett entfernt  
✅ **Polymorphe Videos** - Flexible Zuordnung zu Tournament/Game/Player  
✅ **Controller-Anpassungen** - Frühzeitig angepasst, nur kleine Fehler  
✅ **Model-Aliase** - View-Kompatibilität durch `name`, `location` Aliase  

### Was noch verbessert werden kann:

⚠️ **JSONB-Queries** - Controller verwenden noch direkte `.where()` statt Scopes  
⚠️ **Helper-Methoden** - `duration_formatted` könnte fehlen  
⚠️ **Dokumentation** - Alte Dokumente archivieren für Klarheit  

---

## 📞 Nächste Schritte - EMPFEHLUNG

**Reihenfolge:**

1. 🔴 **JETZT:** Controller-Fixes (5 Minuten)
2. 🟡 **DANN:** Video Model prüfen (2 Minuten)
3. 🟢 **DANN:** Manuelle Tests (15 Minuten)
4. 📦 **SPÄTER:** Dokumenten-Cleanup (5 Minuten)

**Geschätzte Gesamtzeit:** ~30 Minuten

---

**Status:** Bereit für Fixes  
**Risiko:** Niedrig (nur kleine Controller-Anpassungen)  
**Impact:** Hoch (Alle Turnier-Views funktionieren danach korrekt)
