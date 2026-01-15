# Docker & API-Synchronisation - Analyse
## Version.update_from_carambus_api in Docker-Umgebung

**Version:** 1.0  
**Datum:** 14. Januar 2026  
**Kontext:** [Docker Database Complexity Analysis](DOCKER_DATABASE_COMPLEXITY_ANALYSIS.de.md)

---

## 🎯 Problem-Statement

Die Location-Server müssen **täglich und on-demand** mit dem API-Server synchronisiert werden via:

```ruby
# app/models/version.rb
Version.update_from_carambus_api(opts = {})
```

**Wie wird dies in Docker-Umgebung gehandhabt?**

---

## 📊 Aktuelle Cron-Architektur (Bare-Metal)

### Crontab-Konfiguration

**Aktuell (Host-Level):**
```bash
# /etc/cron.d/carambus oder via crontab -e

# Daily API-Sync at 2:00 AM
0 2 * * * cd /var/www/carambus_location_5101/current && \
  RAILS_ENV=production bundle exec rake scrape:daily_update >> log/cron.log 2>&1

# Weekly cleanup (Paper Trail Versions)
0 3 * * 0 cd /var/www/carambus_location_5101/current && \
  RAILS_ENV=production bundle exec rake cleanup:cleanup_paper_trail_versions >> log/cron.log 2>&1
```

**Was macht `scrape:daily_update`?**
```ruby
# lib/tasks/scrape.rake
task daily_update: :environment do
  # 1. Update Seasons
  Season.update_seasons
  
  # 2. Scrape Regions
  Region.scrape_regions
  
  # 3. Scrape Locations
  Location.scrape_locations
  
  # 4. Scrape Clubs & Players
  Club.scrape_clubs(season, from_background: true, player_details: true)
  
  # 5. Scrape Tournaments
  season.scrape_single_tournaments_public_cc
  
  # 6. Scrape Leagues
  Region::ALL_SHORTNAMES.each do |shortname|
    League.scrape_leagues_from_cc(Region.find_by_shortname(shortname), season)
  end
end
```

### API-Sync-Mechanismus

```ruby
# app/models/version.rb (Line 177-383)
def self.update_from_carambus_api(opts = {})
  # 1. Build API URL with last_version_id
  url = "#{Carambus.config.carambus_api_url}/versions/get_updates?last_version_id=#{
    Setting.key_get_value('last_version_id').to_i
  }"
  
  # 2. GET updates from API
  json_io = http_get_with_ssl_bypass(uri)
  updates = JSON.parse(json_io)
  
  # 3. Apply each update (create, update, destroy)
  updates.each do |h|
    last_version_id = h["id"]
    
    case h["event"]
    when "update", "create"
      obj = h["item_type"].constantize.find_or_initialize_by(id: h["item_id"])
      args = YAML.load(h["object"])
      obj.unprotected = true  # ← Wichtig: Bypass LocalProtector!
      obj.save!
      obj.unprotected = false
      
    when "destroy"
      obj = h["item_type"].constantize.find(h["item_id"])
      obj.unprotected = true
      obj.delete
    end
    
    # 4. Update last_version_id marker
    Setting.key_set_value("last_version_id", last_version_id)
  end
end
```

**Wichtige Aspekte:**
- ✅ Nutzt `last_version_id` als Sync-Marker (inkrementelles Update)
- ✅ Setzt `obj.unprotected = true` um LocalProtector zu umgehen
- ✅ Funktioniert mit API-Daten (ID < 50.000.000)
- ✅ Erhält lokale Daten (ID > 50.000.000) unverändert

---

## 🐳 Docker-Implementierung: Herausforderungen

### Challenge 1: Cron in Container

**Problem:**
```yaml
# docker-compose.yml (typisch)
services:
  rails:
    image: carambus:latest
    command: bundle exec puma
    # ⚠️ Wo läuft Cron?
```

**Ursache:**
- Docker-Container sollten **Single-Process** sein (Best Practice)
- Puma-Server läuft als Haupt-Prozess
- Cron ist ein **separater Daemon**
- Multi-Process in einem Container ist Anti-Pattern

#### Lösungsansatz 1A: Cron im gleichen Container (Anti-Pattern)

```dockerfile
# Dockerfile (NOT RECOMMENDED!)
FROM ruby:3.2.1-slim

# Install cron
RUN apt-get update && apt-get install -y cron

# Copy crontab
COPY config/schedule.rb /etc/cron.d/carambus
RUN chmod 0644 /etc/cron.d/carambus
RUN crontab /etc/cron.d/carambus

# Start script: Puma + Cron
COPY docker-entrypoint.sh /
CMD ["/docker-entrypoint.sh"]
```

```bash
#!/bin/bash
# docker-entrypoint.sh (NOT RECOMMENDED!)

# Start cron in background
cron &

# Start Puma in foreground
bundle exec puma
```

**❌ Probleme:**
- Anti-Pattern: Multi-Process in einem Container
- Cron-Fehler schwer zu debuggen (keine Logs in stdout)
- Container-Restart startet auch Cron neu (ungünstig bei langen Jobs)
- Health-Checks kompliziert (welcher Prozess ist tot?)

---

#### Lösungsansatz 1B: Separater Cron-Container (Best Practice)

```yaml
# docker-compose.yml
services:
  rails:
    image: carambus:latest
    command: bundle exec puma
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgresql://...
    restart: unless-stopped
  
  cron:
    image: carambus:latest  # Gleiches Image!
    command: cron -f  # Cron im Foreground
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgresql://...  # Gleiche DB!
    volumes:
      - ./config/crontab:/etc/cron.d/carambus:ro
      - ./log:/app/log  # Shared logs
    restart: unless-stopped
    depends_on:
      - rails
```

**Crontab:**
```cron
# config/crontab
# Daily API-Sync at 2:00 AM
0 2 * * * cd /app && RAILS_ENV=production bundle exec rake scrape:daily_update >> /app/log/cron.log 2>&1

# Weekly cleanup
0 3 * * 0 cd /app && RAILS_ENV=production bundle exec rake cleanup:cleanup_paper_trail_versions >> /app/log/cron.log 2>&1
```

**✅ Vorteile:**
- Best Practice: Ein Prozess pro Container
- Cron-Fehler isoliert (Rails läuft weiter)
- Einfaches Debugging (docker logs cron)
- Health-Checks einfach (nur Cron-Prozess prüfen)
- Gleiche Codebase (gleiches Image)

**⚠️ Nachteile:**
- Extra Container (~50 MB RAM)
- Crontab muss in Config-Datei (nicht dynamisch)

---

#### Lösungsansatz 1C: Kubernetes CronJob (Overkill für unseren Use-Case)

```yaml
# kubernetes/cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: carambus-daily-sync
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: sync
            image: carambus:latest
            command: ["bundle", "exec", "rake", "scrape:daily_update"]
            env:
            - name: RAILS_ENV
              value: production
          restartPolicy: OnFailure
```

**✅ Vorteile:**
- Native Kubernetes-Feature
- Job-History & Retry-Logic
- Resource-Limits pro Job

**❌ Nachteile:**
- Braucht Kubernetes (Overkill für Raspberry Pi!)
- Komplexe Setup
- Höherer Resource-Overhead

---

### Challenge 2: Interaktive Sync-Aufrufe

**Aktuell (Bare-Metal):**
```bash
# Via SSH
ssh www-data@192.168.178.107
cd /var/www/carambus_location_5101/current
RAILS_ENV=production bundle exec rails c

# In Rails Console:
Version.update_from_carambus_api
# oder mit Parametern:
Version.update_from_carambus_api(update_tournament_from_cc: 12345)
Version.update_from_carambus_api(reload_tournaments: 1)  # Region 1
```

**Mit Docker:**
```bash
# Via SSH zum Host, dann docker exec
ssh www-data@192.168.178.107
docker-compose exec rails bundle exec rails c

# In Rails Console (gleich wie vorher!):
Version.update_from_carambus_api
```

**✅ Funktioniert identisch!**
- `docker-compose exec` ist Äquivalent zu direktem Zugriff
- Rails-Console im Container hat vollen DB-Zugriff
- Interaktive Commands funktionieren perfekt

---

### Challenge 3: Cron-Job-Logs

**Problem:**
```bash
# Aktuell (Bare-Metal):
tail -f /var/www/carambus_location_5101/current/log/cron.log

# Mit Docker:
docker logs cron  # ← Zeigt cron daemon logs (nutzlos!)
# Eigentliche Rake-Logs sind in /app/log/cron.log im Container
```

**Ursache:**
- Cron redirects stdout zu `/app/log/cron.log`
- `docker logs` zeigt nur Container-stdout
- Log-Datei ist im Container isoliert

#### Lösungsansatz 3: Shared Log-Volume

```yaml
# docker-compose.yml
services:
  cron:
    image: carambus:latest
    command: cron -f
    volumes:
      - ./log:/app/log  # ← Shared mit Host!
```

**Vorteile:**
```bash
# Von Host aus (wie bisher!):
tail -f /var/www/carambus_location_5101/log/cron.log

# Oder via docker:
docker-compose exec cron tail -f /app/log/cron.log
```

**✅ Best-of-Both-Worlds:**
- Logs auf Host verfügbar (für Monitoring/Backup)
- Logs im Container verfügbar (für docker exec)

---

### Challenge 4: Cron-Job während Deployment

**Problem:**
```bash
# Deployment-Flow:
ssh www-data@server
cd /var/www/carambus_location_5101
docker-compose pull  # Neues Image
docker-compose up -d # Restart Container

# ⚠️ Was passiert mit laufendem Cron-Job?
```

**Szenarien:**

**Szenario A: Cron-Job läuft NICHT (02:00 - 02:30 Uhr)**
```bash
docker-compose up -d
# ✅ Sauberer Restart
# ✅ Neues Image läuft
# ✅ Cron scheduled sich neu
```

**Szenario B: Cron-Job läuft GERADE (z.B. bei 02:15 Uhr Deployment)**
```bash
docker-compose up -d
# ⚠️ Container wird gestoppt
# ❌ Rake-Task wird abgebrochen (SIGTERM)
# ⚠️ Database-Transaction evtl. inkonsistent
# ⚠️ last_version_id evtl. nicht aktualisiert
```

#### Lösungsansatz 4: Graceful Shutdown + Retry

**docker-compose.yml:**
```yaml
services:
  cron:
    image: carambus:latest
    stop_grace_period: 300s  # 5 Minuten für Graceful Shutdown
    healthcheck:
      test: ["CMD", "pgrep", "-f", "rake"]
      interval: 30s
      timeout: 10s
      retries: 3
```

**Deployment-Script:**
```bash
#!/bin/bash
# bin/safe-docker-deploy.sh

echo "Checking if cron job is running..."
if docker-compose exec -T cron pgrep -f 'rake scrape:daily_update' > /dev/null; then
    echo "⚠️  Cron job is running! Waiting for completion..."
    
    # Wait max 30 minutes
    timeout=1800
    elapsed=0
    while docker-compose exec -T cron pgrep -f 'rake scrape:daily_update' > /dev/null; do
        sleep 10
        elapsed=$((elapsed + 10))
        
        if [ $elapsed -ge $timeout ]; then
            echo "❌ Timeout! Forcing restart..."
            break
        fi
        
        echo "⏳ Still running... (${elapsed}s / ${timeout}s)"
    done
    
    echo "✅ Cron job finished"
fi

echo "Deploying new version..."
docker-compose pull
docker-compose up -d

echo "✅ Deployment complete"
```

**✅ Vorteile:**
- Wartet auf Cron-Job-Completion
- Timeout verhindert endloses Warten
- Graceful Shutdown für laufende Jobs

**⚠️ Nachteile:**
- Deployment kann bis zu 30 Minuten dauern (bei laufendem Job)
- Komplexerer Deployment-Script

---

## 💡 Empfohlene Docker-Architektur mit Cron

### Option A: Hybrid-Ansatz mit Host-Cron (EINFACHSTE LÖSUNG)

```
┌─────────────────────────────────────────────────────────────┐
│ RASPBERRY PI 5 (Location Server)                            │
│                                                              │
│  PostgreSQL (Host, Bare-Metal) ✅                           │
│  └─ carambus_location_5101_production                       │
│                                                              │
│  Cron (Host, Bare-Metal) ✅                                 │
│  └─ 0 2 * * * docker-compose exec -T rails \                │
│              bundle exec rake scrape:daily_update           │
│                                                              │
│  Docker-Compose:                                            │
│  └─ rails (Puma)                                            │
│  └─ redis                                                   │
│  └─ nginx                                                   │
└─────────────────────────────────────────────────────────────┘
```

**Host-Crontab:**
```bash
# /etc/cron.d/carambus_location_5101
# Daily API-Sync at 2:00 AM
0 2 * * * www-data cd /var/www/carambus_location_5101 && \
    docker-compose exec -T rails \
    bundle exec rake scrape:daily_update >> log/cron.log 2>&1

# Weekly cleanup
0 3 * * 0 www-data cd /var/www/carambus_location_5101 && \
    docker-compose exec -T rails \
    bundle exec rake cleanup:cleanup_paper_trail_versions >> log/cron.log 2>&1
```

**✅ Vorteile:**
- **Minimalste Änderung**: Cron bleibt auf Host (wie bisher)
- **Einfaches Debugging**: Cron-Logs auf Host
- **Kein Extra-Container**: Kein RAM-Overhead
- **Deployment-sicher**: Cron läuft unabhängig von Container-Restarts

**⚠️ Nachteile:**
- Cron nicht in Docker (weniger "pure" Docker-Lösung)
- Braucht `docker-compose exec` (leichter Overhead)

---

### Option B: Cron-Container (DOCKER-PURISTISCH)

```
┌─────────────────────────────────────────────────────────────┐
│ RASPBERRY PI 5 (Location Server)                            │
│                                                              │
│  PostgreSQL (Host, Bare-Metal) ✅                           │
│  └─ carambus_location_5101_production                       │
│                                                              │
│  Docker-Compose:                                            │
│  ├─ rails (Puma)                                            │
│  ├─ cron (Cron Daemon) ← NEU!                               │
│  ├─ redis                                                   │
│  └─ nginx                                                   │
└─────────────────────────────────────────────────────────────┘
```

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  rails:
    image: ghcr.io/gernotullrich/carambus:latest
    command: bundle exec puma
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgresql://...@host.docker.internal:5432/...
    volumes:
      - ./log:/app/log
      - ./config:/app/config:ro
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped

  cron:
    image: ghcr.io/gernotullrich/carambus:latest
    command: cron -f -L 15  # -L 15 = Log to stdout
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgresql://...@host.docker.internal:5432/...
    volumes:
      - ./log:/app/log          # Shared logs
      - ./config:/app/config:ro # Shared config
      - ./config/crontab:/etc/cron.d/carambus:ro
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped
    depends_on:
      - rails
    stop_grace_period: 300s  # 5 Min für laufende Jobs
```

**Dockerfile-Anpassung:**
```dockerfile
# Dockerfile
FROM ruby:3.2.1-slim

# Install cron
RUN apt-get update && apt-get install -y cron && rm -rf /var/lib/apt/lists/*

# Copy application
COPY . /app
WORKDIR /app

# Install dependencies
RUN bundle install

# Setup crontab (wird via volume überschrieben, aber als Fallback)
COPY config/crontab /etc/cron.d/carambus
RUN chmod 0644 /etc/cron.d/carambus

# Default command (wird via docker-compose überschrieben)
CMD ["bundle", "exec", "puma"]
```

**config/crontab:**
```cron
# Carambus Cron Jobs
SHELL=/bin/bash
PATH=/usr/local/bundle/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Daily API-Sync at 2:00 AM
0 2 * * * root cd /app && bundle exec rake scrape:daily_update >> /app/log/cron.log 2>&1

# Weekly cleanup
0 3 * * 0 root cd /app && bundle exec rake cleanup:cleanup_paper_trail_versions >> /app/log/cron.log 2>&1

# Empty line required
```

**✅ Vorteile:**
- "Pure" Docker-Lösung (alles in Containern)
- Cron-Logs via `docker logs cron`
- Isoliert von Rails-Container (unabhängige Restarts)

**⚠️ Nachteile:**
- Extra Container (~50 MB RAM)
- Komplexere Orchestrierung
- Deployment-Timing (laufende Jobs)

---

## 📊 Vergleich der Ansätze

| Aspekt | Host-Cron + docker exec | Cron-Container | Bare-Metal (Status Quo) |
|--------|-------------------------|----------------|--------------------------|
| **Änderungsaufwand** | ✅ Minimal (1 Tag) | ⚠️ Mittel (2-3 Tage) | ✅ Keine Änderung |
| **RAM-Overhead** | ✅ Keiner | ⚠️ +50 MB | ✅ Keiner |
| **Debugging** | ✅ Einfach (Host-Logs) | ⚠️ docker logs | ✅ Einfach (Host-Logs) |
| **Deployment-Sicherheit** | ✅ Unabhängig | ⚠️ Braucht Graceful-Shutdown | ✅ Unabhängig |
| **Docker-Purismus** | ⚠️ Hybrid | ✅ Pure Docker | ❌ Kein Docker |
| **Interaktive Sync** | ✅ docker exec | ✅ docker exec | ✅ SSH + bundle exec |
| **Cron-Config-Änderungen** | ⚠️ Host-File | ⚠️ Volume-Mount | ⚠️ Host-File |

---

## 🎯 Finale Empfehlung

### ✅ Option A: Host-Cron + docker exec

**Begründung:**
1. ✅ **Minimalste Änderung**: Nur Crontab anpassen (docker-compose exec statt bundle exec)
2. ✅ **Keine Komplexität**: Kein Extra-Container, keine Orchestrierung
3. ✅ **Deployment-sicher**: Cron läuft unabhängig von Container-Restarts
4. ✅ **Best-of-Both-Worlds**: Rails in Docker, Cron auf Host

**Implementierung:**

**1. Crontab auf Host:**
```bash
# /etc/cron.d/carambus_location_5101
0 2 * * * www-data cd /var/www/carambus_location_5101 && \
    docker-compose exec -T rails \
    bundle exec rake scrape:daily_update >> log/cron.log 2>&1
```

**2. docker-compose.yml:**
```yaml
services:
  rails:
    image: ghcr.io/gernotullrich/carambus:latest
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgresql://...@host.docker.internal:5432/...
    volumes:
      - ./log:/app/log  # Cron-Logs landen hier!
    # Kein Cron-Container nötig!
```

**3. Interaktive Sync (unverändert):**
```bash
ssh www-data@server
docker-compose exec rails bundle exec rails c
> Version.update_from_carambus_api(update_tournament_from_cc: 12345)
```

**Aufwand:** ~1 Tag (Crontab anpassen + testen)

---

### ⚠️ Optional: Option B (Cron-Container)

Nur sinnvoll wenn:
- "Pure Docker" wichtig ist (z.B. für Multi-Cloud-Deployment)
- Host-Cron nicht verfügbar (z.B. in verwalteten Kubernetes-Umgebungen)
- Mehrere Scenarios auf einem Host (Isolation wichtig)

**Aufwand:** ~2-3 Tage (Dockerfile, docker-compose, Testing)

---

## 📋 Implementierungs-Checklist

### Phase 1: Host-Cron-Ansatz

**Setup:**
- [ ] Crontab auf Host anpassen (`docker-compose exec -T`)
- [ ] Log-Volume in docker-compose.yml mounten
- [ ] Testen: Cron-Job manuell ausführen
- [ ] Testen: Logs auf Host verfügbar
- [ ] Dokumentieren: Cron-Job-Management

**Testing:**
```bash
# Manueller Test
cd /var/www/carambus_location_5101
docker-compose exec -T rails bundle exec rake scrape:daily_update

# Cron-Test (ohne zu warten)
sudo -u www-data bash -c "cd /var/www/carambus_location_5101 && \
    docker-compose exec -T rails bundle exec rake scrape:daily_update >> log/cron-test.log 2>&1"

# Log prüfen
tail -f log/cron-test.log
```

**Rollout:**
- [ ] Pilot-Server: Umstellung auf Host-Cron + docker exec
- [ ] Monitoring: 1 Woche
- [ ] Evaluation: Fehlerrate, Performance
- [ ] Scale-out: Weitere Location-Server

---

## 🔄 Migration von Bare-Metal zu Docker

### Schritt-für-Schritt

**Schritt 1: Vorbereitung (auf Host)**
```bash
# Aktuellen Cron sichern
crontab -l -u www-data > /tmp/crontab.backup

# Neuen Cron vorbereiten
cat > /tmp/crontab.new << 'EOF'
# Carambus Location 5101
0 2 * * * cd /var/www/carambus_location_5101 && docker-compose exec -T rails bundle exec rake scrape:daily_update >> log/cron.log 2>&1
0 3 * * 0 cd /var/www/carambus_location_5101 && docker-compose exec -T rails bundle exec rake cleanup:cleanup_paper_trail_versions >> log/cron.log 2>&1
EOF
```

**Schritt 2: Docker-Setup**
```bash
cd /var/www/carambus_location_5101
# docker-compose.yml bereits vorhanden (aus vorherigem Setup)
docker-compose up -d
```

**Schritt 3: Cron umstellen**
```bash
# Neuen Cron aktivieren
crontab -u www-data /tmp/crontab.new

# Verifizieren
crontab -l -u www-data
```

**Schritt 4: Testen**
```bash
# Manueller Test (als www-data)
sudo -u www-data bash -c "cd /var/www/carambus_location_5101 && \
    docker-compose exec -T rails bundle exec rake scrape:daily_update"
```

**Schritt 5: Monitoring (1 Woche)**
```bash
# Täglich prüfen
tail -50 /var/www/carambus_location_5101/log/cron.log

# Bei Fehler: Rollback zu Bare-Metal-Cron
crontab -u www-data /tmp/crontab.backup
```

---

## 🎓 Zusammenfassung

### Antwort auf Original-Frage

**"Wie sieht es aus mit der Synchronisierung (Version.update_from_carambus_api)?"**

✅ **Version.update_from_carambus_api funktioniert IDENTISCH in Docker!**

**Täglicher Cron-Job:**
- ✅ **Empfohlen**: Host-Cron mit `docker-compose exec -T rails bundle exec rake`
- ⚠️ Optional: Separater Cron-Container (mehr Komplexität, kein echter Vorteil)

**Interaktiver Sync:**
- ✅ Funktioniert perfekt via `docker-compose exec rails bundle exec rails c`
- ✅ Keine Änderung an Workflow nötig

**Deployment-Sicherheit:**
- ✅ Host-Cron läuft unabhängig von Container-Restarts
- ✅ Keine Unterbrechung bei Docker-Updates

**Aufwand:**
- ✅ Minimal: ~1 Tag für Crontab-Anpassung
- ✅ Keine Code-Änderungen nötig

### Docker ist KEIN Problem für API-Sync!

Die API-Synchronisation ist **kein Blocker** für Docker-Implementierung. Im Gegenteil:

**Vorteile mit Docker:**
- ✅ Gleiche Codebase für Rails-App (versioniert)
- ✅ Cron-Jobs nutzen gleiche Dependencies (aus Image)
- ✅ Reproduzierbare Umgebung (Cron läuft mit genau gleichen Gems)

**Empfohlener Hybrid-Ansatz bleibt optimal:**
- PostgreSQL: Host (Performance, Scenario-Kompatibilität)
- Rails-App: Docker (Versionierung, Reproduzierbarkeit)
- Cron: Host (Einfachheit, Deployment-Sicherheit)

---

**Version:** 1.0  
**Status:** ✅ API-Sync ist Docker-kompatibel  
**Empfehlung:** ✅ Host-Cron + docker exec  
**Aufwand:** ~1 Tag

