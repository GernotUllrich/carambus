# Tournament Game Protection - Turnierspiel-Schutz

## Übersicht

Dieses Dokument beschreibt die implementierten Schutzmaßnahmen, die verhindern, dass Turnierspiele während eines laufenden Turniers manipuliert werden können.

## Problem

Bisher war es möglich, dass:
1. Freie Spiele auf Tischen gestartet werden, die einem Turnier zugeordnet sind
2. TableMonitor-Aktionen direkt aufgerufen werden, die Turnierspiele manipulieren
3. Turniere von nicht-autorisierten Benutzern zurückgesetzt werden

## Lösung

### 1. ApplicationController - Zentrale Helper-Methode

**Datei**: `app/controllers/application_controller.rb`

Eine neue Helper-Methode `block_if_tournament_game!` wurde hinzugefügt:

```ruby
def block_if_tournament_game!(table_monitor)
  return unless table_monitor&.tournament_monitor_id.present?
  
  flash[:error] = I18n.t('errors.tournament_game_manipulation_blocked',
                        default: 'Spielmanipulationen sind während eines Turniers nicht erlaubt.')
  redirect_back(fallback_location: root_path) and return true
end
```

Diese Methode prüft ob ein TableMonitor einem Turnier zugeordnet ist (`tournament_monitor_id.present?`) und blockiert den Zugriff entsprechend.

### 2. TableMonitorsController - Action-Schutz

**Datei**: `app/controllers/table_monitors_controller.rb`

**Geschützte Actions**:
- `start_game` - Verhindert Start eines freien Spiels auf Turniertischen
- `update` - Verhindert direkte Updates
- `destroy` - Verhindert Löschen

**Implementierung**:
```ruby
before_action :block_tournament_manipulation,
              only: %i[start_game update destroy]

private

def block_tournament_manipulation
  if @table_monitor&.tournament_monitor_id.present?
    flash[:error] = I18n.t('errors.tournament_game_manipulation_blocked',
                          default: 'Spielmanipulationen sind während eines Turniers nicht erlaubt.')
    redirect_back(fallback_location: locations_path) and return
  end
end
```

### 3. LocationsController - Scoreboard-Schutz

**Datei**: `app/controllers/locations_controller.rb`

**Geschützte Bereiche**:
- `free_game` State - Quick Game Setup
- `free_game_detail` State - Detailed Game Setup
- `scoreboard_free_game_karambol_new` Action

**Implementierung** (Beispiel für `free_game`):
```ruby
when "free_game"
  # Blockiere wenn Turnierspiel läuft
  if @table.present?
    table_monitor = @table.table_monitor
    if table_monitor&.tournament_monitor_id.present?
      flash[:error] = I18n.t('errors.tournament_game_manipulation_blocked',
                            default: 'Spielmanipulationen sind während eines Turniers nicht erlaubt.')
      redirect_to location_path(@location, sb_state: "welcome") and return
    end
  end
  # ... rest of the code
```

### 4. Tournament Model - Reset-Schutz

**Datei**: `app/models/tournament.rb`

**Neue Guard-Methode**:
```ruby
def admin_can_reset_tournament?
  current_user = User.current || PaperTrail.request.whodunnit
  return true if current_user.blank? # Beim Initialisieren gibt es keinen User
  
  user = current_user.is_a?(User) ? current_user : User.find_by(id: current_user)
  user&.club_admin? || user&.system_admin?
end
```

**Geschützte State Machine Events**:
```ruby
event :reset_tmt_monitor do
  transitions to: :new_tournament, 
              guard: %i[tournament_not_yet_started admin_can_reset_tournament?]
end

event :forced_reset_tournament_monitor do
  transitions to: :new_tournament, 
              guard: :admin_can_reset_tournament?
end
```

**Wichtig**: 
- `reset_tmt_monitor` - Kann nur zurücksetzen wenn Turnier noch nicht gestartet UND User ist Admin
- `forced_reset_tournament_monitor` - Kann nur von Admins aufgerufen werden (erzwingt Reset auch bei gestarteten Turnieren)

### 5. Internationalisierung

**Dateien**: 
- `config/locales/de.yml`
- `config/locales/en.yml`

**Neue Übersetzungsschlüssel**:

**Deutsch**:
```yaml
errors:
  tournament_game_manipulation_blocked: "Spielmanipulationen sind während eines Turniers nicht erlaubt. Bitte verwenden Sie das Turnier-Verwaltungssystem."
  tournament_reset_requires_admin: "Das Zurücksetzen eines Turniers ist nur für Club- und System-Administratoren erlaubt."
```

**Englisch**:
```yaml
errors:
  tournament_game_manipulation_blocked: "Game manipulations are not allowed during a tournament. Please use the tournament management system."
  tournament_reset_requires_admin: "Resetting a tournament is only allowed for club and system administrators."
```

## Funktionsweise

### Erkennung von Turnierspielen

Ein Spiel wird als Turnierspiel erkannt wenn:
```ruby
table_monitor.tournament_monitor_id.present?
```

Dies bedeutet, dass der TableMonitor einem TournamentMonitor (oder PartyMonitor) zugeordnet ist.

### Blockierung von Manipulationen

1. **Bei direkten Controller-Aufrufen**: Der `before_action` Filter prüft die Zuordnung und blockiert den Request
2. **Bei Scoreboard-States**: Inline-Prüfungen am Anfang der jeweiligen State-Handler
3. **Bei Tournament-Resets**: AASM Guards prüfen die Berechtigungen in der State Machine

### Ausnahmen

**Erlaubt sind**:
- Alle Aktionen die vom TournamentMonitor/PartyMonitor selbst ausgehen
- Tournament-Resets durch `club_admin` oder `system_admin`
- Lesezugriffe (show, index)
- Anzeige-Funktionen (evaluate_result, next_step wenn von TournamentMonitor)

**Blockiert sind**:
- Direkte Manipulation via TableMonitorsController (start_game, update, destroy)
- Freie Spiele auf Turniertischen via LocationsController
- Tournament-Resets durch normale User oder Scoreboard-User

## Benutzerrollen

### System Admin (`system_admin?`)
- Kann Turniere zurücksetzen (auch gestartete)
- Kann alle TableMonitor-Funktionen nutzen

### Club Admin (`club_admin?`)
- Kann Turniere zurücksetzen (auch gestartete)
- Spielleiter-Funktionen im Turnier

### Normale User
- Können Turnierspiele NICHT manipulieren
- Können Turniere NICHT zurücksetzen
- Können nur freie Spiele auf nicht-Turnier-Tischen starten

### Scoreboard User
- Kann Turnierspiele NICHT manipulieren
- Kann Turniere NICHT zurücksetzen
- Wird automatisch bei Zugriff auf blockierte Aktionen umgeleitet

## Testing

### Manuelle Tests

1. **Test: Freies Spiel auf Turniertisch**
   ```
   1. Erstelle ein Turnier und weise einen Tisch zu
   2. Versuche ein freies Spiel auf diesem Tisch zu starten
   3. Erwartung: Fehlermeldung und Redirect zum Welcome Screen
   ```

2. **Test: TableMonitor direkt manipulieren**
   ```
   1. Öffne einen TableMonitor der einem Turnier zugeordnet ist
   2. Versuche start_game aufzurufen
   3. Erwartung: Fehlermeldung und Redirect
   ```

3. **Test: Tournament Reset als normaler User**
   ```
   1. Als normaler User anmelden
   2. Versuche reset_tmt_monitor! oder forced_reset_tournament_monitor! aufzurufen
   3. Erwartung: AASM::InvalidTransition Exception
   ```

4. **Test: Tournament Reset als Club Admin**
   ```
   1. Als club_admin anmelden
   2. Rufe reset_tmt_monitor! auf (vor Tournament-Start)
   3. Erwartung: Erfolgreiches Reset
   ```

### Automatische Tests

TODO: System-Tests für die Schutzmaßnahmen hinzufügen

## Sicherheitshinweise

1. **Guard-Methode in Tournament**: Die `admin_can_reset_tournament?` Methode erlaubt Zugriff wenn kein User vorhanden ist. Dies ist notwendig für die Initialisierung, sollte aber beobachtet werden.

2. **State Machine Guards**: Guards werden nur bei Event-Aufrufen geprüft, nicht bei direkten State-Änderungen. Immer Events verwenden!

3. **PaperTrail Integration**: Die Guard-Methode nutzt `User.current` und `PaperTrail.request.whodunnit` um den aktuellen User zu ermitteln.

## Wartung

Bei Änderungen an:
- TableMonitor-Actions: Prüfen ob Schutz nötig ist
- Tournament State Machine: Guards berücksichtigen
- Scoreboard States: Inline-Checks hinzufügen

## User Experience

### Flash-Messages auf Scoreboard

Wenn eine blockierte Aktion versucht wird, sieht der Benutzer:

1. **Redirect zur Welcome-Seite** (oder andere sichere Seite)
2. **Rote Error-Box** oben zentriert mit der Fehlermeldung
3. **Klare Anweisung** was nicht erlaubt ist

Die Flash-Messages sind:
- Prominent platziert (oben zentriert)
- Farblich kodiert (rot für Fehler)
- Automatisch verschwindend bei nächster Navigation
- In der gewählten Sprache (DE/EN)

Details siehe: [FLASH_MESSAGES_SCOREBOARD.md](FLASH_MESSAGES_SCOREBOARD.md)

## Changelog

### 2025-12-01
- Initiale Implementierung des Tournament Game Protection Systems
- Schutz für TableMonitorsController, LocationsController
- Admin-only Tournament Resets
- Internationalisierung (DE/EN)
- Flash-Messages Integration für Scoreboard-Views
- Support für `flash[:error]` in Flash-Partial hinzugefügt

