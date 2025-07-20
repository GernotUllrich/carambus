# Carambus API

Carambus ist ein Billard-Management-System mit Ruby on Rails.

## Dokumentation

Die Dokumentation ist mit MkDocs erstellt und unterstützt Deutsch und Englisch.

### Lokale Entwicklung der Dokumentation

```bash
# Dependencies installieren
pip install -r requirements.txt

# Dokumentation lokal starten
mkdocs serve

# Dokumentation bauen
mkdocs build
```

Die Dokumentation ist dann unter `http://127.0.0.1:8000/carambus-docs/` verfügbar.

### Struktur

- `pages/de/` - Deutsche Dokumentation
- `pages/en/` - Englische Dokumentation
- `mkdocs.yml` - MkDocs Konfiguration
- `requirements.txt` - Python Dependencies

### Deployment

Die Dokumentation wird automatisch über GitHub Actions auf GitHub Pages deployed. 