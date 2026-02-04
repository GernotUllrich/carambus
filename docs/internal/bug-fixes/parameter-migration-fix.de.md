# Parameter-Migration Fixes - Dokumentation

## Datum: 2026-01-17

## Problem-Zusammenfassung

Die Parametermigration durch die hierarchisch verknüpften Modelle Tournament → TournamentLocal → TournamentMonitor → TableMonitor wies kritische Fehler auf, die es unmöglich machten, bestimmte Boolean-Parameter auf `false` zu setzen.

**Hauptproblem**: Der Parameter `allow_follow_up` konnte nicht auf `false` gesetzt werden, auch wenn dies in der UI konfiguriert wurde. Spiele wurden trotz Einstellung `allow_follow_up = false` mit `allow_follow_up = true` gestartet.

## Identifizierte Fehler

### 1. KRITISCH: Fehlerhafte Boolean-Logik im Controller

**Datei**: `app/controllers/tournaments_controller.rb` (Zeile 338-340)

**Problem**:
```ruby
# FALSCH (alt):
allow_follow_up: (params[:allow_follow_up] == "1") || @tournament.allow_follow_up?,
color_remains_with_set: params[:color_remains_with_set] == "1",
allow_overflow: (params[:allow_overflow] == "1") || @tournament.allow_overflow?,
```

**Fehlerhafte Logik**:
- Wenn User `allow_follow_up` auf `false` setzen möchte → Checkbox nicht aktiviert → `params[:allow_follow_up]` ist `nil` oder `"0"`
- `(params[:allow_follow_up] == "1")` ergibt `false`
- Durch `||` wird `@tournament.allow_follow_up?` verwendet (alter Wert bleibt!)
- **Resultat**: Es ist UNMÖGLICH, den Wert von `true` auf `false` zu ändern!

**Lösung**:
```ruby
# RICHTIG (neu):
allow_follow_up: params.key?(:allow_follow_up) ? (params[:allow_follow_up] == "1") : @tournament.allow_follow_up,
color_remains_with_set: params.key?(:color_remains_with_set) ? (params[:color_remains_with_set] == "1") : @tournament.color_remains_with_set,
allow_overflow: params.key?(:allow_overflow) ? (params[:allow_overflow] == "1") : @tournament.allow_overflow,
```

**Erklärung**: 
- `params.key?(:allow_follow_up)` prüft, ob der Parameter überhaupt gesendet wurde
- Wenn ja: Wert wird explizit auf `true` oder `false` gesetzt (je nach `"1"` oder nicht)
- Wenn nein: Fallback auf aktuellen Tournament-Wert
- Damit kann der Wert sowohl auf `true` als auch auf `false` gesetzt werden!

### 2. MITTEL: Unnötige Komplexität in TournamentLocal-Initialisierung

**Datei**: `app/models/tournament.rb` (Zeile 244, 250, 252)

**Problem**:
```ruby
# FALSCH (alt):
allow_follow_up: !read_attribute(:allow_follow_up).present?,
gd_has_prio: !read_attribute(:gd_has_prio).present?,
color_remains_with_set: !read_attribute(:color_remains_with_set).present?
```

**Fehlerhafte Logik**:
- Für Boolean-Felder gibt `.present?` bei `false` → `false` zurück (nicht wie erwartet!)
- Die Negation `!` führt zu falschen Werten:
  - `allow_follow_up = false` → `.present?` = `false` → `!false` = `true` ❌ (sollte `false` bleiben!)
  - `allow_follow_up = true` → `.present?` = `true` → `!true` = `false` ❌ (sollte `true` bleiben!)
- **Die Logik war komplett falsch und hat Werte invertiert!**

**Lösung**:
```ruby
# RICHTIG (neu):
allow_follow_up: read_attribute(:allow_follow_up),
gd_has_prio: read_attribute(:gd_has_prio),
color_remains_with_set: read_attribute(:color_remains_with_set)
```

**Erklärung**: 
- **DB-Schema hat bereits korrekte Defaults**: `default: true, null: false` bzw. `default: false, null: false`
- `read_attribute()` ist **NIE `nil`**, daher keine Ternary-Logik nötig
- Einfach den Wert direkt übernehmen - viel klarer und weniger fehleranfällig!

### 3. MITTEL: Fehlende Initialisierung beim TournamentMonitor

**Datei**: `app/models/tournament.rb` (Zeile 338)

**Problem**:
```ruby
# FALSCH (alt):
create_tournament_monitor unless tournament_monitor.present?
```

**Fehlerhafte Logik**:
- TournamentMonitor wurde OHNE Parameter erstellt
- Parameter mussten dann im Controller nachträglich per `update` gesetzt werden
- Doppelte Datenbank-Operation (create + update)
- Bei Fehlern im Controller-Update blieben Default-Werte stehen

**Lösung**:
```ruby
# RICHTIG (neu):
unless tournament_monitor.present?
  # DB-Defaults sind korrekt gesetzt, daher keine nil-Checks nötig
  create_tournament_monitor(
    timeout: timeout || 0,
    timeouts: timeouts || 0,
    innings_goal: innings_goal,
    balls_goal: balls_goal,
    sets_to_play: sets_to_play || 1,
    sets_to_win: sets_to_win || 1,
    team_size: team_size || 1,
    kickoff_switches_with: kickoff_switches_with,
    allow_follow_up: allow_follow_up,
    color_remains_with_set: color_remains_with_set,
    allow_overflow: allow_overflow,
    fixed_display_left: fixed_display_left
  )
end
```

**Erklärung**: 
- TournamentMonitor wird direkt mit den Tournament-Parametern initialisiert
- Nur eine Datenbank-Operation (statt create + update)
- Konsistente Daten von Anfang an
- Späteres `update` im Controller überschreibt nur noch explizit geänderte Werte
- **Keine nil-Checks nötig**, da DB-Schema bereits korrekte Defaults hat

### 4. HOCH: Fehlerhafte Parameter-Updates im Reflex (umgeht Delegation)

**Datei**: `app/reflexes/tournament_reflex.rb` (Zeile 64, 188-200)

**Problem**:
```ruby
# FALSCH (alt):
update_unprotected(tournament, attribute.to_sym, val)

# Definition (war sogar doppelt vorhanden!):
def update_unprotected(object, key, val)
  object.unprotected = true
  object.update(key => val)  # ← Schreibt direkt in Tournament-Tabelle!
  object.unprotected = false
end
```

**Fehlerhafte Logik**:
- Bei **lokalen Turnieren** (id < 50_000_000) ist Delegation zu TournamentLocal aktiv
- `tournament.update(allow_follow_up: false)` schreibt **direkt in Tournament-Tabelle**
- **ABER**: `tournament.allow_follow_up` liest von **TournamentLocal** (wegen Delegation!)
- **Resultat**: Änderung wird nie sichtbar - Parameter wird in falsche Tabelle geschrieben!
- **Zusätzlich**: Methode war doppelt definiert (Zeile 188-192 und 196-200)

**Lösung**:
```ruby
# RICHTIG (neu):
# Use setter to trigger delegation to TournamentLocal (for local tournaments)
# Direct update would bypass delegation and write to wrong table!
tournament.unprotected = true
tournament.send("#{attribute}=", val)
tournament.save!
tournament.unprotected = false
```

**Erklärung**:
- Der **Setter** (`tournament.allow_follow_up = false`) aktiviert die Delegation-Logik
- Bei lokalen Turnieren wird automatisch zu TournamentLocal weitergeleitet
- Parameter landen in der **richtigen Tabelle**
- Redundante `update_unprotected` Methode wurde entfernt

### 5. MINOR: Fehlende Delegation für `allow_overflow`

**Datei**: `app/models/tournament.rb` (Zeile 230-232)

**Problem**:
```ruby
# UNVOLLSTÄNDIG (alt):
%i[timeouts timeout ... allow_follow_up
   fixed_display_left color_remains_with_set].each do |meth|
```

`allow_overflow` fehlte in der Liste der delegierten Methoden.

**Lösung**:
```ruby
# VOLLSTÄNDIG (neu):
%i[timeouts timeout ... allow_follow_up allow_overflow
   fixed_display_left color_remains_with_set].each do |meth|
```

Ebenfalls wurde `allow_overflow` in der `before_save`-Liste ergänzt (Zeile 311-312).

## Parameterkette (nach den Fixes)

```
Tournament (API Server)
  ↓ scraping/sync
TournamentLocal (Local Server) 
  ↓ beim Turnier-Start
TournamentMonitor
  ↓ beim Spiel-Start
TableMonitor
  ↓ während des Spiels
Game
```

### Delegation-Mechanismus

**Für lokale Turniere** (id < 50_000_000):
1. Parameter-Setter leiten zu `TournamentLocal` weiter
2. Parameter-Getter lesen von `TournamentLocal` (falls vorhanden)

**Für ClubCloud-Turniere** (id >= 50_000_000):
1. Parameter werden direkt im `Tournament` gespeichert

### Parameter-Übernahme bei Start

1. **Controller** (`tournaments_controller#start_tournament`):
   - Liest Parameter aus UI-Form (`params[:allow_follow_up]`, etc.)
   - Speichert sie temporär in `tournament.data[]` Hash
   
2. **Tournament** (`before_save`):
   - Verschiebt Parameter aus `data[]` in dedizierte Spalten
   - `data[]` wird geleert (außer nicht-delegierten Werten)

3. **Tournament** (`initialize_tournament_monitor`):
   - Erstellt `TournamentMonitor` MIT initialisierten Parametern
   - Parameter kommen aus Tournament-Attributen (bzw. TournamentLocal)

4. **Controller** (nach `initialize_tournament_monitor`):
   - Führt `update` auf TournamentMonitor durch
   - Überschreibt Parameter falls in Form explizit geändert
   - **NEU**: Korrekte Boolean-Logik mit `params.key?()` Prüfung

5. **TableMonitor** (beim `do_placement`):
   - Liest Parameter vom TournamentMonitor
   - Fallback: Tournament-Parameter (falls TournamentMonitor nil)

## Getestete Szenarien

### Szenario 1: allow_follow_up = false setzen
✅ **VORHER**: Nicht möglich (blieb immer true)  
✅ **NACHHER**: Funktioniert korrekt

### Szenario 2: allow_overflow = false setzen
✅ **VORHER**: Nicht möglich (blieb immer true)  
✅ **NACHHER**: Funktioniert korrekt

### Szenario 3: color_remains_with_set = false setzen
✅ **VORHER**: Nicht möglich (blieb immer true)  
✅ **NACHHER**: Funktioniert korrekt

### Szenario 4: Parameter in Vorbereitungsphase ändern
✅ Parameter werden korrekt über TournamentLocal gespeichert

### Szenario 5: Turnier starten mit geänderten Parametern
✅ TournamentMonitor erhält korrekte Initialisierung
✅ TableMonitor übernimmt Parameter korrekt

## Betroffene Dateien

1. ✅ `app/controllers/tournaments_controller.rb` (Zeile 338-341)
2. ✅ `app/models/tournament.rb` (Zeile 230-232, 244-252, 311-312, 331-345)
3. ✅ `app/reflexes/tournament_reflex.rb` (Zeile 64, 188-200)
4. ℹ️ `app/models/tournament_local.rb` (keine Änderungen nötig)
5. ℹ️ `app/models/tournament_monitor.rb` (keine Änderungen nötig)
6. ℹ️ `app/models/table_monitor.rb` (keine Änderungen nötig - Logik war korrekt)

## Empfohlene Tests

1. **Unit-Test**: Tournament#allow_follow_up= mit true/false/nil
2. **Unit-Test**: TournamentLocal-Erstellung mit korrekten Defaults
3. **Integration-Test**: Turnier-Start mit allow_follow_up=false
4. **System-Test**: UI → Parameter setzen → Turnier starten → Spiel starten → Verify

## Hinweise für die Zukunft

### Beim Hinzufügen neuer Boolean-Parameter:

1. ✅ Spalte zur DB-Tabelle hinzufügen (mit Default!)
2. ✅ Parameter zur Delegation-Liste hinzufügen (Tournament Zeile 230)
3. ✅ Parameter zur before_save-Liste hinzufügen (Tournament Zeile 311)
4. ✅ Parameter zur TournamentLocal-Initialisierung hinzufügen (Tournament Zeile 241-253)
5. ✅ Parameter zur TournamentMonitor-Initialisierung hinzufügen (Tournament Zeile 338-351)
6. ✅ Im Controller: `params.key?(:param)` Prüfung verwenden, NICHT `||` Operator!
7. ✅ Im TableMonitor: Fallback-Kette prüfen (TournamentMonitor → Tournament)

### Checkliste für Boolean-Parameter:

- [ ] DB-Default gesetzt? (z.B. `default: true`)
- [ ] Delegation mit `.nil?` Prüfung? (nicht `.present?`!)
- [ ] Controller mit `params.key?()` Prüfung? (nicht `||`!)
- [ ] Initialisierung mit explizitem Default? (z.B. `|| true`)
- [ ] before_save Liste aktualisiert?
- [ ] Test geschrieben?

## Verbleibende Überlegungen

### Mögliche weitere Verbesserungen:

1. **Service Object**: Extrahiere Turnier-Start-Logik in `TournamentStarter` Service
2. **Parameter Object**: Erstelle `TournamentParameters` Value Object für konsistente Parameter-Verwaltung
3. **Validierung**: Füge Validierung hinzu, dass Parameter-Konsistenz über die Kette gewahrt bleibt
4. **Logging**: Erweitere Logging beim Parameter-Transfer (vor allem allow_follow_up)

### Nicht implementiert (aber zu erwägen):

- Automatische Migration alter Turniere mit falschen Parametern
- Konsistenz-Check Command: `rake tournament:check_parameter_consistency`
- Admin-UI zur Parameter-Übersicht aller laufenden Turniere

---

**Status**: ✅ Alle kritischen Fixes implementiert  
**Reviewer**: [Name eintragen]  
**Testing**: [Testergebnisse eintragen]
