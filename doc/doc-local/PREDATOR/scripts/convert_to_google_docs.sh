#!/bin/bash

# Konvertierung der PREDATOR GRAND PRIX Dokumente für Google Docs
# Verwendung: ./convert_to_google_docs.sh

echo "Konvertiere PREDATOR GRAND PRIX Dokumente für Google Docs..."

# Erstelle Ausgabe-Verzeichnis
mkdir -p google_docs_export

# Prüfe ob Pandoc installiert ist
if ! command -v pandoc &> /dev/null; then
    echo "Pandoc ist nicht installiert. Installiere es mit: brew install pandoc"
    echo "Alternativ verwende die manuelle Methode in Google Docs."
    exit 1
fi

# Konvertiere alle Markdown-Dateien
echo "Konvertiere Hauptdokumentation..."
pandoc docs/predator_grand_prix_2025.de.md \
    -o google_docs_export/PREDATOR_GRAND_PRIX_2025_DE.docx \
    --toc \
    --toc-depth=3

echo "Konvertiere Zeitplan..."
pandoc docs/predator_grand_prix_timeline_2025.de.md \
    -o google_docs_export/PREDATOR_GRAND_PRIX_ZEITPLAN_2025_DE.docx \
    --toc \
    --toc-depth=2

echo "Konvertiere Funktionsbesetzung..."
pandoc docs/predator_grand_prix_roles_2025.de.md \
    -o google_docs_export/PREDATOR_GRAND_PRIX_FUNKTIONEN_2025_DE.docx \
    --toc \
    --toc-depth=2

echo "Konvertiere englische Version..."
pandoc docs/predator_grand_prix_2025.en.md \
    -o google_docs_export/PREDATOR_GRAND_PRIX_2025_EN.docx \
    --toc \
    --toc-depth=3

echo ""
echo "✅ Konvertierung abgeschlossen!"
echo "📁 Dateien befinden sich im Verzeichnis: google_docs_export/"
echo ""
echo "📋 Nächste Schritte:"
echo "1. Öffne Google Docs (docs.google.com)"
echo "2. Lade die .docx-Dateien hoch"
echo "3. Oder kopiere den Inhalt direkt aus den Markdown-Dateien"
echo ""
echo "📚 Verfügbare Dokumente:"
ls -la google_docs_export/
