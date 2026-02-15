# Scraping Monitoring - Quick Start 🚀

**5 Minuten Setup für Production-Ready Monitoring**

---

## ⚡ Setup (einmalig)

```bash
# 1. Migrations ausführen
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
bin/rails db:migrate

# 2. Test-Scraping mit Monitoring
rake scrape:daily_update_monitored
```

Fertig! 🎉

---

## 📊 Monitoring nutzen

### Option 1: Web-Dashboard (empfohlen!)

```bash
# Server starten
bin/rails server

# Browser öffnen
open http://localhost:3000/scraping_monitor
```

**Features:**
- ✅ Live-Übersicht aller Scraping-Operationen
- 📈 Statistiken (7/30/90 Tage)
- ⚠️ Automatische Anomalie-Erkennung
- 🔍 Detail-View pro Operation
- 🔄 Auto-Refresh alle 30 Sekunden

### Option 2: CLI

```bash
# Statistiken anzeigen
rake scrape:stats

# Letzte Errors
rake scrape:recent_errors

# Health Check
rake scrape:check_health
```

---

## 🔄 Täglicher Betrieb

### Ersetze alten Cron Job:

```bash
# ALT (ohne Monitoring):
0 3 * * * cd /var/www/carambus && rake scrape:daily_update

# NEU (mit Monitoring):
0 3 * * * cd /var/www/carambus && rake scrape:daily_update_monitored
```

### Optional: Automatischer Health Check

```bash
# Cron: Jeden Morgen Health Check
0 6 * * * cd /var/www/carambus && rake scrape:check_health || mail -s "Scraping Alert" admin@example.com
```

---

## 📈 Was wird getrackt?

Für **jede Scraping-Operation**:

| Metrik | Bedeutung |
|--------|-----------|
| `created_count` | Neue Records erstellt |
| `updated_count` | Records aktualisiert |
| `deleted_count` | Records gelöscht |
| `unchanged_count` | Records unverändert |
| `error_count` | Fehler aufgetreten |
| `duration` | Laufzeit in Sekunden |
| `errors_json` | Vollständige Exceptions + Stack Traces |

---

## 🚨 Alerts & Anomalie-Erkennung

Das System erkennt automatisch:

### ⚠️ Hohe Error-Rate
```
Erfolgsrate < 90% → Alarm
```

### 🐌 Performance-Probleme
```
Durchschnittliche Laufzeit > 5 Min → Alarm
```

### Prüfen:
```bash
rake scrape:check_health

# Output:
# ⚠️  2 Anomalie(n) gefunden:
# 
# 1. daily_update
#    Problem: High error rate: 15%
#    Details: 10 Durchläufe, 150 Errors
```

---

## 🔍 Typische Workflows

### 1. Morgens: "Wie lief das Scraping heute Nacht?"

```bash
rake scrape:stats
```

**oder**: Dashboard öffnen: `http://localhost:3000/scraping_monitor`

### 2. Problem erkannt: "Was ist schiefgelaufen?"

```bash
# Letzte Errors ansehen
rake scrape:recent_errors

# Output zeigt:
# - Welche Operation
# - Welcher Record
# - Vollständige Exception + Stack Trace
```

### 3. Trend-Analyse: "Wird das System langsamer?"

```bash
# CSV Export für Excel/Numbers
rake scrape:export_stats[30]

# Output: tmp/scraping_stats_2026-02-15.csv
```

### 4. Aufräumen: "Alte Logs löschen"

```bash
# Logs älter als 90 Tage entfernen
rake scrape:cleanup_logs
```

---

## 💡 Vorteile

### Statt aufwändiger Tests:

❌ **Alt:**
```ruby
# test/scraping/tournament_scraper_test.rb
# 500 Zeilen Mock-Data
# 10 Stunden Arbeit
# Veraltet nach 2 Monaten
```

✅ **Neu:**
```bash
# Real-World Production Monitoring
rake scrape:daily_update_monitored

# Zeigt ECHTE Probleme
# Null Maintenance
# Immer aktuell
```

---

## 🎯 Code-Coverage durch Monitoring

Das Monitoring zeigt welche Methoden **tatsächlich** aufgerufen werden:

```
📊 ScrapeMonitor Summary: region_scraping
   Methods called: scrape_single_tournament_public, scrape_locations, scrape_clubs
```

**Besser als SimpleCov:**
- Zeigt was **wirklich läuft** (nicht was Tests abdecken)
- Zeigt **Performance-Daten**
- Zeigt **echte Exceptions**

---

## 🔧 Eigene Scraping-Methoden monitoren

### Einfache Integration:

```ruby
class MyModel < ApplicationRecord
  include ScrapeMonitor
  
  def my_scraping_method
    track_scraping("my_operation") do |monitor|
      # Dein Scraping-Code
      
      data.each do |item|
        begin
          record = create_or_update(item)
          monitor.record_created(record) if record.previously_new_record?
          monitor.record_updated(record) if record.saved_changes?
        rescue => e
          monitor.record_error(item, e)
        end
      end
    end
  end
end
```

Fertig! Jetzt erscheint `my_operation` im Dashboard.

---

## 📚 Weitere Docs

- **Vollständige Doku**: `/docs/SCRAPING_MONITORING.md`
- **Alle Rake Tasks**: `rake -T scrape`
- **Model-Methoden**: `/app/models/scraping_log.rb`

---

## 🎉 Das war's!

**3 Befehle merken:**

```bash
rake scrape:daily_update_monitored  # Scraping mit Monitoring
rake scrape:stats                   # Stats ansehen
rake scrape:check_health            # Health Check
```

**oder** einfach Dashboard öffnen:

```
http://localhost:3000/scraping_monitor
```

---

**Happy Monitoring!** 🔍✨
