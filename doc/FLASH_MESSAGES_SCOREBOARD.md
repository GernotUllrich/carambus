# Flash Messages im Scoreboard

## Übersicht

Flash-Messages werden nun auch auf Scoreboard-Seiten angezeigt, insbesondere wenn Benutzer versuchen, blockierte Aktionen auszuführen (z.B. Turnierspiel-Manipulationen).

## Implementierte Änderungen

### 1. Flash-Partial erweitert (`app/views/application/_flash.html.erb`)

Unterstützung für `flash[:error]` hinzugefügt (zusätzlich zu `notice` und `alert`):

```erb
<% if flash[:error] %>
  <div class="notice notice-error dark:bg-red-700 dark:text-red-300" role="alert">
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-red-700 dark:text-red-400" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
    </svg>
    <p><%= sanitize flash[:error] %></p>
  </div>
<% end %>
```

### 2. Scoreboard Views aktualisiert

Flash-Messages in folgenden Views integriert:

#### scoreboard_welcome.html.erb
```erb
<div class="fixed top-20 left-1/2 transform -translate-x-1/2 z-50 w-11/12 max-w-4xl">
  <%= render "application/flash" %>
</div>
```

#### scoreboard_start.html.erb
```erb
<div class="fixed top-20 left-1/2 transform -translate-x-1/2 z-50 w-11/12 max-w-4xl">
  <%= render "application/flash" %>
</div>
```

### 3. CSS-Klassen

Die CSS-Klassen für Flash-Messages sind bereits in `app/assets/stylesheets/components/alert.css` definiert:

- `.notice-info` - Blaue Info-Box
- `.notice-success` - Grüne Success-Box
- `.notice-error` - Rote Error-Box
- `.notice-warning` - Gelbe Warning-Box

## Verwendung

### Im Controller

```ruby
# Info-Nachricht
flash[:notice] = "Erfolgreich gespeichert"

# Warnung
flash[:alert] = "Achtung: Etwas ist passiert"

# Fehler
flash[:error] = "Fehler: Diese Aktion ist nicht erlaubt"
```

### Bei Redirects

```ruby
redirect_to location_path(@location, sb_state: "welcome"), 
            notice: "Erfolg!"

redirect_to location_path(@location, sb_state: "welcome"), 
            alert: "Warnung!"

# Für Fehler müssen wir flash[:error] vorher setzen:
flash[:error] = "Fehler!"
redirect_to location_path(@location, sb_state: "welcome")
```

## Positionierung

Die Flash-Messages sind:
- **Fixed positioniert** am oberen Bildschirmrand
- **Zentriert** (`left-1/2 transform -translate-x-1/2`)
- **Mit hohem z-index** (`z-50`) damit sie über anderen Elementen erscheinen
- **Responsive** (`w-11/12 max-w-4xl`)
- **Top-offset** von 20 (`top-20`) um nicht mit dem oberen Menü zu kollidieren

## Turnierspiel-Schutz Integration

Bei blockierten Turnierspiel-Manipulationen wird automatisch eine Fehlermeldung angezeigt:

```ruby
flash[:error] = I18n.t('errors.tournament_game_manipulation_blocked',
                      default: 'Spielmanipulationen sind während eines Turniers nicht erlaubt.')
redirect_to location_path(@location, sb_state: "welcome")
```

**Deutsch**: "Spielmanipulationen sind während eines Turniers nicht erlaubt. Bitte verwenden Sie das Turnier-Verwaltungssystem."

**Englisch**: "Game manipulations are not allowed during a tournament. Please use the tournament management system."

## Auto-Dismiss

Flash-Messages haben das Attribut `data-turbo-temporary`, was bedeutet dass sie:
- Nach einem Turbo-Navigation automatisch verschwinden
- Bei einem Page-Reload nicht mehr angezeigt werden
- Nur einmal pro Request angezeigt werden

## Testing

### Manueller Test

1. Navigiere zu einer Location mit aktivem Turnier
2. Versuche ein freies Spiel auf einem Turniertisch zu starten
3. Erwartung: Redirect zur Welcome-Seite mit roter Error-Box

### Browser-Entwicklertools

```javascript
// Flash-Message im Browser testen
document.querySelector('#flash').innerHTML = `
  <div class="notice notice-error">
    <p>Test Fehlermeldung</p>
  </div>
`;
```

## Weitere Views

Falls weitere Scoreboard-Views Flash-Messages benötigen, einfach das Partial hinzufügen:

```erb
<div class="fixed top-20 left-1/2 transform -translate-x-1/2 z-50 w-11/12 max-w-4xl">
  <%= render "application/flash" %>
</div>
```

**Wichtig**: Position und z-index anpassen je nach Layout der jeweiligen View!

## Changelog

### 2025-12-01
- `flash[:error]` Support hinzugefügt
- Flash-Messages in `scoreboard_welcome.html.erb` integriert
- Flash-Messages in `scoreboard_start.html.erb` integriert
- Dokumentation erstellt


