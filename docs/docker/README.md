# Carambus Docker Deployment

## Übersicht

Carambus verwendet ein **parameterisiertes Docker-Deployment-System**, das es ermöglicht, die Anwendung auf verschiedenen Zielumgebungen zu deployen, ohne separate Git-Branches zu benötigen.

## 🚀 Schnellstart

### Einfaches Deployment
```bash
# Auf API-Server deployen
./deploy-docker.sh carambus_newapi www-data@carambus.de /var/www/carambus_newapi

# Auf Raspberry Pi deployen  
./deploy-docker.sh carambus_raspberry pi@192.168.178.53 /home/pi/carambus

# Lokal testen
./deploy-docker.sh carambus_local localhost /tmp/carambus_test
```

Das war's! 🎉 Das Skript konfiguriert automatisch:
- Datenbank (PostgreSQL)
- Cache (Redis) 
- Web-Server (Rails + Puma)
- Nginx-Konfiguration (bei Remote-Deployments)
- SSL-Zertifikate (bei HTTPS)

## 📋 Voraussetzungen

### Auf dem Zielsystem
- Docker (Version 20.10+)
- Docker Compose (Version 2.0+)
- SSH-Zugang (bei Remote-Deployment)

### Benötigte Dateien
- Datenbank-Dump: `*.sql.gz` Datei
- Rails Credentials: `production.key`

## 🏗️ Unterstützte Deployment-Typen

| Deployment Name | Verwendung | Port | Domain |
|----------------|------------|------|--------|
| `carambus_newapi` | API-Server | 3001 | newapi.carambus.de |
| `carambus_raspberry` | Raspberry Pi Scoreboard | 3000 | localhost |
| `carambus_local` | Lokale Entwicklung | 3000 | localhost |

## 📚 Detaillierte Anleitungen

- **[Parameterisiertes Deployment](PARAMETERIZED_DEPLOYMENT.md)** - Vollständige Anleitung
- **[Raspberry Pi Setup](RASPBERRY_PI_SETUP.md)** - Scoreboard-spezifisch  
- **[API Server Setup](API_SERVER_SETUP.md)** - Produktions-Server
- **[Troubleshooting](TROUBLESHOOTING.md)** - Fehlerbehebung

## 🔧 Manuelle Konfiguration

Falls Sie spezielle Anpassungen benötigen, können Sie die automatische Konfiguration übersteuern:

```bash
# .env Datei anpassen nach dem Deployment
cd /pfad/zum/deployment
nano .env

# Container neu starten
docker compose restart
```

## 📖 Weitere Dokumentation

- **[IMPLEMENTATION_LESSONS.md](../../IMPLEMENTATION_LESSONS.md)** - Lessons Learned
- **[FRESH_SD_TEST_CHECKLIST.md](../../FRESH_SD_TEST_CHECKLIST.md)** - Test-Checkliste

## 🆘 Hilfe

Bei Problemen:
1. Prüfen Sie die **[Troubleshooting](TROUBLESHOOTING.md)**-Seite
2. Logs anschauen: `docker compose logs`
3. Container-Status: `docker compose ps`

---

**💡 Tipp**: Das System ist so konzipiert, dass Sie mit einem einzigen Befehl deployen können. Alle Komplexität wird automatisch gehandhabt.