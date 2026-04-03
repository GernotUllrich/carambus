# Translation System - Dokumentation

## Übersicht

Das Carambus Translation System bietet zwei Übersetzungsmethoden:
1. **DeepL mit Billard-Glossaren** (Standard, günstig, schnell)
2. **AI-Translation (Anthropic Claude)** (für komplexe Texte, französische Quellen)

Es gibt **zwei Möglichkeiten** zur Übersetzung:
- **A) Automatische Übersetzung** beim Speichern von Models (Tags, Training Concepts, etc.)
- **B) Ad-hoc Translation Tool** für beliebige Texte im Admin-Dashboard

---

## 1. Ad-hoc Translation Tool (NEU!)

### Zugriff:

Dashboard → **"Translations"** im Sidebar-Menü

Oder direkt: `/admin/translations`

### Verwendung:

1. **Quelltext eingeben:** Beliebiger Text (mehrere Zeilen möglich)
2. **Quellsprache wählen:** NL (Standard), FR, EN, DE
3. **Zielsprache wählen:** DE (Standard), EN
4. **Übersetzungsmethode wählen:**
   - **DeepL API** (Standard) - Schnell, präzise, mit Billard-Glossar
   - **Claude (Anthropic)** - KI-basiert, sehr präzise, versteht Kontext besser
5. **"Übersetzen" klicken**
6. **Ergebnis kopieren** mit dem Copy-Button

### Features:

- ✅ Zeilenumbrüche werden korrekt übernommen
- ✅ Copy-to-Clipboard Funktion (auch mit Fallback für ältere Browser)
- ✅ Billard-spezifische Glossare werden automatisch verwendet
- ✅ Responsive Design, funktioniert auf allen Geräten
- ✅ Nur für Admin-User zugänglich

### Wann welche Methode?

| Situation | Empfohlene Methode | Grund |
|-----------|-------------------|-------|
| NL/EN → DE/EN | **DeepL** | Schnell, günstig, Glossar unterstützt |
| FR → DE/EN | **Claude** | Besseres Sprachverständnis |
| Komplexe Texte mit Kontext | **Claude** | Versteht Zusammenhänge besser |
| Fachbegriffe ohne Kontext | **DeepL** | Glossar-basiert, konsistent |
| Sehr lange Texte (>1000 Wörter) | **DeepL** | Günstiger, schneller |

### Beispiel-Workflow:

```
Eingabe (NL):
De speelbal moet de eerste band raken na de carambole.
De positie is moeilijk omdat de ballen in brillenstand liggen.

Methode: DeepL API
Ausgabe (DE):
Der Spielball muss die erste Bande nach der Karambolage berühren.
Die Position ist schwierig, weil die Bälle in Brillenstellung liegen.

→ Copy-Button klicken → Text ist in der Zwischenablage!
```

---

## 2. Automatische Übersetzung im Admin-Interface

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

### Konfiguration (API Keys)

Alle Services benötigen API-Keys in den Rails Credentials:

```bash
# Development
EDITOR=nano bin/rails credentials:edit --environment development

# Production
EDITOR=nano bin/rails credentials:edit --environment production
```

**Erforderliche Credentials:**

```yaml
# DeepL (erforderlich für beide Methoden)
deepl_key: "DeepL-Auth-Key xxxx..."

# Anthropic Claude (für AI-Methode im Ad-hoc Tool)
anthropic:
  api_key: "sk-ant-api03-..."

# OpenAI (optional, für AI-Methode)
openai:
  api_key: "sk-proj-..."
```

**Wie man API Keys erhält:**

1. **DeepL Pro API Key:**
   - Website: https://www.deepl.com/pro-api
   - Wichtig: **Pro API** (nicht Free), URL ist `api.deepl.com`
   - Kosten: ~€5.49/Monat + ~€20/Million Zeichen

2. **Anthropic API Key:**
   - Website: https://console.anthropic.com/
   - Account erstellen → API Keys → Create Key
   - Kosten: Pay-as-you-go, ~$3/Million Input-Tokens

3. **OpenAI API Key (optional):**
   - Website: https://platform.openai.com/api-keys
   - Kosten: ~$0.15/Million Input-Tokens (GPT-4o-mini)

**Kosten-Vergleich für typische Übersetzung (1000 Wörter):**
- DeepL: ~€0.02
- Anthropic Claude: ~$0.01-0.02
- OpenAI GPT-4o-mini: ~$0.01

## 6. Technische Details

### Ad-hoc Translation Tool - Architektur

**Controller:** `Admin::TranslationsController`

```ruby
# GET /admin/translations - Zeigt das Formular
def index
  # Zeigt leeres Formular oder vorherige Übersetzung
end

# POST /admin/translations - Führt Übersetzung aus
def index
  @translated_text = perform_translation(
    params[:text],
    params[:source_lang],
    params[:target_lang],
    params[:translation_method]
  )
end
```

**View:** `app/views/admin/translations/index.html.erb`
- Responsive Design mit CSS Grid
- JavaScript für Copy-to-Clipboard mit Fallback
- `simple_format` für korrekte Zeilenumbruch-Darstellung

**Services verwendet:**

```ruby
# DeepL mit Glossar
service = DeeplTranslationService.new
service.translate(
  text: text,
  source_lang: "NL",
  target_lang: "DE",
  use_glossary: true  # Automatisch das passende Glossar
)

# Anthropic Claude
service = AnthropicTranslationService.new
service.translate(
  text: text,
  source_lang: "NL",
  target_lang: "DE"
)
```

**Routing:**

```ruby
namespace :admin do
  resources :translations, only: [:index]
end
```

**Navigation:**

Automatisch im Administrate-Dashboard durch:
```ruby
# app/controllers/admin/application_controller.rb
NAVIGATION_RESOURCES = [
  # ...
  :translations,
  # ...
]
```

### Translatable Concern (für Models)

Models mit `include Translatable` unterstützen automatische Übersetzung:

```ruby
# Tag übersetzen
tag = Tag.find(1)
tag.translate_to_target_languages!(force: true, method: 'deepl')

# Oder mit AI
tag.translate_to_target_languages!(force: true, method: 'ai')
```

### Services Übersicht:

| Service | Zweck | API | Kosten |
|---------|-------|-----|--------|
| `DeeplTranslationService` | DeepL API mit Glossar-Support | DeepL Pro | ~€0.02/Seite |
| `DeeplGlossaryService` | Glossar-Verwaltung (CRUD) | DeepL Pro | Kostenlos |
| `AnthropicTranslationService` | Claude Sonnet 4.6 mit Kontext | Anthropic | ~$0.01/Request |
| `OpenaiTranslationService` | GPT-4 mit Kontext (optional) | OpenAI | ~$0.01/Request |
| `AiTranslationService` | Basis-Klasse für AI-Services | - | - |

## 7. Troubleshooting

### Ad-hoc Translation Tool

#### Problem: "Translations" erscheint nicht im Sidebar

**Ursache:** Navigation-Resource fehlt oder User ist kein Admin

**Lösung:**
```ruby
# In app/controllers/admin/application_controller.rb prüfen:
NAVIGATION_RESOURCES = [
  # ...
  :translations,  # ← Muss vorhanden sein
  # ...
]

# User muss admin sein:
def valid_action?
  current_user&.admin?
end
```

#### Problem: "DeepL übersetzt, aber Zeilenumbrüche fehlen"

**Ursache:** Browser-Display-Problem (nicht DeepL)

**Lösung:** Bereits implementiert mit `simple_format(@translated_text, {}, sanitize: false)`
```erb
<!-- In app/views/admin/translations/index.html.erb -->
<div class="text-result">
  <%= simple_format(@translated_text, {}, sanitize: false) %>
</div>
```

#### Problem: "Copy-Button funktioniert nicht"

**Ursache:** `navigator.clipboard` nicht verfügbar (HTTP statt HTTPS)

**Lösung:** Bereits implementiert mit Fallback:
```javascript
// Fallback verwendet document.execCommand('copy')
function fallbackCopy(text) {
  const textarea = document.createElement('textarea');
  textarea.value = text;
  // ... automatischer Fallback
}
```

#### Problem: "Anthropic API Error: model not found"

**Ursache:** Falscher Model-Name

**Lösung:** Aktuellen Model-Namen verwenden:
```ruby
# In app/services/anthropic_translation_service.rb
model: "claude-sonnet-4-6"  # Stand: März 2026
```

#### Problem: "Invalid API Key" für Anthropic/OpenAI

**Ursache:** API Key nicht korrekt in Credentials gespeichert

**Lösung:**
```bash
# Credentials prüfen
bin/rails credentials:show

# Sollte enthalten:
anthropic:
  api_key: "sk-ant-api03-..."

# Debugging: Service-Log prüfen
# Alle Services loggen den API Key (erste/letzte Zeichen):
# "Anthropic API Key loaded: sk-ant-api03-...xxx (length: 108)"
```

### Automatische Übersetzung (Models)

#### Problem: "Glossar nicht gefunden"

```bash
# Glossare neu erstellen
bin/rails runner "
  DeeplGlossaryService.new.create_billiard_glossary_en_de
  DeeplGlossaryService.new.create_billiard_glossary_nl_de
  DeeplGlossaryService.new.create_billiard_glossary_nl_en
"
```

#### Problem: "DeepL API Error 403"

→ API-Key in Credentials überprüfen (sollte OHNE `:fx` Suffix sein für Pro)

#### Problem: "Begriff wird nicht übersetzt"

1. Begriff zum Glossar hinzufügen (siehe Abschnitt 3)
2. Glossar neu erstellen
3. Server neu starten
4. Test mit kleinem Text

### Allgemeine API-Probleme

#### DeepL Rate Limit (429)

**Ursache:** Zu viele Requests in kurzer Zeit

**Lösung:**
- Pro Account hat höhere Limits
- Requests mit Delay zwischen Übersetzungen
- Batch-Übersetzungen vermeiden

#### Anthropic/OpenAI Rate Limit (429)

**Ursache:** Usage Tier zu niedrig oder Billing-Problem

**Lösung:**
- Account-Status prüfen: https://console.anthropic.com/
- Billing-Details aktualisieren
- Usage Tier upgraden (nach ersten $5-50 Ausgaben automatisch)

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
