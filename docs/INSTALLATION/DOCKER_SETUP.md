# 🐳 Docker Setup für Carambus

## 📋 Übersicht

Carambus verwendet ein **parameterisiertes Docker-Deployment-System**, das es ermöglicht, die Anwendung auf verschiedenen Zielumgebungen zu deployen, ohne separate Git-Branches zu benötigen.

## 🚀 Schnellstart

### Einfaches Deployment
```bash
# Auf API-Server deployen
./deploy-docker.sh carambus_newapi www-data@carambus.de /var/www/carambus_newapi

# Auf Raspberry Pi deployen  
./deploy-docker.sh carambus_raspberry www-data@192.168.178.53:8910 /var/www/carambus

# Lokal testen
./deploy-docker.sh carambus_local localhost /tmp/carambus_test
```

Das war's! 🎉 Das Skript konfiguriert automatisch:
- Datenbank (PostgreSQL)
- Cache (Redis) 
- Web-Server (Rails + Puma)
- Nginx-Konfiguration (bei Remote-Deployments)
- SSL-Zertifikate (bei HTTPS)

## 🏗️ Docker-Architektur

### Korrekte Struktur (wie besprochen)

```
Production-Modi (2 verschiedene Systeme):
├── API-Server: Ist der zentrale API-Server (newapi.carambus.de)
└── Local-Server: Hat eine Carambus API URL, die auf den API-Server verweist

Development-Modus (übergeordnet):
├── Beide Production-Modi können im Development-Modus getestet werden
├── Auf dem Mac Mini parallel lauffähig
└── Für Inter-System-Kommunikation (z.B. Region-Filter-Tests)
```

### Port-Zuordnung (Development - parallele Systeme)
| System | Web | PostgreSQL | Redis |
|--------|-----|------------|-------|
| API-Server | 3001 | 5433 | 6380 |
| Local-Server | 3000 | 5432 | 6379 |
| Web-Client | 3002 | 5434 | 6381 |

### Port-Zuordnung (Production - Standard-Ports)
| System | Web | PostgreSQL | Redis |
|--------|-----|------------|-------|
| Alle Systeme | 3000 | 5432 | 6379 |

## 📋 Voraussetzungen

### Auf dem Zielsystem
- Docker (Version 20.10+)
- Docker Compose (Version 2.0+)
- SSH-Zugang (bei Remote-Deployment)

### Benötigte Dateien
- Datenbank-Dump: `*.sql.gz` Datei
- Rails Credentials: `production.key`

## 🏗️ Unterstützte Deployment-Typen

| Deployment Name | Verwendung | Port | Domain | Merkmale |
|----------------|------------|------|--------|----------|
| `carambus_newapi` | API-Server | 3001 | newapi.carambus.de | Ist der zentrale API-Server |
| `carambus_raspberry` | Raspberry Pi Scoreboard | 3000 | localhost | Hat Carambus API URL, die auf API-Server verweist |
| `carambus_local` | Lokale Entwicklung | 3000 | localhost | Hat Carambus API URL, die auf API-Server verweist |

## 🚀 Development-Modus (Mac Mini)

### Einzelne Systeme

#### API-Server (Development)
```bash
# Mit spezifischer Umgebungsdatei
docker-compose -f docker-compose.development.api-server.yml --env-file env.development.api-server up

# Oder mit Standard-Umgebungsdatei
docker-compose -f docker-compose.development.api-server.yml up
```

#### Local-Server (Development)
```bash
# Mit spezifischer Umgebungsdatei
docker-compose -f docker-compose.development.local-server.yml --env-file env.development.local-server up

# Oder mit Standard-Umgebungsdatei
docker-compose -f docker-compose.development.local-server.yml up
```

#### Web-Client (Development)
```bash
# Mit spezifischer Umgebungsdatei
docker-compose -f docker-compose.development.web-client.yml --env-file env.development.web-client up

# Oder mit Standard-Umgebungsdatei
docker-compose -f docker-compose.development.web-client.yml up
```

### Parallele Systeme (Development-Modus)

Für die Entwicklung mit mehreren Systemen gleichzeitig auf dem Mac Mini (z.B. für Region-Filter-Tests):

```bash
# Alle drei Systeme parallel starten
docker-compose -f docker-compose.development.parallel.yml --env-file env.development.parallel up

# Oder mit Standard-Umgebungsdatei
docker-compose -f docker-compose.development.parallel.yml up
```

**Vorteile der parallelen Entwicklung:**
- Alle Systeme laufen gleichzeitig auf dem Mac Mini
- Verschiedene Ports für jede Datenbank/Redis-Instanz
- **Inter-System-Kommunikation möglich** (Local-Server ↔ API-Server über Carambus API URL)
- Test von Region-Filtern und Synchronisierung
- **Beide Production-Modi im Development-Modus testbar**

## 🚀 Production-Modus

### Einzelne Systeme

#### API-Server (Production)
```bash
docker-compose -f docker-compose.production.api-server.yml --env-file env.production.api-server up
```

#### Local-Server (Production)
```bash
docker-compose -f docker-compose.production.local-server.yml --env-file env.production.local-server up
```

#### Web-Client (Production)
```bash
docker-compose -f docker-compose.production.web-client.yml --env-file env.production.web-client up
```

### Generische Production-Konfiguration

```bash
docker-compose -f docker-compose.production.yml --env-file env.production up
```

## ⚙️ Umgebungsdateien

### Development
- `env.development.api-server` - API-Server im Development-Modus
- `env.development.local-server` - Local-Server im Development-Modus
- `env.development.web-client` - Web-Client im Development-Modus
- `env.development.parallel` - Alle Systeme parallel im Development-Modus

### Production
- `env.production.api-server` - API-Server im Production-Modus
- `env.production.local-server` - Local-Server im Production-Modus
- `env.production.web-client` - Web-Client im Production-Modus
- `env.production` - Generische Production-Konfiguration

## 🔧 Manuelle Konfiguration

Falls Sie spezielle Anpassungen benötigen, können Sie die automatische Konfiguration übersteuern:

```bash
# .env Datei anpassen nach dem Deployment
cd /pfad/zum/deployment
nano .env

# Container neu starten
docker compose restart
```

### Carambus API URL konfigurieren
```bash
# Für Local-Server: API-URL auf API-Server setzen
echo "CARAMBUS_API_URL=https://newapi.carambus.de" >> .env

# Oder in der Rails-Konfiguration
echo "config.carambus_api_url = 'https://newapi.carambus.de'" >> config/environments/production.rb
```

## 🚨 Troubleshooting

### Container startet nicht
```bash
# Docker-Status prüfen
sudo systemctl status docker

# Logs anschauen
docker compose logs
```

### Ports sind belegt
```bash
# Andere Ports in der entsprechenden docker-compose.yml verwenden
nano docker-compose.development.api-server.yml
# Ändere z.B. "3001:3000" zu "3003:3000"
```

### Speicherplatz voll
```bash
# Docker-Images aufräumen
docker system prune -a

# Logs aufräumen
docker-compose logs --tail=100
```

### Performance-Probleme
```bash
# Container-Ressourcen überwachen
docker stats

# System-Ressourcen prüfen
htop
```

## 📊 Monitoring

### Container-Status prüfen
```bash
docker compose ps
```

### Logs anzeigen
```bash
# Alle Logs
docker compose logs -f

# Nur Rails-Logs
docker compose logs -f web

# Nur Datenbank-Logs
docker compose logs -f postgres
```

### Ressourcen überwachen
```bash
# Container-Ressourcen
docker stats

# System-Ressourcen
htop
```

## 🔄 Updates

### Carambus aktualisieren
```bash
# Repository aktualisieren
git pull

# Container neu bauen und starten
docker-compose down
docker-compose up -d --build
```

### Docker aktualisieren
```bash
# Docker aktualisieren
sudo apt update
sudo apt upgrade docker-ce docker-ce-cli containerd.io

# Docker Compose aktualisieren
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

## 📖 Weitere Dokumentation

- **[Docker Structure](../DEVELOPMENT/DOCKER_STRUCTURE.md)** - Detaillierte Docker-Struktur
- **[Raspberry Pi Setup](RASPBERRY_PI_SETUP.md)** - Scoreboard-spezifisch  
- **[API Server Setup](API_SERVER_SETUP.md)** - Produktions-Server
- **[Troubleshooting](../MAINTENANCE/TROUBLESHOOTING.md)** - Fehlerbehebung

## 🆘 Hilfe

Bei Problemen:
1. Prüfen Sie die **[Troubleshooting](../MAINTENANCE/TROUBLESHOOTING.md)**-Seite
2. Logs anschauen: `docker compose logs`
3. Container-Status: `docker compose ps`

---

**💡 Tipp**: Das System ist so konzipiert, dass Sie mit einem einzigen Befehl deployen können. Alle Komplexität wird automatisch gehandhabt.

**🎯 Für parallele Development-Systeme**: Verwenden Sie `./start-development-parallel.sh` für alle drei Systeme gleichzeitig auf dem Mac Mini!

**🏗️ Architektur**: 2 Production-Modi - API-Server (zentral) und Local-Server (mit Carambus API URL), beide im Development-Modus testbar! 