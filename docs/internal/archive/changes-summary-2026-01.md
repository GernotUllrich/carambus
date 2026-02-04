# Zusammenfassung der Änderungen - Parameter-Migration Fix

**Datum**: 17. Januar 2026  
**Entwickler**: AI Assistant  
**Reviewer**: [Bitte eintragen]

## Problem

Die Parameter `allow_follow_up`, `allow_overflow` und `color_remains_with_set` konnten in der UI nicht auf `false` gesetzt werden. Spiele wurden immer mit den Default-Werten (`true`) gestartet, unabhängig von der Konfiguration.

## Root Cause

Fehlerhafte Boolean-Logik im Controller: Die Verwendung des `||` Operators anstelle einer expliziten Prüfung auf Parameter-Existenz machte es unmöglich, Boolean-Parameter von `true` auf `false` zu ändern.

## Geänderte Dateien

### 1. `app/reflexes/tournament_reflex.rb`

**Zeilen 64, 188-200**: Kritischer Fix - Delegation statt direktes Update

```ruby
# VORHER (FALSCH - umgeht Delegation):
update_unprotected(tournament, attribute.to_sym, val)

def update_unprotected(object, key, val)
  object.unprotected = true
  object.update(key => val)  # ← Schreibt in falsche Tabelle!
  object.unprotected = false
end

# NACHHER (KORREKT - nutzt Delegation):
tournament.unprotected = true
tournament.send("#{attribute}=", val)  # ← Aktiviert Delegation zu TournamentLocal!
tournament.save!
tournament.unprotected = false
```

**Problem**: 
- Bei lokalen Turnieren wird `tournament.update(allow_follow_up: false)` direkt in die Tournament-Tabelle geschrieben
- Der Getter `tournament.allow_follow_up` liest aber von TournamentLocal (wegen Delegation)
- **Resultat**: Parameter landet in falscher Tabelle, Änderung wird nie sichtbar!

**Lösung**: 
- Setter `tournament.send("#{attribute}=", val)` nutzen
- Aktiviert automatisch die Delegation-Logik
- Parameter landet in korrekter Tabelle (TournamentLocal bei lokalen Turnieren)

**Zusätzlich**: Doppelte Definition von `update_unprotected` entfernt (war 2x vorhanden)

### 2. `app/controllers/tournaments_controller.rb`

**Zeilen 338-341**: Kritischer Fix der Boolean-Parameter-Logik

```ruby
# VORHER (FALSCH):
allow_follow_up: (params[:allow_follow_up] == "1") || @tournament.allow_follow_up?,

# NACHHER (KORREKT):
allow_follow_up: params.key?(:allow_follow_up) ? (params[:allow_follow_up] == "1") : @tournament.allow_follow_up,
```

**Problem**: `||` Operator machte es unmöglich, Boolean-Werte auf `false` zu setzen

**Betroffene Parameter**:
- `allow_follow_up`
- `allow_overflow`
- `color_remains_with_set`

### 3. `app/models/tournament.rb`

#### Fix 2a: Delegation (Zeile 230-232)

**Hinzugefügt**: `allow_overflow` zur Liste der delegierten Parameter

```ruby
# VORHER:
%i[... allow_follow_up
   fixed_display_left color_remains_with_set].each do |meth|

# NACHHER:
%i[... allow_follow_up allow_overflow
   fixed_display_left color_remains_with_set].each do |meth|
```

#### Fix 2b: TournamentLocal-Initialisierung (Zeile 244-252)

**Korrigiert**: Boolean-Default-Logik für bessere Lesbarkeit

```ruby
# VORHER (VERWIRREND):
allow_follow_up: !read_attribute(:allow_follow_up).present?,

# NACHHER (KLAR):
allow_follow_up: read_attribute(:allow_follow_up).nil? ? true : read_attribute(:allow_follow_up),
```

#### Fix 2c: before_save Callback (Zeile 311-312)

**Hinzugefügt**: `allow_overflow` zur Liste der aus `data[]` zu extrahierenden Parameter

```ruby
# NACHHER:
%w[... allow_follow_up allow_overflow
   fixed_display_left color_remains_with_set].each do |meth|
```

#### Fix 2d: TournamentMonitor-Initialisierung (Zeile 331-357)

**Neu**: Explizite Parameter-Übergabe beim Erstellen des TournamentMonitors

```ruby
# VORHER (UNVOLLSTÄNDIG):
create_tournament_monitor unless tournament_monitor.present?

# NACHHER (VOLLSTÄNDIG):
unless tournament_monitor.present?
  create_tournament_monitor(
    timeout: timeout || 0,
    timeouts: timeouts || 0,
    innings_goal: innings_goal,
    balls_goal: balls_goal,
    sets_to_play: sets_to_play || 1,
    sets_to_win: sets_to_win || 1,
    team_size: team_size || 1,
    kickoff_switches_with: kickoff_switches_with,
    allow_follow_up: allow_follow_up.nil? ? true : allow_follow_up,
    color_remains_with_set: color_remains_with_set.nil? ? true : color_remains_with_set,
    allow_overflow: allow_overflow || false,
    fixed_display_left: fixed_display_left
  )
end
```

**Vorteil**: 
- Nur eine Datenbank-Operation (vorher: create + update)
- Konsistente Parameter von Anfang an
- Kein Risiko von fehlenden Defaults

## Neue Dateien

### `PARAMETER_MIGRATION_FIXES.md`

Umfassende Dokumentation mit:
- Detaillierte Fehleranalyse
- Erklärung der Parameterkette
- Test-Szenarien
- Best Practices für zukünftige Boolean-Parameter

## Testing-Checklist

### Manuelle Tests (vor Deployment)

- [ ] Turnier erstellen mit `allow_follow_up = false`
- [ ] Turnier starten und Spiel zuweisen
- [ ] Verifizieren: TableMonitor hat `allow_follow_up = false`
- [ ] Spiel spielen bis Ende: Nachzug sollte NICHT möglich sein
- [ ] Gleiches für `allow_overflow = false`
- [ ] Gleiches für `color_remains_with_set = false`

### Automatisierte Tests (empfohlen)

```ruby
# spec/models/tournament_spec.rb
describe "Parameter Migration" do
  it "allows setting allow_follow_up to false" do
    tournament = create(:tournament, allow_follow_up: true)
    tournament.update(allow_follow_up: false)
    expect(tournament.allow_follow_up).to be false
  end
  
  it "initializes TournamentMonitor with correct parameters" do
    tournament = create(:tournament, allow_follow_up: false)
    tournament.initialize_tournament_monitor
    expect(tournament.tournament_monitor.allow_follow_up).to be false
  end
end

# spec/controllers/tournaments_controller_spec.rb
describe "POST #start_tournament" do
  it "sets allow_follow_up to false when unchecked" do
    post :start_tournament, params: { 
      id: tournament.id,
      # allow_follow_up NICHT in params (= Checkbox nicht aktiviert)
    }
    expect(tournament.reload.tournament_monitor.allow_follow_up).to be false
  end
end
```

## Risiko-Bewertung

| Risiko | Wahrscheinlichkeit | Impact | Mitigation |
|--------|-------------------|--------|------------|
| Regression bei existierenden Turnieren | Niedrig | Mittel | Manuelle Tests vor Deployment |
| Inkonsistente Parameter bei laufenden Turnieren | Niedrig | Niedrig | Turniere neu starten (falls nötig) |
| Fehler in TournamentLocal-Delegation | Sehr niedrig | Hoch | Code Review + Tests |
| Reflex-Änderungen brechen Live-Updates | Sehr niedrig | Mittel | Test mit StimulusReflex im Browser |

## Deployment-Hinweise

1. **Vor Deployment**:
   - Alle manuellen Tests durchführen
   - Code Review durch zweiten Entwickler
   - Backup der Datenbank erstellen

2. **Nach Deployment**:
   - Laufende Turniere beobachten
   - Bei Problemen: Sofortiges Rollback möglich (keine DB-Änderungen)
   - Parameter-Konsistenz bei nächstem Turnier-Start prüfen

3. **Migration** (optional):
   - Falls alte Turniere korrigiert werden sollen:
   ```ruby
   Tournament.where(allow_follow_up: true)
             .where("id < ?", Tournament::MIN_ID)
             .find_each do |t|
     t.tournament_monitor&.update(allow_follow_up: true) if t.tournament_monitor
   end
   ```

## Backward Compatibility

✅ **Vollständig backward-kompatibel**:
- Keine Datenbank-Schema-Änderungen
- Keine API-Änderungen
- Existierende Turniere funktionieren weiterhin
- Default-Werte bleiben gleich (`allow_follow_up: true`, etc.)

## Nächste Schritte

1. [ ] Code Review durch Team-Mitglied
2. [ ] Manuelle Tests durchführen
3. [ ] Deployment auf Staging-Server
4. [ ] Tests auf Staging wiederholen
5. [ ] Deployment auf Production
6. [ ] Monitoring für 24h nach Deployment

## Fragen?

Bei Fragen oder Problemen:
- Siehe `PARAMETER_MIGRATION_FIXES.md` für Details
- Kontakt: [Entwickler eintragen]

---

**Status**: ✅ Bereit für Review  
**Priorität**: 🔴 Hoch (Bug-Fix)  
**Geschätzter Aufwand**: 2h Testing + Deployment
