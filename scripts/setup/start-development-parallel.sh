#!/bin/bash

# Carambus Development Parallel Systems Starter
# Startet alle drei Systeme parallel: API-Server, Local-Server, Web-Client

set -e

echo "🚀 Starte Carambus Development Parallel Systems..."
echo ""

# Prüfe ob Docker läuft
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker läuft nicht. Bitte starten Sie Docker zuerst."
    exit 1
fi

# Prüfe ob die benötigten Dateien existieren
if [ ! -f "docker-compose.development.parallel.yml" ]; then
    echo "❌ docker-compose.development.parallel.yml nicht gefunden."
    exit 1
fi

if [ ! -f "env.development.parallel" ]; then
    echo "❌ env.development.parallel nicht gefunden."
    exit 1
fi

echo "📋 Starte alle drei Systeme parallel..."
echo "   - API-Server: http://localhost:3001"
echo "   - Local-Server: http://localhost:3000"
echo "   - Web-Client: http://localhost:3002"
echo ""

echo "🗄️  Datenbank-Ports:"
echo "   - API-Server: 5433"
echo "   - Local-Server: 5432"
echo "   - Web-Client: 5434"
echo ""

echo "🔴 Redis-Ports:"
echo "   - API-Server: 6380"
echo "   - Local-Server: 6379"
echo "   - Web-Client: 6381"
echo ""

# Starte alle Systeme
docker-compose -f docker-compose.development.parallel.yml --env-file env.development.parallel up -d

echo ""
echo "✅ Alle Systeme gestartet!"
echo ""
echo "📊 Status anzeigen:"
echo "   docker-compose -f docker-compose.development.parallel.yml ps"
echo ""
echo "📝 Logs anzeigen:"
echo "   docker-compose -f docker-compose.development.parallel.yml logs -f"
echo ""
echo "🛑 Alle Systeme stoppen:"
echo "   docker-compose -f docker-compose.development.parallel.yml down"
echo ""
echo "🧹 Alle Systeme und Daten löschen:"
echo "   docker-compose -f docker-compose.development.parallel.yml down -v" 