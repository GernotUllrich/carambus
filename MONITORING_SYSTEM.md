# 🔍 Scraping Monitoring System - Komplett-Übersicht

**Implementiert am: 2026-02-15**

---

## 🎯 Zielsetzung

Statt aufwändiger Mock-Tests: **Real-World Production Monitoring**

### Problem (vorher):
- ❌ Aufwändige Fixture-Tests (>500 Zeilen Mock-Data)
- ❌ Veralten schnell (ClubCloud ändert sich)
- ❌ Zeigen nicht echte Probleme
- ❌ Hoher Maintenance-Aufwand

### Lösung (jetzt):
- ✅ **Automatic Exception Tracking**
- ✅ **Performance Monitoring**
- ✅ **Create/Update/Delete Statistiken**
- ✅ **Code-Coverage** (welche Methoden laufen wirklich?)
- ✅ **Anomalie-Erkennung** (automatische Alerts)
- ✅ **Web-Dashboard** + CLI Tools
- ✅ **Null Maintenance** (selbst-aktualisierend)

---

## 📦 Komponenten

### 1. Backend (Models & Concerns)

#### `app/models/concerns/scraping_monitor.rb`
- **Concern** zum Einbinden in Scraping-Klassen
- Trackt automatisch: Exceptions, Performance, DB-Änderungen
- Callbacks: `record_created`, `record_updated`, `record_deleted`, `record_error`
- Methoden-Tracking für Code-Coverage

#### `app/models/scraping_log.rb`
- **Model** für Persistierung der Monitoring-Daten
- Scopes: `recent`, `by_operation`, `with_errors`, `today`, `last_week`
- Statistik-Methoden: `stats_for()`, `all_operations_stats()`
- Anomalie-Erkennung: `check_anomalies()`
- Cleanup: `cleanup_old_logs(keep_days)`

#### Migrations
- `db/migrate/20260215194955_create_scraping_logs.rb`
  - Tabelle: `scraping_logs`
  - Felder: operation, context, duration, created_count, updated_count, deleted_count, unchanged_count, error_count, errors_json, executed_at
  - Indizes: operation, executed_at, [operation, executed_at]

- `db/migrate/20260215195121_add_unchanged_count_to_scraping_logs.rb`
  - Ergänzt: `unchanged_count` Feld

### 2. Frontend (Web-Dashboard)

#### `app/controllers/scraping_monitor_controller.rb`
- **Dashboard-Controller**
- Actions: `index` (Übersicht), `operation` (Detail-View)
- Filtert nach Zeiträumen (1/7/30/90 Tage)

#### Views
- `app/views/scraping_monitor/index.html.erb`
  - Übersicht aller Operationen
  - Stats-Cards (Created/Updated/Deleted/Errors)
  - Operations-Tabelle mit Erfolgsrate
  - Recent Logs (letzte 50)
  - Auto-Refresh alle 30 Sekunden

- `app/views/scraping_monitor/operation.html.erb`
  - Detail-View für einzelne Operation
  - Execution History (letzte 100 Runs)
  - Performance-Trends
  - Error-Details (aufklappbar)

#### Routes
```ruby
get 'scraping_monitor', to: 'scraping_monitor#index'
get 'scraping_monitor/:id', to: 'scraping_monitor#operation'
```

### 3. CLI Tools (Rake Tasks)

#### `lib/tasks/scrape_monitored.rake`

| Task | Beschreibung |
|------|--------------|
| `rake scrape:daily_update_monitored` | Daily Scraping **mit Monitoring** |
| `rake scrape:stats` | Statistiken anzeigen (alle Operationen) |
| `rake scrape:stats[operation]` | Stats für spezifische Operation |
| `rake scrape:check_health` | Health Check (Exit Code 1 bei Anomalien) |
| `rake scrape:recent_errors` | Letzte Errors (24h) |
| `rake scrape:cleanup_logs[days]` | Alte Logs entfernen (default: 90 Tage) |
| `rake scrape:export_stats[days]` | CSV Export für Analyse |

---

## 🚀 Setup

### 1. Migrations ausführen

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
bin/rails db:migrate
```

### 2. Testen

```bash
# Test-Scraping mit Monitoring
rake scrape:daily_update_monitored

# Stats ansehen
rake scrape:stats
```

### 3. Dashboard öffnen

```bash
bin/rails server
open http://localhost:3000/scraping_monitor
```

---

## 📊 Was wird getrackt?

### Pro Scraping-Operation:

| Metrik | Typ | Beschreibung |
|--------|-----|--------------|
| `operation` | String | Name der Operation (z.B. "daily_update") |
| `context` | String | Kontext (z.B. "Region[5]") |
| `duration` | Float | Laufzeit in Sekunden |
| `created_count` | Integer | Neue Records erstellt |
| `updated_count` | Integer | Records aktualisiert |
| `deleted_count` | Integer | Records gelöscht |
| `unchanged_count` | Integer | Records unverändert |
| `error_count` | Integer | Anzahl Fehler |
| `errors_json` | Text | Vollständige Exceptions (JSON) |
| `executed_at` | DateTime | Zeitpunkt der Ausführung |

### Exception Details (errors_json):

```json
[
  {
    "context": "Tournament[123]",
    "error": {
      "class": "NoMethodError",
      "message": "undefined method `cc_id' for nil:NilClass",
      "backtrace": [
        "app/models/tournament.rb:395",
        "lib/tasks/scrape.rake:45",
        "..."
      ]
    }
  }
]
```

---

## 🚨 Anomalie-Erkennung

Das System erkennt **automatisch**:

### 1. Hohe Error-Rate
```ruby
if success_rate < 90%
  → ⚠️ ALARM: "High error rate"
end
```

### 2. Performance-Probleme
```ruby
if avg_duration > 300  # 5 Minuten
  → ⚠️ ALARM: "Slow performance"
end
```

### Prüfen:
```bash
rake scrape:check_health

# Exit Code 0: OK
# Exit Code 1: Anomalien gefunden (für CI/CD)
```

---

## 🔧 Integration in bestehenden Code

### Beispiel 1: Concern nutzen

```ruby
class Tournament < ApplicationRecord
  include ScrapeMonitor
  
  def scrape_tournaments
    track_scraping("tournament_scraping") do |monitor|
      tournaments.each do |t|
        begin
          if t.scrape_single_tournament_public
            monitor.record_updated(t)
          else
            monitor.record_unchanged(t)
          end
          monitor.track_method("scrape_single_tournament_public")
        rescue => e
          monitor.record_error(t, e)
        end
      end
    end
  end
end
```

### Beispiel 2: Manuelles Monitoring

```ruby
monitor = ScrapingMonitor.new("my_operation", "MyContext")

monitor.run do |m|
  # Dein Scraping-Code
  
  data.each do |item|
    begin
      record = create_from(item)
      m.record_created(record)
    rescue => e
      m.record_error(item, e)
    end
  end
  
  m.track_method("create_from")
end
```

---

## 📈 Langfristige Auswertung

### Model-Methoden

```ruby
# Stats für Operation (letzte 7 Tage)
ScrapingLog.stats_for("daily_update", since: 7.days.ago)
# => {
#      total_runs: 7,
#      avg_duration: 125.3,
#      total_created: 123,
#      total_updated: 456,
#      total_deleted: 12,
#      total_errors: 5,
#      success_rate: 98.9,
#      last_run: 2026-02-15 03:00:00
#    }

# Alle Operations-Stats
ScrapingLog.all_operations_stats(since: 30.days.ago)

# Anomalien prüfen
ScrapingLog.check_anomalies(threshold: 0.1)

# Logs mit Errors
ScrapingLog.with_errors.last_week

# Cleanup
ScrapingLog.cleanup_old_logs(keep_days: 90)
```

### CSV Export

```bash
rake scrape:export_stats[30]
# → tmp/scraping_stats_2026-02-15.csv

# Spalten:
# Operation, Executed At, Duration (s), Created, Updated, Deleted, Errors
```

---

## 🎯 Code-Coverage durch Monitoring

Das Monitoring zeigt welche Methoden **tatsächlich in Production** laufen:

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

**Vorteile gegenüber SimpleCov:**
- ✅ Zeigt **echte Produktions-Ausführungen**
- ✅ Zeigt **Performance** je Methode
- ✅ Zeigt **echte Exceptions**
- ✅ Zeigt **Dead Code** (nie aufgerufene Methoden)

---

## 🔮 Zukünftige Erweiterungen (Optional)

### Geplant:
- [ ] **Grafana/Prometheus Integration**
  - Metriken exportieren via `/metrics` Endpoint
  - Grafana-Dashboard für Visualisierung

- [ ] **Slack/Discord Webhooks**
  - Automatische Benachrichtigung bei Errors
  - Daily Summary Reports

- [ ] **Automatische Retry**
  - Bei temporären Fehlern (Timeout, 503)
  - Exponential Backoff

- [ ] **Diff-Tracking**
  - Welche Felder ändern sich?
  - Before/After Snapshots

- [ ] **HTML-Snapshot-Archivierung**
  - Bei Errors automatisch HTML speichern
  - Für Debugging & Regression-Tests

### Nice-to-have:
- [ ] **Charts im Dashboard** (Chart.js)
- [ ] **Email-Reports** (täglich/wöchentlich)
- [ ] **ClubCloud Changelog-Detection**
- [ ] **Automatische Fixture-Generierung**

---

## 📚 Dokumentation

### Erstellt:
- ✅ `docs/SCRAPING_MONITORING.md` - Vollständige Dokumentation
- ✅ `docs/SCRAPING_MONITORING_QUICKSTART.md` - 5-Minuten Quick Start
- ✅ `MONITORING_SYSTEM.md` (dieses Dokument) - Komplett-Übersicht

### Aktualisiert:
- ✅ `test/README.md` - Verweis auf Monitoring hinzugefügt

---

## 🎯 Empfohlener Workflow

### Entwicklung:
```bash
# 1. Lokal testen mit Monitoring
rake scrape:daily_update_monitored

# 2. Stats prüfen
rake scrape:stats

# 3. Dashboard öffnen
open http://localhost:3000/scraping_monitor
```

### Deployment:
```bash
# 1. Migrations ausführen
bin/rails db:migrate

# 2. Health Check
rake scrape:check_health
```

### Production:
```bash
# Cron Job (3:00 Uhr: Scraping)
0 3 * * * cd /var/www/carambus && rake scrape:daily_update_monitored

# Cron Job (6:00 Uhr: Health Check)
0 6 * * * cd /var/www/carambus && rake scrape:check_health || mail -s "Alert" admin@example.com

# Cron Job (Sonntag: Cleanup)
0 4 * * 0 cd /var/www/carambus && rake scrape:cleanup_logs[90]
```

### Wöchentliche Review:
```bash
# Jeden Montag: Stats der letzten Woche
rake scrape:stats

# CSV Export für Analyse
rake scrape:export_stats[7]
```

---

## 💡 Warum besser als Tests?

| Aspekt | Mock-Tests | Production Monitoring |
|--------|------------|----------------------|
| **Datenquelle** | Fake Fixtures | Echte ClubCloud-Daten |
| **Fehler-Erkennung** | Nur gemockte Szenarien | Alle realen Fehler |
| **Performance** | Nicht messbar | Echte Laufzeiten |
| **Maintenance** | Hoch (Fixtures veralten) | Null (selbst-aktualisierend) |
| **Coverage** | Zeigt Test-Abdeckung | Zeigt echte Nutzung |
| **Aufwand** | 10-20 Stunden | 5 Minuten Setup |
| **Nutzen** | Begrenzt | Sehr hoch |

---

## 🎉 Zusammenfassung

### Was haben wir erreicht?

✅ **Real-World Monitoring** statt Mock-Tests  
✅ **Automatic Exception Tracking**  
✅ **Performance Monitoring**  
✅ **Create/Update/Delete Stats**  
✅ **Code-Coverage** (echte Produktion!)  
✅ **Anomalie-Erkennung**  
✅ **Web-Dashboard** (Live)  
✅ **CLI Tools** (Rake Tasks)  
✅ **Null Maintenance**  

### Aufwand:
- **Setup:** 5 Minuten
- **Nutzung:** `rake scrape:daily_update_monitored`
- **Auswertung:** Dashboard öffnen

### Nutzen:
- ✅ Sofortiges Feedback bei Problemen
- ✅ Langfristige Trend-Analyse
- ✅ Automatische Alerts
- ✅ Professionelles Open-Source Monitoring

---

**🚀 Ready for Production!**

*"Monitoring beats testing. Reality beats mocks."* 🔍✨
