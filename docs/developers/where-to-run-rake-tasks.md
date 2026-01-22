# Wo werden Rake-Tasks ausgeführt?

## Übersicht

Die Rake-Tasks für Streaming müssen **dort ausgeführt werden, wo die Datenbank ist**, da sie auf die `StreamConfiguration` Modelle zugreifen müssen.

## Architektur

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   MacBook Pro   │         │  Local Server    │         │  Raspberry Pi   │
│  (Development)  │         │ 192.168.2.210    │         │ 192.168.2.217   │
│                 │         │ Port: 3131        │         │                 │
│                 │         │                   │         │                 │
│  - Rails Code   │◄───────►│  - Rails Server  │         │  - Stream       │
│  - Git Repo     │  SSH    │  - Database       │◄───────►│  - Camera       │
│  - Editor       │         │  - Active Jobs    │  SSH    │  - FFmpeg       │
└─────────────────┘         └──────────────────┘         └─────────────────┘
```

## Wo ist die Datenbank?

Die Datenbank befindet sich auf dem **Local Server** (192.168.2.210:3131).

## Wo müssen Rake-Tasks ausgeführt werden?

### ✅ Option 1: Auf dem Local Server (Empfohlen)

Die Rake-Tasks müssen auf dem **Local Server** ausgeführt werden, da dort:
- ✅ Die Datenbank ist
- ✅ Rails läuft
- ✅ Die Models verfügbar sind
- ✅ SSH-Zugriff zum Raspberry Pi möglich ist

**SSH zum Local Server:**
```bash
ssh user@192.168.2.210
cd /path/to/carambus_bcw
rake 'streaming:camera_calibrate[3]'
```

### ⚠️ Option 2: Vom MacBook aus (wenn Remote-DB-Verbindung)

Sie können die Tasks auch vom MacBook ausführen, **wenn**:
- Die Datenbank vom MacBook aus erreichbar ist (Remote-Verbindung)
- Die `database.yml` auf den Remote-Server zeigt
- SSH-Zugriff zum Raspberry Pi vom MacBook aus möglich ist

**Vom MacBook:**
```bash
cd carambus_bcw
# Stelle sicher, dass database.yml auf 192.168.2.210 zeigt
rake 'streaming:camera_calibrate[3]'
```

## Wie prüfe ich, wo die Datenbank ist?

### 1. Prüfen Sie die `database.yml`:

```bash
cat carambus_bcw/config/database.yml
```

**Lokale Datenbank (MacBook):**
```yaml
development:
  database: carambus_bcw_development
  host: localhost
```

**Remote-Datenbank (Local Server):**
```yaml
development:
  database: carambus_bcw_development
  host: 192.168.2.210
  port: 5432
```

### 2. Prüfen Sie die aktuelle Verbindung:

```bash
cd carambus_bcw
rails runner "puts ActiveRecord::Base.connection_config"
```

Dies zeigt, zu welcher Datenbank Rails verbunden ist.

## Empfohlener Workflow

### Für Entwicklung/Testing:

**Vom MacBook aus:**
```bash
# 1. Code ändern
cd carambus_bcw
# ... Änderungen machen ...

# 2. Commit und Push
git add -A
git commit -m "Changes"
git push

# 3. Auf Local Server: Pull und Tasks ausführen
ssh user@192.168.2.210
cd /path/to/carambus_bcw
git pull
rake 'streaming:camera_calibrate[3]'
```

### Für Produktion:

**Direkt auf dem Local Server:**
```bash
ssh user@192.168.2.210
cd /path/to/carambus_bcw
rake 'streaming:camera_calibrate[3]'
```

## Welche Tasks brauchen die Datenbank?

Alle Streaming-Tasks benötigen die Datenbank:

- ✅ `rake streaming:camera_calibrate[TABLE_ID]` - Liest aus DB
- ✅ `rake streaming:camera_set[TABLE_ID,...]` - Setzt Werte (via SSH)
- ✅ `rake streaming:camera_save[TABLE_ID]` - Speichert in DB
- ✅ `rake streaming:perspective_calibrate[TABLE_ID]` - Liest/Schreibt DB
- ✅ `rake streaming:perspective_set[TABLE_ID,...]` - Schreibt in DB
- ✅ `rake streaming:deploy[TABLE_ID]` - Liest aus DB, schreibt Config
- ✅ `rake streaming:status` - Liest aus DB

## SSH-Zugriff

Die Tasks müssen auch **SSH-Zugriff zum Raspberry Pi** haben:

**Vom Local Server aus:**
```bash
# Prüfen Sie SSH-Zugriff
ssh pi@192.168.2.217 "echo 'SSH works'"
```

**Vom MacBook aus (wenn Remote-DB):**
```bash
# Prüfen Sie SSH-Zugriff
ssh pi@192.168.2.217 "echo 'SSH works'"
```

## Troubleshooting

### Problem: "Could not find table with id=3"

**Ursache:** Die Datenbank ist nicht erreichbar oder die falsche Datenbank.

**Lösung:**
1. Prüfen Sie, ob Sie auf dem richtigen System sind
2. Prüfen Sie die `database.yml`
3. Prüfen Sie die Datenbankverbindung: `rails runner "puts ActiveRecord::Base.connection_config"`

### Problem: "SSH authentication failed"

**Ursache:** SSH-Zugriff zum Raspberry Pi fehlt.

**Lösung:**
1. Prüfen Sie, ob SSH-Schlüssel konfiguriert sind
2. Prüfen Sie die `.env` Datei: `RASPI_SSH_KEYS=/path/to/key`
3. Testen Sie SSH manuell: `ssh pi@192.168.2.217`

### Problem: "Connection refused" bei Datenbank

**Ursache:** Datenbank ist nicht erreichbar vom aktuellen System.

**Lösung:**
1. Führen Sie die Tasks auf dem System aus, wo die Datenbank ist
2. Oder konfigurieren Sie eine Remote-Datenbankverbindung

## Zusammenfassung

| Task-Typ | Wo ausführen? | Warum? |
|----------|---------------|--------|
| **Streaming-Tasks** | **Local Server** (192.168.2.210) | Datenbank ist dort |
| **Code-Änderungen** | MacBook | Entwicklungsumgebung |
| **Git-Operationen** | Beide | Code-Synchronisation |

**Empfehlung:**
- Entwickeln Sie auf dem MacBook
- Führen Sie Rake-Tasks auf dem Local Server aus (wo die Datenbank ist)
- Oder konfigurieren Sie Remote-DB-Verbindung vom MacBook zum Local Server

