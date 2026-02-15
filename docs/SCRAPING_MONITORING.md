# Scraping Monitoring System 🔍

**Pragmatischer Ansatz: Monitoring > Tests!**

Statt aufwändige Mock-Tests zu schreiben, tracken wir **echte Produktions-Scraping-Operationen** mit detailliertem Monitoring.

## Warum Monitoring statt Tests?

✅ **Vorteile:**
- Erfasst **echte Fehler** in der Produktion
- Zeigt **Performance-Trends** über Zeit
- Erkennt **Datenqualitäts-Probleme** automatisch
- **Automatische Alerts** bei Anomalien
- **Keine Maintenance** von Mock-Daten nötig
- **Code-Coverage**: Zeigt welche Methoden tatsächlich laufen

❌ **Nachteile von aufwändigen Fixture-Tests:**
- Hoher Maintenance-Aufwand
- Mock-Daten veralten schnell (ClubCloud ändert sich)
- Testen nicht echte Probleme

---

## 🚀 Quick Start

### 1. Migrations ausführen

```bash
bin/rails db:migrate
```

### 2. Gemonitortes Scraping starten

```bash
# Statt:
rake scrape:daily_update

# Neu (mit Monitoring):
rake scrape:daily_update_monitored
```

### 3. Statistiken ansehen

```bash
# Übersicht aller Operationen (letzte 7 Tage)
rake scrape:stats

# Spezifische Operation
rake scrape:stats[daily_update]
rake scrape:stats[region_scraping]
```

### 4. Health Check

```bash
rake scrape:check_health
```

---

## 📊 Was wird getrackt?

### Für jede Scraping-Operation:

| Metrik | Bedeutung |
|--------|-----------|
| **created_count** | Neue Records erstellt |
| **updated_count** | Records aktualisiert |
| **deleted_count** | Records gelöscht |
| **unchanged_count** | Records unverändert |
| **error_count** | Fehler aufgetreten |
| **duration** | Laufzeit in Sekunden |
| **executed_at** | Zeitpunkt der Ausführung |

### Exception Tracking:

- **Vollständige Error Messages**
- **Stack Traces** (erste 3 Zeilen)
- **Kontext** (welches Objekt/Model)

### Code Coverage:

- Welche Scraping-Methoden wurden aufgerufen?
- `track_method("scrape_single_tournament_public")`

---

## 🛠️ Verfügbare Rake Tasks

### Scraping mit Monitoring

```bash
# Daily Update mit Monitoring
rake scrape:daily_update_monitored
```

**Was passiert:**
1. Startet Scraping für alle Regions
2. Trackt jede Operation (Tournaments, Locations, Clubs)
3. Zählt Creates/Updates/Deletes/Errors
4. Misst Performance
5. Speichert in `scraping_logs` Tabelle

### Statistiken

```bash
# Alle Operationen (letzte 7 Tage)
rake scrape:stats

# Output:
# 📊 Alle Scraping-Operationen (letzte 7 Tage):
# ================================================================
# 
# daily_update:
#   Durchläufe:      5 │ Ø 127.3s
#   Created:       123 │ Updated:    456
#   Errors:          2 │ Rate: 99.1%
#   Letzter Lauf: 2026-02-15 10:30

# Spezifische Operation
rake scrape:stats[region_scraping]
```

### Health Check

```bash
rake scrape:check_health

# Exit Code 0: Alles OK
# Exit Code 1: Anomalien gefunden (für CI/CD)
```

**Prüft automatisch:**
- Erfolgsrate < 90%? → ⚠️ Alarm
- Laufzeit > 5 Min? → ⚠️ Alarm

### Letzte Errors

```bash
rake scrape:recent_errors

# Output:
# ❌ Letzte Scraping-Errors (24h):
# ================================================================
# 
# 2026-02-15 10:30 - region_scraping (Region[5])
#   Errors: 3 │ Duration: 45.2s
#   └─ NoMethodError: undefined method `cc_id' for nil:NilClass
```

### Cleanup

```bash
# Entferne Logs älter als 90 Tage (default)
rake scrape:cleanup_logs

# Custom Zeitraum
rake scrape:cleanup_logs[30]  # 30 Tage
```

### CSV Export

```bash
# Exportiere letzte 30 Tage (default)
rake scrape:export_stats

# Custom Zeitraum
rake scrape:export_stats[7]  # Letzte 7 Tage

# Output: tmp/scraping_stats_2026-02-15.csv
```

---

## 🔧 Integration in eigene Scraping-Methoden

### Einfaches Monitoring

```ruby
# In Model mit include ScrapeMonitor
class Tournament < ApplicationRecord
  include ScrapeMonitor
  
  def my_scraping_method
    track_scraping("tournament_detail_scraping") do |monitor|
      # Dein Scraping-Code
      
      # Optional: Callbacks nutzen
      monitor.record_created(self)
      monitor.record_updated(self)
      monitor.track_method("scrape_details")
    end
  end
end
```

### Manuelles Monitoring

```ruby
monitor = ScrapingMonitor.new("my_operation", "Tournament[123]")

monitor.run do |m|
  # Dein Code
  
  Tournament.all.each do |t|
    begin
      if t.update(scraped_data)
        m.record_updated(t)
      else
        m.record_unchanged(t)
      end
    rescue => e
      m.record_error(t, e)
    end
  end
  
  m.track_method("scrape_all_tournaments")
end
```

---

## 📈 Langfristige Auswertung

### Datenbank-Queries

```ruby
# Alle Operationen heute
ScrapingLog.today

# Operationen mit Errors
ScrapingLog.with_errors

# Stats für spezifische Operation
ScrapingLog.stats_for("daily_update", since: 30.days.ago)
# => {
#      total_runs: 30,
#      avg_duration: 125.4,
#      total_created: 1234,
#      total_updated: 5678,
#      total_deleted: 12,
#      total_errors: 45,
#      success_rate: 99.2
#    }

# Alle Operations-Stats
ScrapingLog.all_operations_stats
```

### Trends erkennen

```ruby
# Performance-Trend (wird langsamer?)
logs = ScrapingLog.by_operation("daily_update").last_week.order(:executed_at)
logs.pluck(:executed_at, :duration)
# => [[2026-02-08, 120.3], [2026-02-09, 125.1], ...]

# Error-Trend (mehr Fehler?)
logs.pluck(:executed_at, :error_count)
```

---

## 🚨 Alerting (TODO)

### Option 1: Cron + Health Check

```bash
# In crontab:
0 */6 * * * cd /var/www/carambus && rake scrape:check_health || mail -s "Scraping Alert" admin@example.com
```

### Option 2: Exception Notification Gem

```ruby
# Gemfile
gem 'exception_notification'

# In scraping_monitor.rb
ExceptionNotifier.notify_exception(error, data: { operation: @operation })
```

### Option 3: Custom Webhook

```ruby
# In save_to_database
if @stats[:errors] > threshold
  Net::HTTP.post_form(
    URI('https://your-monitoring.service/alert'),
    operation: @operation,
    errors: @stats[:errors]
  )
end
```

---

## 🧪 Testing Strategy

### Unit Tests: NUR Concerns

```bash
# Teste nur Concerns (LocalProtector, SourceHandler)
rake test:concerns
```

### Smoke Tests: Basis-Funktionalität

```bash
# Teste dass Scraping nicht crashed
rake test:scraping
```

### Production Monitoring: ALLES ANDERE

```bash
# Echte Daten, echte Fehler, echte Performance
rake scrape:daily_update_monitored
rake scrape:check_health
```

---

## 📋 Empfohlener Workflow

### 1. Entwicklung

```bash
# Lokal testen mit Monitoring
rake scrape:daily_update_monitored

# Stats prüfen
rake scrape:stats
```

### 2. Deployment

```bash
# Nach Deploy: Health Check
rake scrape:check_health

# Falls Fehler: Details ansehen
rake scrape:recent_errors
```

### 3. Täglicher Betrieb

```bash
# Cron Job (3:00 Uhr nachts)
0 3 * * * cd /var/www/carambus && rake scrape:daily_update_monitored

# Cron Job (6:00 Uhr: Health Check)
0 6 * * * cd /var/www/carambus && rake scrape:check_health
```

### 4. Wöchentliche Review

```bash
# Jeden Montag: Stats der letzten Woche
rake scrape:stats

# CSV Export für Analyse
rake scrape:export_stats[7]
```

---

## 🎯 Code Coverage durch Monitoring

Das Monitoring zeigt welche Scraping-Methoden **tatsächlich in Production** ausgeführt werden:

```ruby
monitor.track_method("scrape_single_tournament_public")
monitor.track_method("scrape_locations")
monitor.track_method("scrape_clubs")
```

**Log-Output:**

```
📊 ScrapeMonitor Summary: region_scraping
   Methods called: scrape_single_tournament_public, scrape_locations, scrape_clubs
```

Damit siehst du:
- Welche Code-Pfade werden wirklich genutzt?
- Welche Methoden werden nie aufgerufen? (Dead Code)
- Welche Error-Handling-Pfade greifen?

---

## 💡 Vorteile gegenüber SimpleCov

| SimpleCov (Test Coverage) | Production Monitoring |
|---------------------------|----------------------|
| Zeigt was Tests abdecken | Zeigt was **tatsächlich läuft** |
| Basiert auf Mock-Daten | Basiert auf **echten Daten** |
| Kann 100% sein, aber irrelevant | Zeigt **echte Probleme** |
| Keine Performance-Daten | **Performance-Tracking** inklusive |
| Keine Error-Details | **Vollständige Exceptions** |

---

## 🔮 Zukünftige Erweiterungen

### Geplant:
- [ ] Grafana/Prometheus Integration
- [ ] Slack/Discord Webhooks bei Errors
- [ ] Automatische Retry bei temporären Fehlern
- [ ] Diff-Tracking (welche Felder ändern sich?)
- [ ] HTML-Snapshot-Archivierung bei Errors

### Nice-to-have:
- [ ] Web-Dashboard für Stats
- [ ] Vergleich: Vorher/Nachher bei Updates
- [ ] ClubCloud Changelog-Detection
- [ ] Automatische Fixture-Generierung aus Errors

---

## 📚 Siehe auch

- `/test/README.md` - Testing-Übersicht
- `/test/PRAGMATISCHE_TESTS.md` - Test-Philosophie
- `/test/TEST_FINAL.md` - Test-Status

---

**🎉 Happy Monitoring!**

*"In Production, nobody hears your mock data scream."* 🚀
