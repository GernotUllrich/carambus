# Docker & Datenbank-Komplexität - Detailanalyse
## Location-Server mit komplexem Datenbank-Management

**Version:** 1.0  
**Datum:** 14. Januar 2026  
**Kontext:** [Docker Feasibility Study](DOCKER_RASPI_FEASIBILITY_STUDY.de.md)

---

## 🎯 Fragestellung

**Ist Docker für Location-Server sinnvoll, wenn die Datenbank-Verwaltung so komplex ist?**

Die Herausforderung:
- ✅ Scenario-System mit komplexer `config.yml`
- ✅ Lokale Daten-Sicherung (ID > 50.000.000)
- ✅ API-DB-Synchronisation
- ✅ Region-Filterung
- ✅ LocalProtector-Logik
- ✅ Automatische Backup/Restore-Workflows

---

## 📊 Aktuelle Datenbank-Architektur

### Flow-Diagramm: Datenbank-Lifecycle

```
┌──────────────────────────────────────────────────────────────┐
│ STEP 1: Bootstrap (nur beim ersten Mal)                      │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  IF carambus_api_development nicht vorhanden:                │
│    ├─ SSH zu API-Server                                      │
│    ├─ Vergleiche Version.last.id:                            │
│    │   • carambus_api_development                            │
│    │   • carambus_api_production                             │
│    ├─ Wähle DB mit höherem Version.last.id                   │
│    └─ Download via pg_dump | psql (über SSH)                 │
│                                                               │
│  RESULT: carambus_api_development (lokal) = "Mother DB"      │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ STEP 2: Template-based DB Creation                           │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  createdb --template=carambus_api_development \              │
│           carambus_location_5101_development                 │
│                                                               │
│  Vorteil: SEHR schnell (~30 Sek statt 10 Min)               │
│  ⚠️ Docker-Problem: Template-DB muss im GLEICHEN Container! │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ STEP 3: Region-Filterung                                     │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  rake cleanup:remove_non_region_records                      │
│    ENV['REGION_SHORTNAME'] = 'NBV'                           │
│                                                               │
│  Löscht:                                                     │
│    • Clubs außerhalb Region: ~15.000 Datensätze             │
│    • Players außerhalb Region: ~25.000 Datensätze           │
│    • Games außerhalb Region: ~150.000 Datensätze            │
│    • Tournaments außerhalb Region: ~5.000 Datensätze        │
│                                                               │
│  Ergebnis: ~500 MB → ~90 MB (82% Reduktion)                 │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ STEP 4: Sequence-Reset (ID-Konflikt-Vermeidung)             │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  Version.sequence_reset                                      │
│    ├─ Setzt alle Sequences auf > 50.000.000                 │
│    ├─ Verhindert ID-Kollisionen mit API-DB                  │
│    └─ Markiert alle lokalen Datensätze eindeutig            │
│                                                               │
│  ALTER SEQUENCE games_id_seq RESTART WITH 50000001;          │
│  ALTER SEQUENCE players_id_seq RESTART WITH 50000001;        │
│  ...                                                          │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ STEP 5: LocalProtector aktivieren                            │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  config/carambus.yml:                                        │
│    carambus_api_url: "https://api.carambus.de"              │
│                                                               │
│  → ApplicationRecord.local_server? = true                    │
│  → LocalProtector blockt Änderungen an ID < 50.000.000      │
│                                                               │
│  Schutz:                                                     │
│    ✅ API-Daten bleiben unverändert (ID < 50M)              │
│    ✅ Lokale Daten änderbar (ID > 50M)                      │
│    ✅ Verhindert versehentliche Corruption                  │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ STEP 6: Production Deployment (mit Daten-Sicherung)         │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  IF lokale Daten in Production vorhanden (ID > 50M):        │
│    ├─ 1. Automatisches Backup via SSH                       │
│    │     • Nur ID > 50.000.000 + Extension-Tables           │
│    │     • Bereinigt: versions, orphaned records            │
│    │     • Größe: ~116 KB (statt ~1,2 GB)                   │
│    │                                                          │
│    ├─ 2. DB Drop + Recreate                                 │
│    │     • dropdb carambus_location_5101_production         │
│    │     • createdb carambus_location_5101_production       │
│    │                                                          │
│    ├─ 3. Development-Dump laden                             │
│    │     • gunzip -c dump.sql.gz | psql production_db       │
│    │     • Enthält: API-Daten + Regionen-Filter            │
│    │                                                          │
│    └─ 4. Lokale Daten wiederherstellen                      │
│          • psql production_db < local_backup.sql            │
│          • 99,95% Erfolgsrate (15.185 / 15.193 Records)     │
│                                                               │
│  ELSE (keine lokalen Daten):                                 │
│    └─ Sauberes Deployment ohne Backup                       │
└──────────────────────────────────────────────────────────────┘
```

---

## 🐳 Docker-Implementierung: Herausforderungen

### Challenge 1: Template-DB im Container

**Problem:**
```bash
# Aktuell (Bare-Metal):
createdb --template=carambus_api_development carambus_location_5101_development
# ✅ Funktioniert: Beide DBs in gleicher PostgreSQL-Instanz

# Mit Docker:
docker-compose up postgres  # Startet PostgreSQL-Container
createdb --template=carambus_api_development carambus_location_5101_development
# ❌ Funktioniert NICHT: Template-DB nicht im Container!
```

**Ursache:**
- Template-DB (`carambus_api_development`) ist auf **Host-PostgreSQL**
- Target-DB (`carambus_location_5101_development`) soll in **Container-PostgreSQL**
- PostgreSQL erlaubt nur Templates **innerhalb derselben Instanz**

#### Lösungsansatz 1: Template-DB auch in Container

```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database_dumps:/dumps:ro  # Mount für Dumps
    environment:
      - POSTGRES_MULTIPLE_DATABASES=carambus_api_development,carambus_location_5101_production
```

**Initilisierungs-Script:**
```bash
#!/bin/bash
# docker-entrypoint-initdb.d/01-init-template.sh

# 1. Restore carambus_api_development als Template
if [ ! -f /var/lib/postgresql/data/template_initialized ]; then
    echo "Initializing template database..."
    gunzip -c /dumps/carambus_api_development.sql.gz | psql -U postgres carambus_api_development
    touch /var/lib/postgresql/data/template_initialized
fi

# 2. Create Location-DB from Template
createdb -U postgres --template=carambus_api_development carambus_location_5101_development
```

**✅ Vorteile:**
- Template-basierte Creation funktioniert
- Schnell (~30 Sekunden)

**⚠️ Nachteile:**
- Template-DB muss bei jedem Container-Neustart geladen werden (außer Volume persistiert)
- Template-DB-Update komplizierter (muss Container neu bauen)
- Größerer Container-Footprint (~500 MB extra für Template-DB)

---

### Challenge 2: Region-Filterung im Container

**Problem:**
```bash
# Aktuell (Bare-Metal):
cd carambus_location_5101
rake cleanup:remove_non_region_records REGION_SHORTNAME=NBV

# Mit Docker:
docker-compose exec rails rake cleanup:remove_non_region_records REGION_SHORTNAME=NBV
# ❌ Rails-Container hat keine direkte DB-Verbindung während Build!
```

**Ursache:**
- Filterung braucht laufende Rails-App (ActiveRecord)
- Rails-Container braucht laufende PostgreSQL-Container
- Chicken-and-egg-Problem bei Initial-Setup

#### Lösungsansatz 2: Multi-Stage Init

```yaml
# docker-compose.yml
services:
  rails-init:
    build: .
    depends_on:
      postgres:
        condition: service_healthy
    command: >
      bash -c "
        bundle exec rake db:create &&
        bundle exec rake scenario:prepare_development[carambus_location_5101,development] &&
        bundle exec rake db:dump
      "
    volumes:
      - ./database_dumps:/app/database_dumps
  
  postgres:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
  
  rails:
    build: .
    depends_on:
      rails-init:
        condition: service_completed_successfully
    command: bundle exec puma
```

**✅ Vorteile:**
- Filterung läuft automatisch beim ersten Start
- Nutzt existierende Rake-Tasks

**⚠️ Nachteile:**
- Langsamer Initial-Start (10-15 Minuten beim ersten Mal)
- Komplexe Orchestrierung
- Schwierig zu debuggen

---

### Challenge 3: SSH-basierte Backup/Restore

**Problem:**
```bash
# Aktuell (Bare-Metal):
ssh -p 8910 www-data@192.168.178.107 \
  "sudo -u postgres pg_dump carambus_location_5101_production | gzip" \
  > /tmp/backup.sql.gz

# Mit Docker:
docker-compose exec postgres pg_dump carambus_location_5101_production | gzip > backup.sql.gz
# ⚠️ Funktioniert, ABER:
#   - Muss von außerhalb Container aufgerufen werden
#   - Braucht docker-compose auf dem Deployment-Rechner
#   - SSH-Key-Management komplizierter
```

**Ursache:**
- Backup/Restore via SSH bisher direkt auf Host-PostgreSQL
- Mit Docker: Container-PostgreSQL nicht direkt via SSH erreichbar
- Braucht zusätzliche Abstraktionsebene

#### Lösungsansatz 3A: SSH zu Host, dann Docker-Exec

```bash
# Von Deployment-Rechner:
ssh -p 8910 www-data@192.168.178.107 \
  "docker-compose -f /var/www/carambus_location_5101/docker-compose.yml \
   exec -T postgres pg_dump carambus_location_5101_production | gzip" \
  > backup.sql.gz
```

**✅ Vorteile:**
- Nutzt existierende SSH-Infrastruktur
- Keine Änderung an Deployment-Scripts nötig

**⚠️ Nachteile:**
- Braucht docker-compose auf Production-Server
- Komplexere Command-Chain (SSH → Docker-Exec)
- Fehler-Handling schwieriger

#### Lösungsansatz 3B: PostgreSQL-Port exposed

```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:16-alpine
    ports:
      - "5432:5432"  # ⚠️ Sicherheitsrisiko!
    environment:
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
```

```bash
# Von Deployment-Rechner (direkt via psql):
PGPASSWORD=secret pg_dump \
  -h 192.168.178.107 -p 5432 -U postgres \
  carambus_location_5101_production | gzip > backup.sql.gz
```

**✅ Vorteile:**
- Einfacher: Direkte PostgreSQL-Verbindung
- Funktioniert wie vorher (nur anderer Port)

**❌ Nachteile:**
- **Sicherheitsrisiko:** PostgreSQL-Port offen im Netzwerk!
- Braucht Firewall-Regeln
- Password-Management komplexer

---

### Challenge 4: LocalProtector & Container-Isolation

**Problem:**
```ruby
# app/models/local_protector.rb
def disallow_saving_global_records
  if id < 50_000_000 && ApplicationRecord.local_server? && !unprotected
    Rails.logger.warn("LocalProtector: Blocking save...")
    raise ActiveRecord::Rollback
  end
end

# Funktioniert auf: ApplicationRecord.local_server?
# Welches liest: Carambus.config.carambus_api_url

# config/carambus.yml (generiert aus config.yml)
carambus_api_url: "https://api.carambus.de"  # ← Muss im Container verfügbar sein!
```

**Ursache:**
- `config/carambus.yml` wird vom Scenario-System generiert
- Muss in Container gemountet werden
- Änderungen erfordern Container-Neustart

#### Lösungsansatz 4: Config-Volume-Mount

```yaml
# docker-compose.yml
services:
  rails:
    image: carambus:latest
    volumes:
      - ./config/carambus.yml:/app/config/carambus.yml:ro
      - ./config/database.yml:/app/config/database.yml:ro
      - ./config/credentials:/app/config/credentials:ro
    environment:
      - RAILS_ENV=production
```

**✅ Vorteile:**
- Config-Updates ohne Image-Rebuild
- Scenario-System kann weiterhin Configs generieren

**⚠️ Nachteile:**
- Configs müssen **vor** Container-Start existieren
- Chicken-and-egg bei Initial-Setup
- Config-Lock-Files komplizierter (.lock-Dateien müssen auch gemountet werden)

---

## 💡 Empfohlene Docker-Architektur für Location-Server

### Hybrid-Ansatz: Host-DB + Container-Rails

```
┌─────────────────────────────────────────────────────────────┐
│ RASPBERRY PI 5 (Location Server)                            │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ PostgreSQL (Bare-Metal auf Host)                   │    │
│  │                                                     │    │
│  │  ├─ carambus_api_development (Template-DB)         │    │
│  │  ├─ carambus_location_5101_development             │    │
│  │  └─ carambus_location_5101_production              │    │
│  │                                                     │    │
│  │  Vorteil:                                           │    │
│  │  ✅ Template-DB-Creation funktioniert              │    │
│  │  ✅ SSH-basierte Backups funktionieren             │    │
│  │  ✅ Keine Docker-Volume-Komplexität                │    │
│  │  ✅ Performance (kein Container-Overhead)          │    │
│  └────────────────────────────────────────────────────┘    │
│                          │                                   │
│                          │ localhost:5432                    │
│                          ↓                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Docker-Compose                                      │    │
│  │                                                     │    │
│  │  ├─ rails (Carambus App)                           │    │
│  │  │   └─ DB: host.docker.internal:5432              │    │
│  │  │                                                  │    │
│  │  ├─ redis (Cache + ActionCable)                    │    │
│  │  └─ nginx (Reverse Proxy)                          │    │
│  │                                                     │    │
│  │  Vorteil:                                           │    │
│  │  ✅ Rails-App isoliert & versioniert              │    │
│  │  ✅ Redis im Container (stateless)                 │    │
│  │  ✅ Nginx im Container (einfach konfigurierbar)    │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  rails:
    image: ghcr.io/gernotullrich/carambus:location-5101-v1.2.3
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgresql://www-data:${DB_PASSWORD}@host.docker.internal:5432/carambus_location_5101_production
      - REDIS_URL=redis://redis:6379/0
    volumes:
      - ./config:/app/config:ro  # Scenario-generierte Configs
      - ./public:/app/public     # Assets (precompiled)
      - ./log:/app/log           # Logs (persistent)
      - ./storage:/app/storage   # ActiveStorage (persistent)
    depends_on:
      - redis
    restart: unless-stopped
    extra_hosts:
      - "host.docker.internal:host-gateway"  # Für PostgreSQL-Zugriff auf Host

  redis:
    image: redis:7-alpine
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    depends_on:
      - rails
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./config/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./public:/app/public:ro  # Für statische Assets
      - ./ssl:/etc/nginx/ssl:ro  # SSL-Zertifikate
    restart: unless-stopped
```

**Deployment-Flow:**
```bash
# 1. Scenario-System bereitet DB vor (auf Host)
rake "scenario:prepare_development[carambus_location_5101,development]"
# → Erstellt: carambus_location_5101_development auf Host-PostgreSQL
# → Funktioniert: Template-DB-Creation, Region-Filterung, Sequence-Reset

# 2. Scenario-System bereitet Production vor
rake "scenario:prepare_deploy[carambus_location_5101]"
# → SSH zum Server
# → Backup lokaler Daten (Host-PostgreSQL via ssh + pg_dump)
# → Erstellt: carambus_location_5101_production auf Host-PostgreSQL
# → Restore lokaler Daten

# 3. Docker-Deployment (nur Rails-App + Redis + Nginx)
ssh -p 8910 www-data@192.168.178.107
cd /var/www/carambus_location_5101
docker-compose pull  # Holt neues Rails-Image
docker-compose up -d  # Startet Container (Rails verbindet zu Host-PostgreSQL)
```

---

## ✅ Vorteile Hybrid-Ansatz

| Aspekt | Hybrid (Host-DB + Container-Rails) | Full-Docker (DB im Container) |
|--------|-------------------------------------|-------------------------------|
| **Template-DB** | ✅ Funktioniert nativ | ❌ Komplex (Extra-Init) |
| **Region-Filterung** | ✅ Funktioniert nativ | ⚠️ Braucht Init-Container |
| **SSH-Backups** | ✅ Funktioniert nativ | ⚠️ Braucht docker-exec oder Port-Expose |
| **LocalProtector** | ✅ Configs via Volume-Mount | ✅ Configs via Volume-Mount |
| **Performance** | ✅ Keine DB-Container-Overhead | ⚠️ ~5% DB-Overhead |
| **Scenario-System** | ✅ Minimal Änderungen | ❌ Größere Anpassungen |
| **Rollback** | ⚠️ DB auf Host (manuell) | ✅ DB im Volume (einfacher) |
| **Backup-Größe** | ✅ Host-Volume (~10 GB) | ⚠️ Docker-Volume (~15 GB) |

---

## 🎯 Empfehlung: Hybrid-Ansatz

### Warum Hybrid?

1. **✅ Minimale Änderungen am Scenario-System**
   - Template-DB-Creation funktioniert weiterhin
   - Region-Filterung funktioniert weiterhin
   - SSH-basierte Backups funktionieren weiterhin
   - LocalProtector funktioniert weiterhin

2. **✅ Best-of-Both-Worlds**
   - PostgreSQL: Bare-Metal (Performance, Scenario-Kompatibilität)
   - Rails-App: Docker (Versionierung, Rollback, Isolation)
   - Redis: Docker (stateless, einfach)
   - Nginx: Docker (einfach konfigurierbar)

3. **✅ Schrittweise Migration möglich**
   - Phase 1: Nur Rails-App containerisieren
   - Phase 2: Testen & Evaluieren (3-6 Monate)
   - Phase 3 (optional): PostgreSQL später containerisieren (wenn Scenario-System angepasst)

4. **✅ Geringerer Entwicklungsaufwand**
   - Keine Scenario-System-Anpassungen: ~5 Tage gespart
   - Keine PostgreSQL-Container-Setup: ~3 Tage gespart
   - Keine SSH-Backup-Rewrite: ~2 Tage gespart
   - **Gesamt: ~10 Tage Einsparung** (5-10 Tage statt 15-20 Tage)

---

## 📋 Implementierungsplan

### Phase 1: Rails-Container (3-5 Tage)

**Aufgaben:**
1. Dockerfile.production für Rails erstellen
2. docker-compose.yml mit host.docker.internal konfigurieren
3. Config-Volume-Mounts einrichten
4. Testing auf Pilot-Server

**Deliverables:**
- `Dockerfile.production`
- `docker-compose.yml` (Rails + Redis + Nginx)
- Dokumentation: Deployment-Flow
- Getestetes Setup auf einem Location-Server

---

### Phase 2: CI/CD-Pipeline (2-3 Tage)

**Aufgaben:**
1. GitHub Actions für Image-Build
2. GitHub Container Registry (GHCR) Setup
3. Automatische Image-Tags (Git-SHA, Semantic Versioning)
4. Deployment-Script-Anpassung (docker-compose pull)

**Deliverables:**
- `.github/workflows/docker-build.yml`
- Automatische Image-Publizierung
- Versionierte Images in GHCR

---

### Phase 3: Evaluation (3-6 Monate)

**Metriken:**
- Uptime-Vergleich (Hybrid vs. Bare-Metal)
- Deployment-Zeit-Vergleich
- Rollback-Anzahl & Geschwindigkeit
- Problem-Anzahl & Resolution-Zeit

**Entscheidung:**
- ✅ Bei Erfolg: Weitere Location-Server migrieren
- ⚠️ Bei gemischten Ergebnissen: Optimieren & Weiter testen
- ❌ Bei Misserfolg: Rollback zu Bare-Metal

---

## 🔮 Optional: Full-Docker (Zukunft)

Wenn Scenario-System später angepasst wird, kann PostgreSQL auch containerisiert werden:

### Erforderliche Anpassungen

**1. Template-DB-Handling:**
```ruby
# lib/tasks/scenarios.rake
def create_database_from_template(scenario_name, environment)
  if docker_deployment?
    # Docker-spezifisch: Init-Container mit Template-DB
    docker_exec("rails", "rake scenario:init_template_db[#{scenario_name}]")
  else
    # Bare-Metal: Wie bisher
    system("createdb --template=carambus_api_development #{database_name}")
  end
end
```

**2. SSH-Backup-Handling:**
```ruby
def backup_production_database(scenario_name)
  if docker_deployment?
    # Docker-spezifisch: docker-compose exec
    ssh_exec("docker-compose -f #{deploy_path}/docker-compose.yml exec -T postgres pg_dump...")
  else
    # Bare-Metal: Wie bisher
    ssh_exec("sudo -u postgres pg_dump...")
  end
end
```

**3. Region-Filterung:**
```ruby
def filter_region_data(scenario_name, region)
  if docker_deployment?
    # Docker-spezifisch: Init-Container
    docker_exec("rails-init", "rake cleanup:remove_non_region_records REGION=#{region}")
  else
    # Bare-Metal: Wie bisher
    system("cd #{rails_root} && rake cleanup:remove_non_region_records REGION=#{region}")
  end
end
```

**Aufwand:** ~10-15 Tage zusätzlich

**ROI:** Nur sinnvoll wenn:
- Viele Location-Server (>10)
- Häufige DB-Schema-Updates
- PostgreSQL-Version-Management wichtig

---

## 📊 Kosten-Vergleich

| Ansatz | Entwicklung | Komplexität | Scenario-Änderungen | Empfehlung |
|--------|-------------|-------------|---------------------|------------|
| **Hybrid (Host-DB + Container-Rails)** | 5-10 Tage | Mittel | Minimal | ✅ **Empfohlen** |
| **Full-Docker (DB im Container)** | 15-25 Tage | Hoch | Umfangreich | ⚠️ Optional (Zukunft) |
| **Bare-Metal (Status Quo)** | 0 Tage | Niedrig | Keine | ✅ Akzeptabel |

---

## 🎯 Finale Empfehlung

### ✅ HYBRID-ANSATZ für Location-Server

**Begründung:**
1. ✅ **Scenario-System bleibt unverändert** - Template-DB, Filterung, Backups funktionieren weiterhin
2. ✅ **Rails-App profitiert von Docker** - Versionierung, Rollback, Isolation
3. ✅ **Minimaler Entwicklungsaufwand** - 5-10 Tage statt 15-25 Tage
4. ✅ **Schrittweise Migration** - PostgreSQL kann später containerisiert werden (optional)
5. ✅ **Best-of-Both-Worlds** - Performance (Host-DB) + Reproduzierbarkeit (Container-Rails)

**Nicht empfohlen:**
- ❌ Full-Docker sofort (zu hoher Aufwand für Scenario-Anpassungen)
- ⚠️ Bare-Metal beibehalten (verpasst Docker-Vorteile für Rails-App)

**Nächste Schritte:**
1. Hybrid-Ansatz implementieren (Phase 1-2: 5-8 Tage)
2. Pilot-Test auf einem Location-Server (1-2 Wochen)
3. Evaluation nach 3-6 Monaten
4. Entscheidung: Scale-out oder optional Full-Docker-Migration

---

**Version:** 1.0  
**Status:** ✅ Bereit für Implementierung  
**Geschätzter Aufwand:** 5-10 Tage (Hybrid-Ansatz)  
**ROI:** Positiv nach 2-3 Jahren

