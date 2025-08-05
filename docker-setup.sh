#!/bin/bash

# Carambus Docker Setup Script
# Führt die komplette Docker-Installation durch

set -e

echo "🚀 Carambus Docker Setup gestartet..."

# Prüfe Docker-Installation
if ! command -v docker &> /dev/null; then
    echo "❌ Docker ist nicht installiert. Bitte installiere Docker zuerst."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose ist nicht installiert. Bitte installiere Docker Compose zuerst."
    exit 1
fi

echo "✅ Docker und Docker Compose sind installiert"

# Erstelle .env Datei falls nicht vorhanden
if [ ! -f .env ]; then
    echo "📝 Erstelle .env Datei aus env.example..."
    cp env.example .env
    echo "⚠️  Bitte passe die Werte in .env an!"
    echo "   - POSTGRES_PASSWORD: Sicheres Passwort für PostgreSQL"
    echo "   - RAILS_MASTER_KEY: Dein Rails Master Key"
    echo "   - SECRET_KEY_BASE: Dein Rails Secret Key Base"
    read -p "Drücke Enter nach dem Anpassen der .env Datei..."
fi

# Erstelle SSL-Verzeichnis falls nicht vorhanden
if [ ! -d ssl ]; then
    echo "📁 Erstelle SSL-Verzeichnis..."
    mkdir -p ssl
    
    # Generiere selbst-signiertes Zertifikat für Entwicklung
    echo "🔐 Generiere selbst-signiertes SSL-Zertifikat..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/key.pem -out ssl/cert.pem \
        -subj "/C=DE/ST=NRW/L=Dortmund/O=Carambus/CN=localhost"
fi

# Erstelle Datenbank-Initialisierungsverzeichnis
if [ ! -d db/init ]; then
    echo "📁 Erstelle Datenbank-Initialisierungsverzeichnis..."
    mkdir -p db/init
fi

# Baue Docker Images
echo "🔨 Baue Docker Images..."
docker-compose build

# Starte Services
echo "🚀 Starte Docker Services..."
docker-compose up -d

# Warte auf Services
echo "⏳ Warte auf Services..."
sleep 30

# Führe Datenbank-Migrationen aus
echo "🗄️  Führe Datenbank-Migrationen aus..."
docker-compose exec web bundle exec rails db:create
docker-compose exec web bundle exec rails db:migrate

# Optional: Führe Seeds aus
read -p "Möchtest du die Datenbank mit Seeds füllen? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🌱 Führe Seeds aus..."
    docker-compose exec web bundle exec rails db:seed
fi

echo "✅ Carambus Docker Setup abgeschlossen!"
echo ""
echo "🌐 Anwendung ist verfügbar unter:"
echo "   - HTTP:  http://localhost"
echo "   - HTTPS: https://localhost"
echo ""
echo "📊 Service-Status:"
docker-compose ps
echo ""
echo "📝 Nützliche Befehle:"
echo "   - Logs anzeigen: docker-compose logs -f"
echo "   - Services stoppen: docker-compose down"
echo "   - Services neu starten: docker-compose restart"
echo "   - Shell öffnen: docker-compose exec web bash" 