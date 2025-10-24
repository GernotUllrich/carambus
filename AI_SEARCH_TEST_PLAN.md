# KI-Suche - Testplan

## ✅ Implementierungs-Status

### Backend (100% Complete)
- [x] ruby-openai Gem installiert (v7.4.0)
- [x] OpenAI Initializer erstellt (`config/initializers/openai.rb`)
- [x] AiSearchService implementiert (`app/services/ai_search_service.rb`)
- [x] AiSearchController erstellt (`app/controllers/api/ai_search_controller.rb`)
- [x] Route hinzugefügt (`POST /api/ai_search`)
- [x] Syntax-Checks erfolgreich

### Frontend (100% Complete)
- [x] UI-Button in Navbar integriert
- [x] Expandierbarer Suchbereich mit Textfeld
- [x] Hilfe-Beispiele angezeigt
- [x] Stimulus Controller implementiert (`ai_search_controller.js`)
- [x] Loading States & Error Handling
- [x] Dark Mode Support

### Dokumentation (100% Complete)
- [x] Ausführliche Dokumentation (`docs/ai_search.md`)
- [x] Setup-Anleitung (`AI_SEARCH_SETUP.md`)
- [x] Testplan (dieses Dokument)

## 🧪 Manuelle Tests

### Test 1: Setup-Verifizierung

**Voraussetzung:** OpenAI API Key in credentials eingefügt

```bash
# Test 1.1: Rails laden
rails runner "puts 'OK'"

# Test 1.2: Credentials prüfen
rails runner "puts Rails.application.credentials.dig(:openai, :api_key).present? ? 'API Key gefunden ✓' : 'API Key fehlt ✗'"

# Test 1.3: OpenAI Client initialisieren
rails c
> client = OpenAI::Client.new
> client.models.list
# Sollte Liste von Modellen zurückgeben
```

**Erwartetes Ergebnis:** Alle Checks ✓

### Test 2: Service-Ebene

```bash
rails c

# Test 2.1: Einfache Anfrage
result = AiSearchService.call(query: "Turniere in Hamburg", user: User.first)
puts result.inspect

# Erwartete Ausgabe:
# {
#   success: true,
#   entity: "tournaments",
#   filters: "Region:HH",
#   confidence: 90-100,
#   explanation: "...",
#   path: "/tournaments?sSearch=Region:HH"
# }

# Test 2.2: Komplexe Anfrage
result = AiSearchService.call(query: "Dreiband Turniere in Westfalen letzte 2 Wochen", user: User.first)
puts result.inspect

# Erwartete Filter: "Discipline:Dreiband Region:WL Date:>heute-2w"

# Test 2.3: Fehlerfall (leere Anfrage)
result = AiSearchService.call(query: "", user: User.first)
puts result[:success] # => false
```

### Test 3: Controller-Ebene

```bash
# Rails Console
rails c

# Test 3.1: API Request simulieren
controller = Api::AiSearchController.new
controller.params = { query: "Turniere in Hamburg" }
# Manuelles Testen im Browser empfohlen (siehe unten)
```

### Test 4: Frontend (Browser)

**Setup:**
1. Server starten: `bin/dev` oder `rails s`
2. Browser öffnen: `http://localhost:3000`
3. Als User einloggen

**Test 4.1: UI-Elemente**
- [ ] "KI-Assistent" Button sichtbar in linker Navigation
- [ ] Button hat Gradient (blau → lila)
- [ ] ✨ Sparkle-Icon sichtbar
- [ ] Button ist zwischen Logo und Menü-Items

**Test 4.2: Panel öffnen/schließen**
- [ ] Klick auf Button öffnet Panel
- [ ] Panel zeigt Textfeld
- [ ] Beispiele werden angezeigt
- [ ] Zweiter Klick schließt Panel (toggle)

**Test 4.3: Einfache Suche**
1. Panel öffnen
2. Eingeben: "Turniere in Hamburg"
3. Enter drücken oder "Suchen" klicken
4. Erwartung:
   - [ ] Loading-Spinner erscheint
   - [ ] Erfolgs-Meldung mit Erklärung
   - [ ] Automatische Navigation zu `/tournaments?sSearch=Region:HH`
   - [ ] Gefilterte Ergebnisse werden angezeigt

**Test 4.4: Komplexe Suche**
1. Eingeben: "Dreiband Turniere in Westfalen letzte 2 Wochen"
2. Erwartung:
   - [ ] Navigation zu `/tournaments?sSearch=Discipline:Dreiband+Region:WL+Date:>heute-2w`
   - [ ] Korrekt gefilterte Ergebnisse

**Test 4.5: Spieler-Suche**
1. Eingeben: "Alle Spieler aus Berlin"
2. Erwartung:
   - [ ] Navigation zu `/players?sSearch=Region:BE`

**Test 4.6: Fehlerbehandlung**
1. Eingeben: "" (leer)
2. Erwartung:
   - [ ] Rote Fehlermeldung: "Bitte geben Sie eine Suchanfrage ein."

2. OpenAI Key entfernen (temporär)
3. Eingeben: "Test"
4. Erwartung:
   - [ ] Fehlermeldung: "OpenAI nicht konfiguriert"

**Test 4.7: Dark Mode**
1. Dark Mode aktivieren (User-Menü)
2. Panel öffnen
3. Erwartung:
   - [ ] Panel hat dunklen Hintergrund
   - [ ] Text ist hell/lesbar
   - [ ] Kontrast ist gut

**Test 4.8: Clear Button**
1. Text eingeben
2. "Löschen" klicken
3. Erwartung:
   - [ ] Textfeld wird geleert
   - [ ] Focus bleibt im Textfeld
   - [ ] Keine Fehlermeldung

**Test 4.9: Enter-Key**
1. Text eingeben
2. Enter drücken (ohne Shift)
3. Erwartung:
   - [ ] Formular wird abgeschickt
   - [ ] Wie bei Klick auf "Suchen"

**Test 4.10: Shift+Enter**
1. Text eingeben
2. Shift+Enter drücken
3. Erwartung:
   - [ ] Neue Zeile im Textarea
   - [ ] Kein Submit

## 📊 Test-Matrix: Beispiel-Queries

| Query | Erwartete Entity | Erwartete Filter | Confidence |
|-------|-----------------|------------------|------------|
| "Turniere in Hamburg" | tournaments | Region:HH | >90 |
| "Dreiband Turniere 2024" | tournaments | Discipline:Dreiband Season:2024/2025 | >85 |
| "Turniere letzte 2 Wochen" | tournaments | Date:>heute-2w | >85 |
| "Alle Spieler aus Westfalen" | players | Region:WL | >90 |
| "Meyer Hamburg" | players | Meyer Region:HH | >80 |
| "Vereine in Berlin" | clubs | Region:BE | >90 |
| "Spieltage heute" | parties | Date:heute | >85 |
| "Freie Partie Saison 2024/2025" | tournaments | Discipline:Freie Partie Season:2024/2025 | >85 |

## 🐛 Bekannte Edge Cases

### Mehrdeutige Anfragen

**Query:** "Hamburg"  
**Problem:** Könnte Turniere, Spieler, Clubs oder Locations meinen  
**Lösung:** KI wählt wahrscheinlichste Entity (meist: tournaments)  
**Confidence:** Niedrig (<70%)

**Query:** "2024"  
**Problem:** Könnte verschiedene Entities betreffen  
**Lösung:** Fragt implizit nach aktiver Season  
**Confidence:** Mittel (70-80%)

### Unklare Zeitangaben

**Query:** "Nächste Woche"  
**Problem:** Filter-Syntax hat kein "nächste Woche"  
**Lösung:** KI übersetzt zu `Date:>heute` oder `Date:>heute+7`  
**Hinweis:** Ggf. nicht präzise genug

### Tippfehler

**Query:** "Turnire in Hambrg"  
**Lösung:** GPT ist robust gegen Tippfehler  
**Erwartung:** Funktioniert meist trotzdem

### Nicht-unterstützte Entities

**Query:** "Alle Schiedsrichter"  
**Problem:** "Schiedsrichter" ist keine Entity in Carambus  
**Lösung:** KI versucht ähnliche Entity zu finden oder gibt Fehler  
**Erwartung:** Fehler oder Alternative

## 🔧 Debugging-Tipps

### Log-Analyse

**Development:**
```bash
tail -f log/development.log | grep -i "aisearch"
```

**Wichtige Log-Einträge:**
```
Processing by Api::AiSearchController#create
AiSearchService: Query processed successfully
AiSearchService error: [Error Message]
```

### Rails Console Debugging

```ruby
rails c

# Service direkt testen
result = AiSearchService.call(query: "Test", user: User.first)
puts JSON.pretty_generate(result)

# OpenAI Client testen
client = OpenAI::Client.new
response = client.chat(
  parameters: {
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: 'Hello' }]
  }
)
puts response.dig('choices', 0, 'message', 'content')
```

### Browser DevTools

**Network Tab:**
- POST zu `/api/ai_search` sollte Status 200 haben
- Response sollte JSON mit `success: true` sein

**Console Tab:**
- Keine JavaScript-Fehler
- Bei Problemen: `ai_search_controller.js` Fehler prüfen

## 📝 Checkliste vor Deployment

### Pre-Deployment
- [ ] Alle Tests oben durchgeführt
- [ ] OpenAI API Key in production credentials
- [ ] Budget-Limit in OpenAI Dashboard gesetzt
- [ ] Dokumentation vollständig
- [ ] Commit erstellt

### Production Deployment
- [ ] Assets precompilieren: `rails assets:precompile`
- [ ] Server neu starten
- [ ] Smoke Test durchführen (eine Anfrage testen)
- [ ] Logs monitoren

### Post-Deployment
- [ ] Team informieren über neue Funktion
- [ ] Monitoring für 24h
- [ ] Nutzung in OpenAI Dashboard prüfen
- [ ] Feedback sammeln

## 🎯 Success Criteria

**MVP gilt als erfolgreich wenn:**
- [x] Backend-Code kompiliert ohne Fehler
- [x] Frontend-UI wird korrekt angezeigt
- [ ] Mindestens 3 Test-Queries funktionieren
- [ ] Fehlerbehandlung funktioniert
- [ ] Dokumentation ist vollständig
- [ ] User kann Setup eigenständig durchführen

## 📊 Nächste Schritte (nach MVP)

### Phase 2: Verbesserungen
- [ ] Rate Limiting implementieren
- [ ] Analytics hinzufügen (welche Queries werden genutzt?)
- [ ] A/B Testing verschiedener Prompts
- [ ] Caching für häufige Queries
- [ ] Voice Input (macOS Diktat funktioniert bereits!)

### Phase 3: Features
- [ ] Multi-Entity Suche ("Turniere UND Spieler")
- [ ] Fuzzy Matching für Tippfehler
- [ ] Vorschläge bei niedriger Confidence
- [ ] Favoriten/History
- [ ] Shortcuts (Cmd+K für Quick Search)

---

**Status:** MVP Implementation Complete  
**Ready for Testing:** Yes  
**Nächster Schritt:** OpenAI API Key hinzufügen und manuelle Tests durchführen

