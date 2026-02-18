# Video Translation - Setup & Usage

## Übersicht

Der `VideoTranslationService` übersetzt automatisch nicht-englische Video-Titel ins Englische mit der Google Cloud Translation API.

### Warum Übersetzung?

Von unseren **3.566 Videos** sind:
- 🇬🇧 **1.810 Englisch** (51%)
- 🇰🇷 **903 Koreanisch** (25%) ← Brauchen Übersetzung
- 🇻🇳 **483 Vietnamesisch** (14%) ← Brauchen Übersetzung
- 🇨🇳 **251 Chinesisch** (7%) ← Brauchen Übersetzung
- 🇪🇸 **52 Spanisch** (1.5%)

→ **~49% der Videos brauchen Übersetzung!**

## Setup

### 1. Google Cloud Translation API Key

Du brauchst einen API Key von Google Cloud:

1. Gehe zu [Google Cloud Console](https://console.cloud.google.com/)
2. Erstelle ein Projekt (oder wähle bestehendes)
3. Aktiviere "Cloud Translation API"
4. Erstelle API Key (Credentials → Create Credentials → API Key)
5. (Optional) Beschränke Key auf Translation API

### 2. API Key konfigurieren

**Option A: Rails Credentials (empfohlen)**

```bash
bin/rails credentials:edit
```

Füge hinzu:
```yaml
google:
  translate_api_key: AIzaSyDEIN_TRANSLATE_KEY_HIER
```

**Option B: Environment Variable**

```bash
export GOOGLE_TRANSLATE_API_KEY="AIzaSyDEIN_TRANSLATE_KEY_HIER"
```

### 3. Google Cloud Translate Gem

Bereits im Gemfile (von carambus_master):

```ruby
gem 'google-cloud-translate', '~> 3.7'
```

Falls noch nicht installiert:
```bash
bundle add google-cloud-translate
```

## Usage

### Test Translation

```bash
bin/rails videos:test_translation["안녕하세요 당구"]
```

**Output:**
```
================================================================================
TRANSLATION TEST
================================================================================

Original text: 안녕하세요 당구
Detected language: ko (confidence: 99.0%)
Translated: Hello billiards

✅ Translation working!
================================================================================
```

### Statistics

```bash
bin/rails videos:translation_stats
```

**Output:**
```
================================================================================
VIDEO TRANSLATION STATISTICS
================================================================================

Total videos:              3566
Already translated:        0 (0.0%)
Non-English videos:        1756
Need translation:          1756

Videos by language:
  en                 1810 (0 translated)
  ko                  903 (0 translated)
  vi                  483 (0 translated)
  zh-Hant             251 (0 translated)
  es                   52 (0 translated)
================================================================================
```

### Translate All Videos

```bash
bin/rails videos:translate
```

**Was passiert:**
1. Findet alle nicht-englischen Videos ohne Übersetzung
2. Sortiert nach View Count (wichtigste zuerst)
3. Übersetzt Titel ins Englische
4. Speichert Übersetzung in `data->>'translated_title'`
5. Speichert Original-Sprache in `data->>'original_language'`

**Output:**
```
================================================================================
VIDEO TRANSLATION
================================================================================

Found 1756 videos needing translation

✅ Translated 1756 video titles
================================================================================
```

### Translate Einzelnes Video

```bash
bin/rails videos:translate_video[123]
```

## Wie es funktioniert

### 1. Detection

Der Service erkennt automatisch Videos die Übersetzung brauchen:

```ruby
# Videos die übersetzt werden sollten:
videos_to_translate = Video
  .where(metadata_extracted: true)                    # Metadata vorhanden
  .where("data->>'translated_title' IS NULL")         # Noch nicht übersetzt
  .where.not(language: ['en', 'en-US'])               # Nicht Englisch
  .order(view_count: :desc)                           # Wichtigste zuerst
```

### 2. Translation

```ruby
service = VideoTranslationService.new
translated = service.translate_title(video, target_language: 'en')
```

**Was wird gespeichert:**
```ruby
video.data = {
  'translated_title' => 'Translated English Title',
  'original_language' => 'ko',  # Detected source language
  'translated_at' => '2026-02-18T10:30:00Z'
}
```

### 3. Verwendung im Code

```ruby
# Im View oder Controller
video = Video.find(123)

# Original Titel (z.B. Koreanisch)
video.title  
# => "조명우 VS 마틴 혼 | World Cup 2025"

# Übersetzter Titel (Englisch)
video.translated_title
# => "Cho Myung Woo VS Martin Horn | World Cup 2025"

# Prüfen ob Übersetzung nötig
video.needs_translation?
# => true (wenn nicht-Englisch und noch keine Übersetzung)
```

### 4. Cleaning

Der Service bereinigt automatisch:
- Branding-Tags (`[Rewind]`, `[Best of]`, etc.)
- Fußnoten (`(ft. ...)`)
- Übermäßige Interpunktion

**Beispiel:**
```
Original:     [리플레이X] 조명우 VS 마틴 혼!!!
Translated:   Cho Myung Woo VS Martin Horn
              ↑ [Rewind] und !!! entfernt
```

## Kosten

Google Cloud Translation API Kosten:

- **$20 pro 1 Million Zeichen**
- Durchschnittlicher Titel: ~50 Zeichen
- **1.756 Videos × 50 Zeichen = 87.800 Zeichen**
- **Kosten: ~$0.0018** (weniger als 1 Cent!)

→ **Sehr günstig!** Die 3.566 Videos kosten ca. $0.004 zu übersetzen.

### Quota Management

- Standard Quota: 500.000 Zeichen/Tag
- Unser Bedarf: ~90.000 Zeichen (alle Videos)
- → **Kein Problem!** Alle Videos in einem Durchlauf

## Integration

### In Views

```erb
<!-- app/views/videos/show.html.erb -->
<h1><%= @video.translated_title %></h1>
<p class="text-gray-600">
  Original: <%= @video.title %>
  <% if @video.json_data['original_language'] %>
    (<%= @video.json_data['original_language'] %>)
  <% end %>
</p>
```

### In Search/Filter

```ruby
# Suche in übersetzten Titeln
def search_videos(query)
  Video.where(
    "title ILIKE :q OR data->>'translated_title' ILIKE :q",
    q: "%#{query}%"
  )
end
```

### In API/JSON

```ruby
# app/serializers/video_serializer.rb
def as_json(options = {})
  {
    id: id,
    title: title,
    translated_title: translated_title,
    original_language: json_data['original_language'],
    # ...
  }
end
```

## Batch Processing

Für große Mengen Videos:

```ruby
# Translate in chunks to avoid timeout
Video.needs_translation.find_in_batches(batch_size: 100) do |batch|
  service = VideoTranslationService.new
  service.translate_batch(batch)
  
  sleep(1) # Small delay between batches
end
```

## Language Detection

Der Service kann auch Sprachen erkennen:

```ruby
service = VideoTranslationService.new
detection = service.detect_language("당구 선수")

detection
# => { language: 'ko', confidence: 0.99 }
```

## Error Handling

Der Service ist fehler-tolerant:

```ruby
# Falls Translation fehlschlägt:
translated = service.translate_title(video)
# => Returns original title as fallback

# Falls API Key fehlt:
service.available?
# => false

# Im Log:
[VideoTranslation] No Google Translate API key found. Translation disabled.
```

## Production Deployment

### 1. API Key setzen

```bash
# On server
EDITOR=nano bin/rails credentials:edit --environment production
```

Füge hinzu:
```yaml
google:
  translate_api_key: AIzaSy_PRODUCTION_KEY
```

### 2. Einmalige Translation

```bash
# Alle Videos übersetzen
cd /var/www/carambus_api/current
RAILS_ENV=production bin/rails videos:translate
```

### 3. Automatische Translation für neue Videos

In `ScrapeYoutubeJob`:

```ruby
class ScrapeYoutubeJob < ApplicationJob
  def perform(days_back: 7)
    # ... scraping code ...
    
    # After scraping, translate new videos
    TranslateNewVideosJob.perform_later
  end
end

class TranslateNewVideosJob < ApplicationJob
  def perform
    service = VideoTranslationService.new
    return unless service.available?
    
    # Translate videos from last 7 days
    recent = Video.where('created_at >= ?', 7.days.ago)
                  .where("data->>'translated_title' IS NULL")
                  .where.not(language: ['en', 'en-US'])
    
    service.translate_batch(recent)
  end
end
```

## Testing

```bash
# 1. Test API access
bin/rails videos:test_translation

# 2. Check stats
bin/rails videos:translation_stats

# 3. Translate single video
bin/rails videos:translate_video[123]

# 4. Check result
bin/rails runner "
  v = Video.find(123)
  puts 'Original: ' + v.title
  puts 'Translated: ' + v.translated_title
  puts 'Language: ' + v.json_data['original_language'].to_s
"
```

## Credentials Format

**WICHTIG:** Der Translation Service verwendet einen **anderen Pfad** als der YouTube Scraper:

```yaml
# config/credentials.yml.enc
google:
  translate_api_key: AIzaSy_TRANSLATE_KEY  # ← Nested unter 'google'

youtube_api_key: AIzaSy_YOUTUBE_KEY        # ← Top-level
```

**Beide Keys können unterschiedlich sein!**

## Examples

### Beispiel 1: Koreanisch → Englisch

```ruby
video = Video.find_by(title: "조명우 VS 마틴 혼")

service = VideoTranslationService.new
service.translate_title(video)

video.reload
video.translated_title
# => "Cho Myung Woo VS Martin Horn"
```

### Beispiel 2: Vietnamesisch → Englisch

```ruby
video = Video.find_by(title: "Bao Phương Vinh vs Jaspers")

service.translate_title(video)
# => "Bao Phuong Vinh vs Jaspers" (schon fast Englisch, minimal cleaned)
```

### Beispiel 3: Chinesisch → Englisch

```ruby
video = Video.find_by(title: "世界杯三顆星")

service.translate_title(video)
# => "World Cup Three Cushion"
```

## Success Metrics

Für unsere 3.566 Videos:

- ✅ **1.810 English** - keine Übersetzung nötig
- 📝 **1.756 Non-English** - brauchen Übersetzung
  - 903 Korean
  - 483 Vietnamese
  - 251 Chinese
  - 52 Spanish
  - 67 Others

**Nach Translation:**
- ✅ 100% Videos haben englische Titel
- ✅ Original-Titel bleiben erhalten
- ✅ Original-Sprache gespeichert
- ✅ Suchbar in beiden Sprachen

## Status

✅ **Service Ready**
- VideoTranslationService implementiert
- Rake Tasks erstellt
- Error handling vorhanden
- Batch processing supported

🔜 **Next Steps**
1. API Key in credentials setzen
2. `bin/rails videos:translate` ausführen
3. Ergebnisse überprüfen
4. In Views/Search integrieren

---

**Ready to Translate!** 🌍→🇬🇧
