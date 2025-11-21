# Tournament Wizard UI - Test-Anleitung

## Was wurde geändert?

Eine neue visuelle Wizard-Oberfläche für das Tournament Setup mit besserer UX für Turnierleiter.

### Neue Features:

1. **Progress Bar** - Zeigt visuell den Fortschritt (Schritt X von 6)
2. **Status-Icons** - ✅ (erledigt), ▶️ (aktiv), ⏸️ (ausstehend)
3. **Inline-Hilfe** - "Was macht dieser Schritt?" bei jedem Schritt
4. **Gefährliche Aktionen** - Deutlich markiert (z.B. "Rangliste finalisieren")
5. **Troubleshooting-Hilfen** - Häufige Probleme und Lösungen
6. **Responsive Design** - Funktioniert auch auf Tablets/Handys

## Test in Development (carambus_bcw)

### Setup

```bash
# 1. Branch ist bereits ausgecheckt
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw

# 2. Assets wurden bereits kompiliert
# (yarn build:css wurde bereits ausgeführt)

# 3. Rails Server starten (falls nicht schon läuft)
bin/dev
```

### Test-Schritte

1. **Öffne ein Tournament:**
   - Gehe zu: http://localhost:3000/tournaments/17068
   - Oder navigiere via: Regionalverbände → NBV → Turniere → "1. Quali NDM Dreiband TB"

2. **Prüfe die neue Wizard-UI:**

   **Du solltest sehen:**
   - Blauen Header mit "🎯 Turnier-Setup"
   - Progress Bar mit Fortschrittsanzeige
   - 6 Schritte als Karten mit Icons (✅/▶️/⏸️)
   - Der aktuelle Schritt ist blau hinterlegt
   - Abgeschlossene Schritte sind grün
   - Ausstehende Schritte sind grau

3. **Teste die Interaktion:**

   **Schritt 1 (Setzliste):**
   - Sollte ✅ sein (bereits erledigt)
   - Button "Erneut bearbeiten" sollte vorhanden sein
   - Klicke auf "💡 Was macht dieser Schritt?" → Details sollten aufklappen

   **Schritt 2 (Sync):**
   - Könnte ✅ oder ▶️ sein
   - "Jetzt synchronisieren" Button sollte funktionieren

   **Schritt 3 (Sortieren):**
   - Je nach State ▶️ oder ⏸️
   - Wenn aktiv: "Jetzt sortieren" Button sichtbar
   - Wenn pending: "Erst verfügbar nach vorherigem Schritt"

   **Schritt 4 (Finalisieren):**
   - ⚠️ ROT markiert (dangerous action!)
   - Confirm-Dialog beim Klick
   - Hilfetext warnt vor Irreversibilität

4. **Teste verschiedene Tournament States:**

   ```ruby
   # In Rails Console
   t = Tournament.find(17068)
   
   # Zurücksetzen auf verschiedene States zum Testen
   t.update(state: 'new_tournament')        # Schritt 1 aktiv
   t.update(state: 'accreditation_finished') # Schritt 3 aktiv
   t.update(state: 'tournament_seeding_finished') # Schritt 5 aktiv
   ```

5. **Mobile-Test:**
   - Browser-Fenster schmal machen (< 640px)
   - UI sollte responsive sein
   - Schritte sollten untereinander lesbar bleiben

### Was zu prüfen ist

✅ **Visuelles:**
- Progress Bar füllt sich entsprechend dem Fortschritt
- Icons passen zum Status
- Aktiver Schritt ist deutlich hervorgehoben
- Farben sind konsistent (blau=aktiv, grün=erledigt, grau=ausstehend, rot=danger)

✅ **Funktional:**
- Alle Buttons funktionieren wie vorher
- Disabled Buttons sind visuell deaktiviert
- Confirm-Dialoge bei gefährlichen Aktionen
- Hilfe-Texte klappen auf/zu

✅ **Responsive:**
- Mobile-Ansicht funktioniert
- Keine horizontalen Scrollbars
- Buttons sind groß genug für Touch

## Backend-Änderungen

**KEINE!** Alle Routen, Controller-Actions und Datenmodell bleiben unverändert.

Nur UI-Layer wurde verbessert:
- Helper-Methods für Status-Logik
- Partials für Wizard-UI
- CSS für Styling

## Bei Problemen

### CSS lädt nicht?

```bash
# Assets neu kompilieren
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
yarn build:css
```

### Fehler im View?

Prüfe Rails-Log:
```bash
tail -f log/development.log
```

### Zurück zur alten UI?

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
git checkout master
```

## Nächste Schritte (nach erfolgreichem Test)

1. **Feedback sammeln** von Turnierleitern
2. **Iterieren** - Verbesserungen basierend auf Feedback
3. **Merge in master** wenn stabil

## Bekannte Einschränkungen

- Helper-Method `wizard_current_step` basiert auf `tournament.state`
- Funktioniert nur für Tournaments, nicht für andere Turnier-Typen
- Troubleshooting-Sektion ist noch minimal (kann erweitert werden)

## Test-Checklist

- [ ] UI lädt ohne Fehler
- [ ] Progress Bar zeigt korrekten Fortschritt
- [ ] Icons passen zu Status
- [ ] Buttons funktionieren
- [ ] Hilfe-Texte klappen auf
- [ ] Gefährliche Aktionen haben Confirm-Dialog
- [ ] Mobile-Ansicht funktioniert
- [ ] Seedings-Tabelle wird korrekt angezeigt
- [ ] Keine Backend-Fehler im Log


