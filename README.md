# Carambus API

Carambus ist ein Billard-Management-System mit Ruby on Rails.

## 🚀 Quick Start

### Docker Deployment (empfohlen)

```bash
# Auf API-Server deployen
./deploy-docker.sh carambus_newapi www-data@carambus.de /var/www/carambus_newapi

# Auf Raspberry Pi deployen  
./deploy-docker.sh carambus_raspberry pi@192.168.178.53 /home/pi/carambus

# Lokal testen
./deploy-docker.sh carambus_local localhost /tmp/carambus_test
```

**➡️ Siehe [Docker Dokumentation](docs/docker/README.md) für Details**

## 📚 Dokumentation

### Docker & Deployment
- **[Docker Setup](docs/docker/README.md)** - Hauptanleitung für Docker-Deployments
- **[Parameterisiertes Deployment](docs/docker/PARAMETERIZED_DEPLOYMENT.md)** - Vollständige Anleitung
- **[Raspberry Pi Setup](docs/docker/RASPBERRY_PI_SETUP.md)** - Scoreboard-spezifisch
- **[API Server Setup](docs/docker/API_SERVER_SETUP.md)** - Produktions-Server
- **[Troubleshooting](docs/docker/TROUBLESHOOTING.md)** - Fehlerbehebung

### Weitere Dokumentation
- **[IMPLEMENTATION_LESSONS.md](IMPLEMENTATION_LESSONS.md)** - Lessons Learned
- **[FRESH_SD_TEST_CHECKLIST.md](FRESH_SD_TEST_CHECKLIST.md)** - Test-Checkliste

### MkDocs Dokumentation

Die erweiterte Dokumentation ist mit MkDocs erstellt und unterstützt Deutsch und Englisch.

```bash
# Dependencies installieren
pip install -r requirements.txt

# Dokumentation lokal starten
mkdocs serve

# Dokumentation bauen
mkdocs build
```

Die Dokumentation ist dann unter `http://127.0.0.1:8000/carambus-docs/` verfügbar.

#### Struktur
- `pages/de/` - Deutsche Dokumentation
- `pages/en/` - Englische Dokumentation
- `mkdocs.yml` - MkDocs Konfiguration
- `requirements.txt` - Python Dependencies

Die Dokumentation wird automatisch über GitHub Actions auf GitHub Pages deployed. 