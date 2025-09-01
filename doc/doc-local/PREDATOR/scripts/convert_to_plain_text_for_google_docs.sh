#!/bin/bash

# Konvertierung der PREDATOR GRAND PRIX Dokumente zu reinem Text für Google Docs
# Verwendung: ./convert_to_plain_text_for_google_docs.sh

echo "Konvertiere PREDATOR GRAND PRIX Dokumente zu reinem Text für Google Docs..."

# Erstelle Ausgabe-Verzeichnis
mkdir -p plain_text_export

# Prüfe ob Pandoc installiert ist
if ! command -v pandoc &> /dev/null; then
    echo "Pandoc ist nicht installiert. Installiere es mit: brew install pandoc"
    echo "Alternativ verwende die manuelle Methode in Google Docs."
    exit 1
fi

# Konvertiere alle Markdown-Dateien zu reinem Text
echo "Konvertiere Hauptdokumentation..."
pandoc docs/predator_grand_prix_2025.de.md \
    -o plain_text_export/PREDATOR_GRAND_PRIX_2025_DE.txt \
    --to=plain \
    --wrap=none

echo "Konvertiere Zeitplan..."
pandoc docs/predator_grand_prix_timeline_2025.de.md \
    -o plain_text_export/PREDATOR_GRAND_PRIX_ZEITPLAN_2025_DE.txt \
    --to=plain \
    --wrap=none

echo "Konvertiere Funktionsbesetzung..."
pandoc docs/predator_grand_prix_roles_2025.de.md \
    -o plain_text_export/PREDATOR_GRAND_PRIX_FUNKTIONEN_2025_DE.txt \
    --to=plain \
    --wrap=none

echo "Konvertiere englische Version..."
pandoc docs/predator_grand_prix_2025.en.md \
    -o plain_text_export/PREDATOR_GRAND_PRIX_2025_EN.txt \
    --to=plain \
    --wrap=none

echo ""
echo "✅ Text-Konvertierung abgeschlossen!"
echo "📁 Text-Dateien befinden sich im Verzeichnis: plain_text_export/"
echo ""
echo "📋 Nächste Schritte für Google Docs:"
echo "1. Öffne eine .txt-Datei in deinem Texteditor"
echo "2. Kopiere den gesamten Text (Strg+A, Strg+C)"
echo "3. Füge ihn in Google Docs ein (Strg+V)"
echo "4. Formatiere manuell (Überschriften, Listen, etc.)"
echo ""
echo "📚 Verfügbare Text-Dateien:"
ls -la plain_text_export/



