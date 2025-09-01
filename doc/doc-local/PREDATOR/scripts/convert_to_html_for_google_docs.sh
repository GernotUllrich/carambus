#!/bin/bash

# Konvertierung der PREDATOR GRAND PRIX Dokumente zu HTML für Google Docs
# Verwendung: ./convert_to_html_for_google_docs.sh

echo "Konvertiere PREDATOR GRAND PRIX Dokumente zu HTML für Google Docs..."

# Erstelle Ausgabe-Verzeichnis
mkdir -p html_export

# Prüfe ob Pandoc installiert ist
if ! command -v pandoc &> /dev/null; then
    echo "Pandoc ist nicht installiert. Installiere es mit: brew install pandoc"
    echo "Alternativ verwende die manuelle Methode in Google Docs."
    exit 1
fi

# Konvertiere alle Markdown-Dateien zu HTML
echo "Konvertiere Hauptdokumentation..."
pandoc docs/predator_grand_prix_2025.de.md \
    -o html_export/PREDATOR_GRAND_PRIX_2025_DE.html \
    --standalone \
    --css=docs/templates/style.css \
    --toc \
    --toc-depth=3

echo "Konvertiere Zeitplan..."
pandoc docs/predator_grand_prix_timeline_2025.de.md \
    -o html_export/PREDATOR_GRAND_PRIX_ZEITPLAN_2025_DE.html \
    --standalone \
    --css=docs/templates/style.css \
    --toc \
    --toc-depth=2

echo "Konvertiere Funktionsbesetzung..."
pandoc docs/predator_grand_prix_roles_2025.de.md \
    -o html_export/PREDATOR_GRAND_PRIX_FUNKTIONEN_2025_DE.html \
    --standalone \
    --css=docs/templates/style.css \
    --toc \
    --toc-depth=2

echo "Konvertiere englische Version..."
pandoc docs/predator_grand_prix_2025.en.md \
    -o html_export/PREDATOR_GRAND_PRIX_2025_EN.html \
    --standalone \
    --css=docs/templates/style.css \
    --toc \
    --toc-depth=3

echo ""
echo "✅ HTML-Konvertierung abgeschlossen!"
echo "📁 HTML-Dateien befinden sich im Verzeichnis: html_export/"
echo ""
echo "📋 Nächste Schritte für Google Docs:"
echo "1. Öffne eine HTML-Datei im Browser"
echo "2. Kopiere den formatierten Text (Strg+A, Strg+C)"
echo "3. Füge ihn in Google Docs ein (Strg+V)"
echo ""
echo "📚 Verfügbare HTML-Dateien:"
ls -la html_export/



