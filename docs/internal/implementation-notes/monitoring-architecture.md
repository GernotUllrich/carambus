# Scraping Monitoring - Architektur 🏗️

Visuelle Übersicht des Monitoring-Systems.

---

## 📊 System-Übersicht

```
┌─────────────────────────────────────────────────────────────────┐
│                  CARAMBUS SCRAPING MONITOR                      │
└─────────────────────────────────────────────────────────────────┘

              ┌──────────────────────────────┐
              │   Scraping Operations        │
              │  (Tournament, Location, etc) │
              └──────────────┬───────────────┘
                             │
                             │ include ScrapeMonitor
                             ▼
              ┌──────────────────────────────┐
              │   ScrapingMonitor            │
              │  (Concern)                   │
              │                              │
              │  - track_scraping()          │
              │  - record_created()          │
              │  - record_updated()          │
              │  - record_deleted()          │
              │  - record_error()            │
              └──────────┬───────────────────┘
                         │
                         │ Persists to DB
                         ▼
              ┌──────────────────────────────┐
              │   scraping_logs Table        │
              │  (PostgreSQL)                │
              │                              │
              │  - operation                 │
              │  - duration                  │
              │  - created_count             │
              │  - updated_count             │
              │  - error_count               │
              │  - errors_json               │
              │  - executed_at               │
              └──────────┬───────────────────┘
                         │
                         │ Queried by
                         ▼
           ┌─────────────┴──────────────┐
           │                            │
           ▼                            ▼
  ┌────────────────┐         ┌─────────────────────┐
  │  Web Dashboard │         │   CLI Tools         │
  │                │         │  (Rake Tasks)       │
  │  /scraping_    │         │                     │
  │   monitor      │         │  - scrape:stats     │
  │                │         │  - scrape:health    │
  │  - Overview    │         │  - scrape:errors    │
  │  - Per-Op View │         │  - scrape:export    │
  │  - Auto-Refresh│         │                     │
  └────────────────┘         └─────────────────────┘
```

---

## 🔄 Monitoring-Ablauf

```
┌──────────────────────────────────────────────────────────────────┐
│                     SCRAPING WITH MONITORING                     │
└──────────────────────────────────────────────────────────────────┘

1. START SCRAPING
   ├─ rake scrape:daily_update_monitored
   │
   └─▶ ScrapingMonitor.new("daily_update")
       │
       ├─ start_time = Time.current
       ├─ stats = { created: 0, updated: 0, ... }
       └─ errors = []

2. EXECUTE SCRAPING
   │
   ├─▶ Tournament.scrape_single_tournament_public
   │   │
   │   ├─ Success? → monitor.record_updated(tournament)
   │   │             → stats[:updated] += 1
   │   │
   │   └─ Error?   → monitor.record_error(tournament, exception)
   │                 → stats[:errors] += 1
   │                 → errors << { record, error, backtrace }
   │
   ├─▶ Location.scrape_locations
   │   └─ monitor.track_method("scrape_locations")
   │
   └─▶ Club.scrape_clubs
       └─ monitor.track_method("scrape_clubs")

3. SAVE RESULTS
   │
   └─▶ ScrapingLog.create!(
         operation: "daily_update",
         duration: 125.3,
         created_count: 123,
         updated_count: 456,
         error_count: 5,
         errors_json: [...],
         executed_at: start_time
       )

4. LOG OUTPUT
   │
   ├─▶ Rails.logger.info "📊 ScrapeMonitor Summary"
   ├─▶ Rails.logger.info "   Duration: 125.3s"
   ├─▶ Rails.logger.info "   Created: 123"
   ├─▶ Rails.logger.info "   Updated: 456"
   └─▶ Rails.logger.info "   Errors: 5"
```

---

## 📈 Datenfluss: Statistiken

```
┌──────────────────────────────────────────────────────────────────┐
│                   STATISTICS DATA FLOW                           │
└──────────────────────────────────────────────────────────────────┘

scraping_logs Table
  ├─ 1000+ Log-Einträge
  │
  ├─▶ ScrapingLog.stats_for("daily_update", since: 7.days.ago)
  │   │
  │   └─▶ Aggregation:
  │       ├─ total_runs = logs.count
  │       ├─ avg_duration = logs.average(:duration)
  │       ├─ total_created = logs.sum(:created_count)
  │       ├─ total_updated = logs.sum(:updated_count)
  │       ├─ total_errors = logs.sum(:error_count)
  │       └─ success_rate = (ops - errors) / ops * 100
  │
  ├─▶ ScrapingLog.all_operations_stats
  │   │
  │   └─▶ Group by operation:
  │       ├─ "daily_update" → stats
  │       ├─ "region_scraping" → stats
  │       └─ "tournament_scraping" → stats
  │
  └─▶ ScrapingLog.check_anomalies
      │
      └─▶ Prüfungen:
          ├─ success_rate < 90% ? → ALARM
          ├─ avg_duration > 300s ? → ALARM
          └─ no recent runs ? → ALARM
```

---

## 🚨 Anomalie-Erkennung

```
┌──────────────────────────────────────────────────────────────────┐
│                    ANOMALY DETECTION                             │
└──────────────────────────────────────────────────────────────────┘

rake scrape:check_health
  │
  └─▶ ScrapingLog.check_anomalies(threshold: 0.1)
      │
      ├─▶ For each operation:
      │   │
      │   ├─ Check 1: High Error Rate?
      │   │   │
      │   │   ├─ success_rate < 90%
      │   │   └─▶ YES → anomaly << {
      │   │           operation: "daily_update",
      │   │           issue: "High error rate: 15%"
      │   │         }
      │   │
      │   └─ Check 2: Slow Performance?
      │       │
      │       ├─ avg_duration > 300s
      │       └─▶ YES → anomaly << {
      │               operation: "region_scraping",
      │               issue: "Slow: 425s"
      │             }
      │
      └─▶ Return anomalies[]
          │
          ├─ Empty? → Exit 0 (OK)
          └─ Found? → Exit 1 (ALARM)
                      → Log to Rails.logger
                      → Send to monitoring system
```

---

## 🌐 Web-Dashboard Architektur

```
┌──────────────────────────────────────────────────────────────────┐
│                      WEB DASHBOARD                               │
└──────────────────────────────────────────────────────────────────┘

HTTP GET /scraping_monitor
  │
  └─▶ ScrapingMonitorController#index
      │
      ├─▶ @time_range = params[:days] || 7
      │
      ├─▶ @operations_stats = ScrapingLog.all_operations_stats(since: 7.days.ago)
      │   └─▶ [
      │         { operation: "daily_update", total_runs: 7, ... },
      │         { operation: "region_scraping", total_runs: 42, ... }
      │       ]
      │
      ├─▶ @recent_logs = ScrapingLog.recent(50)
      │
      ├─▶ @anomalies = ScrapingLog.check_anomalies
      │
      └─▶ render :index
          │
          └─▶ HTML:
              ├─ Anomaly Alert (rot/grün)
              ├─ Stats Cards (Created/Updated/Deleted/Errors)
              ├─ Operations Table (sortierbar)
              └─ Recent Logs Table (letzte 50)

              ┌─────────────────────────────────┐
              │ 🔍 Scraping Monitor Dashboard   │
              ├─────────────────────────────────┤
              │ ✅ All Systems Operational      │
              ├─────────────────────────────────┤
              │ Created: 1234 | Updated: 5678   │
              │ Deleted: 12   | Errors: 5       │
              ├─────────────────────────────────┤
              │ Operations (Last 7 Days)        │
              │ ┌───────────────────────────┐   │
              │ │ daily_update  │ 7 runs    │   │
              │ │ Ø 125s        │ 98.9% ✓   │   │
              │ └───────────────────────────┘   │
              └─────────────────────────────────┘

              Auto-Refresh: 30s

HTTP GET /scraping_monitor/daily_update
  │
  └─▶ ScrapingMonitorController#operation
      │
      ├─▶ @operation = "daily_update"
      ├─▶ @stats = ScrapingLog.stats_for(@operation)
      ├─▶ @logs = ScrapingLog.by_operation(@operation).limit(100)
      │
      └─▶ render :operation
          │
          └─▶ HTML:
              ├─ Stats Cards (Runs, Duration, Created, ...)
              ├─ Execution History Table
              └─ Error Details (aufklappbar)
```

---

## 🔧 Code-Integration

```
┌──────────────────────────────────────────────────────────────────┐
│              HOW TO INTEGRATE INTO YOUR CODE                     │
└──────────────────────────────────────────────────────────────────┘

OPTION 1: Include Concern
──────────────────────────

class Tournament < ApplicationRecord
  include ScrapeMonitor  ← Add this
  
  def my_scraping_method
    track_scraping("tournament_scraping") do |monitor|
      # Your code
      tournament = scrape_data()
      
      if tournament.new_record?
        monitor.record_created(tournament)
      else
        monitor.record_updated(tournament)
      end
      
      monitor.track_method("scrape_data")
    end
  end
end


OPTION 2: Manual Monitoring
────────────────────────────

monitor = ScrapingMonitor.new("my_operation", "Context")

monitor.run do |m|
  begin
    records.each do |record|
      result = process(record)
      m.record_updated(record) if result
    end
  rescue => e
    m.record_error(record, e)
  end
  
  m.track_method("process")
end


CALLBACKS AVAILABLE:
────────────────────

monitor.record_created(record)     → stats[:created] += 1
monitor.record_updated(record)     → stats[:updated] += 1
monitor.record_deleted(record)     → stats[:deleted] += 1
monitor.record_unchanged(record)   → stats[:unchanged] += 1
monitor.record_error(record, err)  → stats[:errors] += 1
monitor.track_method("method_name") → method_calls << "method_name"
```

---

## 📦 Dateien-Übersicht

```
┌──────────────────────────────────────────────────────────────────┐
│                      FILES CREATED                               │
└──────────────────────────────────────────────────────────────────┘

Backend:
├── app/models/concerns/scraping_monitor.rb         [Concern]
├── app/models/scraping_log.rb                      [Model]
├── db/migrate/20260215194955_create_scraping_logs.rb
└── db/migrate/20260215195121_add_unchanged_count_to_scraping_logs.rb

Frontend:
├── app/controllers/scraping_monitor_controller.rb  [Controller]
├── app/views/scraping_monitor/index.html.erb       [Dashboard]
├── app/views/scraping_monitor/operation.html.erb   [Detail View]
└── config/routes.rb                                [+2 Routes]

CLI:
└── lib/tasks/scrape_monitored.rake                 [7 Tasks]

Documentation:
├── docs/SCRAPING_MONITORING.md                     [Vollständig]
├── docs/SCRAPING_MONITORING_QUICKSTART.md          [5 Min]
├── docs/MONITORING_ARCHITECTURE.md                 [This file]
└── MONITORING_SYSTEM.md                            [Übersicht]

Updated:
└── test/README.md                                  [+Monitoring Link]
```

---

## 🎯 Deployment-Workflow

```
┌──────────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT WORKFLOW                           │
└──────────────────────────────────────────────────────────────────┘

LOCAL DEVELOPMENT:
──────────────────
1. bin/rails db:migrate
2. rake scrape:daily_update_monitored
3. open http://localhost:3000/scraping_monitor


SCENARIO DEPLOYMENT (per carambus_bcw etc):
───────────────────────────────────────────
1. cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
2. [Make changes & commit]
3. git push

4. cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
5. git pull
6. rake "scenario:deploy[carambus_bcw]"
   └─▶ Runs migrations automatically
   └─▶ Restarts Puma


PRODUCTION CRON JOBS:
─────────────────────
# Daily Scraping (3:00 AM)
0 3 * * * cd /var/www/carambus_bcw && rake scrape:daily_update_monitored

# Health Check (6:00 AM)
0 6 * * * cd /var/www/carambus_bcw && rake scrape:check_health || \
          mail -s "Scraping Alert: carambus_bcw" admin@example.com

# Weekly Cleanup (Sunday 4:00 AM)
0 4 * * 0 cd /var/www/carambus_bcw && rake scrape:cleanup_logs[90]
```

---

## 💾 Datenbank-Schema

```sql
CREATE TABLE scraping_logs (
  id               BIGSERIAL PRIMARY KEY,
  operation        VARCHAR NOT NULL,
  context          VARCHAR,
  duration         FLOAT,
  created_count    INTEGER DEFAULT 0,
  updated_count    INTEGER DEFAULT 0,
  deleted_count    INTEGER DEFAULT 0,
  unchanged_count  INTEGER DEFAULT 0,
  error_count      INTEGER DEFAULT 0,
  errors_json      TEXT,
  executed_at      TIMESTAMP NOT NULL,
  created_at       TIMESTAMP NOT NULL,
  updated_at       TIMESTAMP NOT NULL
);

CREATE INDEX index_scraping_logs_on_operation ON scraping_logs(operation);
CREATE INDEX index_scraping_logs_on_executed_at ON scraping_logs(executed_at);
CREATE INDEX index_scraping_logs_on_operation_and_executed_at 
  ON scraping_logs(operation, executed_at);
```

---

## 🔮 Erweiterungsmöglichkeiten

```
┌──────────────────────────────────────────────────────────────────┐
│                    FUTURE EXTENSIONS                             │
└──────────────────────────────────────────────────────────────────┘

Phase 1: Alerting
─────────────────
┌─────────────┐
│ ScrapingLog │
│  .anomalies │
└──────┬──────┘
       │
       ├─▶ Slack Webhook
       │   POST https://hooks.slack.com/...
       │   { text: "⚠️ High error rate in daily_update" }
       │
       ├─▶ Discord Webhook
       │   POST https://discord.com/api/webhooks/...
       │
       └─▶ Email (ActionMailer)
           ScrapingAlertMailer.anomaly_detected(anomalies).deliver_now


Phase 2: Metrics Export
────────────────────────
GET /metrics (Prometheus format)
  │
  └─▶ # TYPE scraping_duration_seconds gauge
      scraping_duration_seconds{operation="daily_update"} 125.3
      
      # TYPE scraping_errors_total counter
      scraping_errors_total{operation="daily_update"} 5


Phase 3: Advanced Visualizations
─────────────────────────────────
┌──────────────┐
│  Chart.js    │
│  Integration │
└──────┬───────┘
       │
       ├─▶ Performance Chart (Zeit-Serie)
       ├─▶ Error Rate Chart (Trend)
       └─▶ Operations Comparison (Bar Chart)


Phase 4: Automatic Retry
─────────────────────────
monitor.run do |m|
  begin
    scrape_data()
  rescue Timeout::Error, Net::HTTPServerError => e
    m.record_error(self, e)
    
    # Automatic Retry with Exponential Backoff
    retry_with_backoff(max_retries: 3) do
      scrape_data()
    end
  end
end
```

---

**🚀 Architecture Complete!**

*"Build systems, not tests."* 🏗️✨
