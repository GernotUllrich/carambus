# Tournament Wizard Scroll Position Feature

## Übersicht

Diese Funktion speichert automatisch die Scroll-Position auf der Tournament Show Seite (Wizard) und stellt sie wieder her, wenn der Benutzer von einer Unterseite zurückkehrt.

## Problem

Wenn ein Benutzer im Tournament Wizard weit nach unten scrollt und dann einen Link zu einer Unterseite klickt (z.B. "Teilnehmer prüfen" in Schritt 3), verlor er beim Zurückkehren seine Scroll-Position. Der Browser scrollte immer wieder zum Anfang der Seite zurück.

## Lösung

Die Implementierung nutzt `sessionStorage` und Stimulus Controller Lifecycle-Methoden, um die Scroll-Position zu speichern und wiederherzustellen.

### Implementierte Funktionalität

1. **Automatisches Speichern**: Scroll-Position wird automatisch gespeichert, wenn:
   - Der Benutzer auf einen Link innerhalb der Tournament-Seite klickt
   - Turbo einen Seitenwechsel durchführt (`turbo:before-visit`)

2. **Automatisches Wiederherstellen**: Scroll-Position wird automatisch wiederhergestellt, wenn:
   - Der Benutzer zur Tournament Show Seite zurückkehrt
   - Die gespeicherte Position für das aktuelle Turnier existiert

3. **Turnier-spezifisch**: Jedes Turnier hat seine eigene gespeicherte Position basierend auf der `tournament_id`

4. **Session-basiert**: Die Positionen werden in `sessionStorage` gespeichert und automatisch nach der Wiederherstellung gelöscht

## Technische Details

### Geänderte Dateien

**`app/javascript/controllers/tournament_controller.js`**
- Neuer `connect()` Lifecycle: Initialisiert Scroll-Speicherung und -Wiederherstellung
- Neue Methode `restoreScrollPosition()`: Stellt gespeicherte Position wieder her
- Neue Methode `setupScrollSaving()`: Richtet Event-Listener ein
- Neuer `disconnect()` Lifecycle: Räumt Event-Listener auf

### Funktionsweise

```javascript
// Storage-Key-Format: tournament_{id}_scroll
const scrollKey = `tournament_${tournamentId}_scroll`

// Speichern beim Verlassen
sessionStorage.setItem(scrollKey, window.scrollY.toString())

// Wiederherstellen beim Zurückkehren
const savedScroll = sessionStorage.getItem(scrollKey)
if (savedScroll) {
  window.scrollTo({ top: parseInt(savedScroll, 10), behavior: 'instant' })
  sessionStorage.removeItem(scrollKey) // Aufräumen
}
```

### Timing-Optimierung

Die Wiederherstellung verwendet doppelte `requestAnimationFrame`, um sicherzustellen, dass das DOM vollständig gerendert ist:

```javascript
requestAnimationFrame(() => {
  requestAnimationFrame(() => {
    window.scrollTo({ top: scrollY, behavior: 'instant' })
  })
})
```

## Unterstützte Navigation-Pfade

Die Funktion funktioniert für alle Wizard-Unterseiten:

1. **Tournament Show → Define Participants** (Schritt 3)
   - Link: "Teilnehmer prüfen"
   - Zurück: "← Zurück zum Wizard"

2. **Tournament Show → Compare Seedings** (Schritt 2)
   - Link: "Einladung hochladen" / "Setzliste prüfen"
   - Zurück: "← Zurück"

3. **Tournament Show → Finalize Modus** (Schritt 5)
   - Link: "Modus auswählen"
   - Zurück: implizit durch Browser-Navigation

4. **Compare Seedings → Parse Invitation**
   - Unterseite von Schritt 2
   - Zurück: "← Zurück" (zu compare_seedings)

## Testen

### Manuelle Tests

1. **Test 1: Grundfunktion**
   ```
   1. Öffne eine Tournament Show Seite mit Wizard
   2. Scrolle weit nach unten (z.B. zu Schritt 5 oder 6)
   3. Klicke auf "Teilnehmer prüfen" (Schritt 3)
   4. Klicke auf "← Zurück zum Wizard"
   5. ✓ Erwartung: Die Seite scrollt automatisch zur vorherigen Position
   ```

2. **Test 2: Mehrfache Navigation**
   ```
   1. Scrolle zu Position A
   2. Gehe zu "Teilnehmer prüfen"
   3. Kehre zurück (→ Position A)
   4. Scrolle zu Position B
   5. Gehe zu "Modus auswählen"
   6. Kehre zurück (→ Position B)
   7. ✓ Erwartung: Jede Rückkehr führt zur richtigen Position
   ```

3. **Test 3: Verschiedene Turniere**
   ```
   1. Öffne Turnier 1, scrolle zu Position A
   2. Navigiere weg und zurück
   3. Öffne Turnier 2, scrolle zu Position B
   4. Navigiere weg und zurück
   5. ✓ Erwartung: Jedes Turnier merkt sich seine eigene Position
   ```

4. **Test 4: Browser-Zurück-Button**
   ```
   1. Scrolle zu einer Position
   2. Gehe zu einer Unterseite
   3. Verwende Browser-Zurück-Button
   4. ✓ Erwartung: Position wird wiederhergestellt
   ```

### Browser-Console-Logging

Die Funktion gibt Debug-Logs aus:

```javascript
// Beim Speichern
console.log(`Saving scroll position for tournament ${tournamentId}: ${scrollY}px`)

// Beim Wiederherstellen
console.log(`Restoring scroll position for tournament ${tournamentId}: ${scrollY}px`)
```

### Überprüfung in Browser DevTools

Im Browser DevTools → Application → Session Storage:

```
Key: tournament_123_scroll
Value: 2450
```

## Browser-Kompatibilität

- ✅ Chrome/Edge: Vollständig unterstützt
- ✅ Firefox: Vollständig unterstützt
- ✅ Safari: Vollständig unterstützt
- ⚠️ Safari iOS: `behavior: 'instant'` wird zu `'auto'` umgewandelt (kein Problem)

## Wartung

### Wenn neue Wizard-Schritte hinzugefügt werden

Keine Änderungen nötig! Die Funktion funktioniert automatisch für alle Links innerhalb des `data-controller="tournament"` Elements.

### Wenn Probleme auftreten

1. **Position wird nicht wiederhergestellt:**
   - Prüfe Browser Console auf Fehler
   - Prüfe ob `data-tournament-id` auf dem Container-Element gesetzt ist
   - Prüfe sessionStorage in DevTools

2. **Position ist leicht falsch:**
   - Könnte an dynamischem Content liegen, der nach dem Laden erscheint
   - Evt. zusätzliches `requestAnimationFrame` oder `setTimeout` verwenden

3. **Position wird bei jedem Reload wiederhergestellt:**
   - Sollte nicht passieren, da Position nach Wiederherstellung gelöscht wird
   - Wenn doch: Prüfe ob `sessionStorage.removeItem()` aufgerufen wird

## Zukünftige Verbesserungen

Mögliche Erweiterungen:

1. **Smooth Scrolling für lange Distanzen:**
   ```javascript
   const distance = Math.abs(window.scrollY - scrollY)
   const behavior = distance > 1000 ? 'smooth' : 'instant'
   window.scrollTo({ top: scrollY, behavior })
   ```

2. **Timeout für alte Positionen:**
   ```javascript
   const timestamp = Date.now()
   sessionStorage.setItem(`${scrollKey}_time`, timestamp)
   // Beim Wiederherstellen: Nur wenn < 30 Minuten alt
   ```

3. **Visualisierung während Wiederherstellung:**
   ```javascript
   // Kurzer Indikator während Scroll-Wiederherstellung
   showRestoreIndicator()
   ```

## Referenzen

- [MDN: Window.scrollTo()](https://developer.mozilla.org/en-US/docs/Web/API/Window/scrollTo)
- [MDN: Window Storage](https://developer.mozilla.org/en-US/docs/Web/API/Window/sessionStorage)
- [Stimulus Lifecycle Callbacks](https://stimulus.hotwired.dev/reference/lifecycle-callbacks)
- [Turbo Events](https://turbo.hotwired.dev/reference/events)


