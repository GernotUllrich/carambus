# Translation System - Dokumentation

## Übersicht

Das Carambus Translation System bietet zwei Übersetzungsmethoden:
1. **DeepL mit Billard-Glossaren** (Standard, günstig, schnell)
2. **AI-Translation** (optional, für komplexe Texte)

## 1. Verwendung im Admin-Interface

### Tags übersetzen:

1. Tag bearbeiten (`/admin/tags/:id/edit`)
2. Felder ändern (z.B. `name`, `description`)
3. Checkbox aktivieren: **"🌐 Nach dem Speichern automatisch übersetzen"**
4. Übersetzungsmethode wählen:
   - **💰 DeepL mit Glossar** (empfohlen für EN/NL → DE/EN)
   - **🤖 AI (Claude/GPT)** (für FR oder komplexe Texte)
5. Speichern → Automatische Übersetzung!

## 2. DeepL-Glossare

### Verfügbare Glossare:

- **EN → DE**: ~50 Billard-Begriffe
- **NL → DE**: ~50 Billard-Begriffe
- **NL → EN**: ~50 Billard-Begriffe

### Wichtige Begriffe im Glossar:

| English | Deutsch | Nederlands |
|---------|---------|------------|
| American Position | Amerika-Position | Amerikaanse positie |
| cue ball | Spielball | speelbal |
| object ball | Objektball | objectbal |
| cushion/band | Bande | band |
| three-cushion | Dreiband | driebanden |
| carom | Karambolage | carambole |
| in glasses | in Brillenstellung | - |
| shot | Stoß | stoot |
| position | Position | positie |
| diamond | Diamant | diamant |

## 3. Glossare pflegen und erweitern

### Glossar bearbeiten:

Öffnen Sie: `app/services/deepl_glossary_service.rb`

#### Neue Begriffe hinzufügen:

```ruby
# Für EN→DE
BILLIARD_GLOSSARY_EN_DE = {
  # ... bestehende Begriffe ...
  "new term" => "neuer Begriff",
}

# Für NL→DE
BILLIARD_GLOSSARY_NL_DE = {
  # ... bestehende Begriffe ...
  "nieuwe term" => "neuer Begriff",
}

# Für NL→EN
BILLIARD_GLOSSARY_NL_EN = {
  # ... bestehende Begriffe ...
  "nieuwe term" => "new term",
}
```

### Glossar aktualisieren:

Nach Änderungen in `deepl_glossary_service.rb`:

#### Methode 1: Rake Task (empfohlen)

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
bin/rails glossary:update
```

#### Methode 2: Rails Runner

```bash
bin/rails runner "
  service = DeeplGlossaryService.new
  service.create_billiard_glossary_en_de
  service.create_billiard_glossary_nl_de
  service.create_billiard_glossary_nl_en
  puts '✅ Alle Glossare aktualisiert!'
"
```

**Wichtig:** Glossare werden automatisch neu erstellt und alte Versionen überschrieben.

### Weitere Glossar-Befehle:

```bash
# Alle Glossare auflisten
bin/rails glossary:list

# Glossar-Statistiken anzeigen
bin/rails glossary:stats

# Übersetzungen mit Glossaren testen
bin/rails glossary:test
```

### Glossare anzeigen:

```bash
bin/rails runner "
  service = DeeplGlossaryService.new
  glossaries = service.list_glossaries
  glossaries.each do |g|
    puts \"#{g['name']}: #{g['glossary_id']} (#{g['source_lang']}→#{g['target_lang']})\"
  end
"
```

## 4. Spezielle Billard-Begriffe

### Brillenstellung ("in glasses")

**Definition:** Nahe zusammenliegende Bälle 2 und 3, die ein brillenartiges Muster bilden.

**Übersetzungen:**
- EN: "in glasses" → DE: "in Brillenstellung"
- NL: "in brillenstand" → DE: "in Brillenstellung"

**Beispiel:**
> "The balls are positioned in glasses along the cushion."
> → "Die Bälle sind in Brillenstellung entlang der Bande positioniert."

**⚠️ WICHTIG - Kontext erforderlich:**

"glasses" ist ein mehrdeutiger Begriff (Gläser/Brillen vs. Brillenstellung). 
Das Glossar funktioniert nur mit **ausreichend Kontext**:

✅ **Funktioniert gut:**
- "positioned in glasses along the band" → "in Brillenstellung"
- "the balls are in glasses" (in vollständigem Satz) → "in Brillenstellung"
- "place the balls in glasses" → "in Brillenstellung"

❌ **Kann fehlschlagen:**
- "in glasses" (isoliert) → "in Gläsern" (wörtlich)
- Sehr kurze Sätze ohne Kontext

**Lösung bei Problemen:**
1. Mehr Kontext im Text verwenden
2. Alternative: AI-Translation nutzen (versteht Fachbegriffe besser)
3. Manuell nachbearbeiten

### Weitere wichtige Fachbegriffe:

- **Freie Partie** = Libre (nicht Dreiband!)
- **Cadre** = Feldspiel (z.B. Cadre 47/2)
- **Massé** = Massé-Stoß (steiler Stoß)
- **Effet** = Effet/Spin
- **Nachläufer** = Follow shot
- **Rückläufer** = Draw shot

## 5. AI-Translation (Optional)

### Wann AI verwenden?

- Französische Quellen (FR → DE/EN)
- Komplexe, kontextabhängige Beschreibungen
- Wenn Glossar nicht ausreicht

### AI konfigurieren:

Die AI-Translation ist bereits implementiert, benötigt aber gültige API-Keys:

```bash
EDITOR=nano bin/rails credentials:edit --environment development
```

Fügen Sie hinzu:
```yaml
anthropic_key: sk-ant-api03-...
# ODER
openai:
  api_key: sk-proj-...
```

**Kosten:**
- DeepL: ~kostenlos (normale DeepL-Kosten)
- OpenAI (GPT-4o-mini): ~$0.01 pro Tag-Übersetzung
- Anthropic (Claude): ~$0.01 pro Tag-Übersetzung

## 6. Technische Details

### Translatable Concern

Models mit `include Translatable` unterstützen automatische Übersetzung:

```ruby
# Tag übersetzen
tag = Tag.find(1)
tag.translate_to_target_languages!(force: true, method: 'deepl')

# Oder mit AI
tag.translate_to_target_languages!(force: true, method: 'ai')
```

### Services:

- `DeeplTranslationService`: DeepL API mit Glossar-Support
- `DeeplGlossaryService`: Glossar-Verwaltung
- `AiTranslationService`: OpenAI/Anthropic mit Billard-Kontext

## 7. Troubleshooting

### Problem: "Glossar nicht gefunden"

```bash
# Glossare neu erstellen
bin/rails runner "
  DeeplGlossaryService.new.create_billiard_glossary_en_de
  DeeplGlossaryService.new.create_billiard_glossary_nl_de
  DeeplGlossaryService.new.create_billiard_glossary_nl_en
"
```

### Problem: "DeepL API Error 403"

→ API-Key in Credentials überprüfen (sollte OHNE `:fx` Suffix sein für Pro)

### Problem: "Begriff wird nicht übersetzt"

1. Begriff zum Glossar hinzufügen (siehe Abschnitt 3)
2. Glossar neu erstellen
3. Server neu starten
4. Test mit kleinem Text

## 8. Best Practices

### Glossar-Einträge:

✅ **Gut:**
```ruby
"American Position" => "Amerika-Position"  # Eigenname bleibt teilweise
"cue ball" => "Spielball"                  # Klare Übersetzung
"in glasses" => "in Brillenstellung"       # Fachbegriff
```

❌ **Schlecht:**
```ruby
"ball" => "Kugel"  # Falsch: Im Billard heißt es "Ball"!
"Position" => "Standpunkt"  # Kontext fehlt
```

### Übersetzungs-Workflow:

1. Kleinere Texte (Namen): DeepL mit Glossar
2. Längere Texte (Beschreibungen): DeepL mit Glossar
3. Komplexe Texte (Tutorials): Optional AI
4. Französisch/andere Sprachen: AI oder manuell

---

**Kontakt für Fragen:**
- Dokumentation: `/docs/TRANSLATION.md`
- Code: `app/services/deepl_*_service.rb`
- Tests: `bin/rails runner` (siehe Beispiele oben)
