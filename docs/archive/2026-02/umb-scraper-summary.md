# UMB Scraper - Chat Summary & Status

**Datum:** 18. Februar 2026  
**Kontext:** Debugging und Fertigstellung des UMB Tournament Scrapers

## 🎯 Was wurde erreicht

### 1. Core Scraper Implementation
Der `UmbScraper` Service (`app/services/umb_scraper.rb`) wurde vollständig debugged und ist jetzt **production-ready**.

**Hauptfunktionalität:**
- Scraped Turnierdaten von `https://files.umb-carom.org/public/FutureTournaments.aspx`
- Parst HTML-Tabellen mit komplexer Struktur (Jahr/Monat/Datum in verschiedenen Zellen)
- Erstellt/aktualisiert `InternationalTournament` Records mit `official_umb: true`

### 2. Gelöste Probleme

#### Problem 1: Jahreserkennung für 2027/2028 Events
**Symptom:** Events aus 2027/2028 wurden mit 2026 Daten gespeichert oder komplett ignoriert

**Root Cause:** Die HTML-Tabelle hat Zellen mit mehrzeiligem Content:
```
"2027\n\nApril\n05 - 11\n..."
```

Die Regex-Patterns haben den gesamten Cell-Text geprüft, was fehlschlug.

**Lösung:** (Commit `d333ae6a`)
```ruby
# Split first cell by newlines and get first non-empty line
first_cell_lines = first_cell_raw&.split(/\n+/)&.map(&:strip)&.reject(&:blank?) || []
first_line = first_cell_lines.first || ''

# Check if FIRST LINE is a year (like "2027" or "2026")
if first_line.match?(/^\s*(2026|2027|2028|2029|2030)\s*$/)
  current_year = match[1].to_i
end
```

**Ergebnis:** ✅ 33 Tournaments korrekt gescraped (20x 2026, 10x 2027, 3x 2028)

#### Problem 2: Cross-Month Events (Turniere über Monatsgrenzen)
**Symptom:** Events wie "Feb 26 - Mar 01" wurden als Duplikate oder Fragmente gespeichert

**Lösung:** Implementierung eines `pending_cross_month` Hash-Mechanismus:
1. Zeile mit `"26 -"` → Start wird gespeichert in `pending_cross_month`
2. Zeile mit `"- 01"` → End wird mit Start kombiniert → komplettes Event erstellt

**Ergebnis:** ✅ Cross-month events werden korrekt als einzelnes Event mit vollständigem Datum gespeichert

#### Problem 3: Deduplication bei Jahr-Übergängen
**Symptom:** SQL Error "Dangerous query method" bei `order()`

**Lösung:** Umstellung auf Ruby-basierte Deduplication:
```ruby
candidates = InternationalTournament.where(name: data[:name])
  .where(location: data[:location])
  .where('start_date BETWEEN ? AND ?', dates[:start_date] - 30.days, dates[:start_date] + 30.days)
  .to_a

existing = candidates.min_by { |t| (t.start_date - dates[:start_date]).abs }
```

**Ergebnis:** ✅ Keine Duplikate, korrekte Updates bei Re-Runs

#### Problem 4: Zu aggressive Filterung
**Symptom:** Valide Tournament-Namen wurden als "Fragmente" gelöscht

**Lösung:** Präzisere Regex-Patterns in `extract_tournament_from_row`:
```ruby
# Skip if name is ONLY a date pattern (fragment rows like "26 -", "- 01", "06 - 12")
return nil if name_text.match?(/^-?\s*\d{1,2}\s*-\s*\d{0,2}\s*$/)

# Skip if name is just a month name with numbers (malformed rows)
return nil if name_text.match?(/^(January|February|...|December)\s*\d/i)
```

**Ergebnis:** ✅ Nur echte Fragmente werden gefiltert, valide Events bleiben erhalten

### 3. Frontend Integration
- **Badge System:** UMB Tournaments zeigen "UMB Official" Badge in `international/index.html.erb`
- **Filter:** UMB-Filter in `international/tournaments/index.html.erb`
- **Scope:** `official_umb` Scope im `InternationalTournament` Model

### 4. Rake Tasks
- `international:scrape_umb` - Führt den Scraper aus
- `international:cleanup_umb_fragments` - Bereinigt fehlerhafte Einträge (Fragmente, Meta-Labels, zu lange Namen)

## 📋 Aktueller Stand

### ✅ Funktioniert perfekt
- Jahr-Erkennung (2026-2030)
- Monats-Erkennung mit korrektem Jahr-Context
- Cross-month Events (Feb 26 - Mar 01, etc.)
- Date Parsing für alle Format-Varianten
- Deduplication (by name + location + date ±30 Tage)
- Frontend-Anzeige mit Badges

### ⚠️ Debug-Logging
Aktuell ist ausführliches Debug-Logging aktiv (`Rails.logger.info` für jede Row).  
**Entscheidung:** Logging bleibt erstmal so (hilft bei zukünftigen Issues)

## 🎯 Nächste Schritte - ORIGINAL PLAN

**WICHTIG:** Wir sind vom ursprünglichen Plan abgekommen durch das intensive Debugging!

### Original Ziel (vor dem Debugging)
Der User wollte **weitere Datenquellen** für internationale Turniere erschließen, nachdem der UMB Scraper grundsätzlich funktionierte.

### Mögliche nächste Schritte

1. **Weitere Scraper implementieren**
   - Andere internationale Billard-Verbände (z.B. BWA, CEB, ACC)
   - Nationale Verbände mit internationalen Events
   - Turnier-Portale (z.B. Kozoom, wenn verfügbar)

2. **Scraper-Automatisierung**
   - Cron Job / Scheduled Task für regelmäßiges Scraping
   - Sidekiq Job für Background Processing
   - Error Notifications bei Scraping-Failures

3. **Data Quality Monitoring**
   - Dashboard für Scraper-Status
   - Alerts bei fehlenden/duplizierten Daten
   - Audit-Log für Änderungen an Tournament-Daten

4. **Frontend Enhancements**
   - Erweiterte Filter (nach Land, Disziplin, Zeitraum)
   - Kalender-Ansicht der Turniere
   - Export-Funktionen (iCal, CSV)

5. **API Integration**
   - REST API für Tournament-Daten
   - Webhook-System für Tournament-Updates
   - Public API für externe Consumer

## 📝 Technische Details für Folgechat

### Wichtige Files
```
app/services/umb_scraper.rb           # Core Scraper Logic
app/models/international_tournament.rb # Tournament Model
app/models/international_source.rb     # Source Management
lib/tasks/international.rake          # Rake Tasks
app/views/international/index.html.erb # Main View mit Badges
app/views/international/tournaments/index.html.erb # List View mit Filter
```

### Database Schema
```ruby
# international_tournaments
- name: string
- location: string
- start_date: date
- end_date: date
- tournament_type: string
- organization: string
- official_umb: boolean (default: false)
- international_source_id: bigint (foreign key)

# international_sources
- name: string
- source_type: string (e.g., 'umb')
- base_url: string
- last_scraped_at: datetime
- metadata: jsonb
```

### Key Lessons Learned
1. **HTML Parsing ist komplex:** Multi-line cells, shifted data, header rows
2. **Newline-Splitting ist key:** Bei komplexen HTML-Strukturen immer zuerst splitten
3. **Robust Error Handling:** Scraper muss mit variierenden HTML-Strukturen umgehen können
4. **Deduplication ist wichtig:** Bei Re-Runs keine Duplikate erzeugen
5. **Debug-Logging ist Gold wert:** Bei Web Scraping immer ausführlich loggen

## 🚀 Deployment Status

### Production Server
- **Server:** `carambus_api` (www-data@carambus)
- **Letzte Deployment:** 18. Feb 2026, ca. 16:52 Uhr
- **Commit:** `d333ae6a` - "Fix year detection: split multi-line cells and check first line"
- **Status:** ✅ Production-ready, 33 Tournaments erfolgreich gescraped

### Testing Command
```bash
cd ~/carambus_api/current
RAILS_ENV=production bundle exec rails international:scrape_umb
```

## 🎬 Prompt für nächsten Chat

```
Ich arbeite an einem Carambus Rails-Projekt (Multi-Tenant Billard-Management System).

AKTUELLER STAND:
- UMB Scraper ist fertig und funktioniert perfekt (33 Tournaments von 2026-2028 gescraped)
- Frontend zeigt UMB Tournaments mit Badge und Filter
- Code ist in carambus_master, deployed auf carambus_api Production Server

ZIEL:
[HIER SPEZIFISCHES ZIEL EINFÜGEN - z.B.:]
- Weitere internationale Turnier-Datenquellen erschließen
- ODER: Scraper automatisieren (Cron/Sidekiq)
- ODER: Frontend erweitern (Kalender-View, erweiterte Filter)
- ODER: Data Quality Monitoring implementieren

TECHNISCHER KONTEXT:
- Rails 7.2 App mit PostgreSQL
- Multi-Tenant Setup (Apartment gem)
- Background Jobs mit Sidekiq (bereits im Setup)
- Scraping mit Nokogiri + Net::HTTP

Bitte lies zuerst das Summary in @UMB_SCRAPER_SUMMARY.md und schlage dann konkrete nächste Schritte vor.
```

---

**Chat-ID für Referenz:** 14f4b221-bda1-46e9-8a69-0e961ed529c6  
**Transcript:** `/Users/gullrich/.cursor/projects/Volumes-EXT2TB-gullrich-DEV-carambus/agent-transcripts/14f4b221-bda1-46e9-8a69-0e961ed529c6.txt`
