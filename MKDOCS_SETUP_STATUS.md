# MkDocs Setup Status

## Aktueller Stand

Die MkDocs-Dokumentation ist bereits konfiguriert und funktioniert lokal, aber die GitHub Pages-Deployment muss noch aktiviert werden.

## Was funktioniert bereits

### 1. Lokale MkDocs-Konfiguration
- ✅ `mkdocs.yml` ist konfiguriert
- ✅ Python-Abhängigkeiten sind in `requirements.txt` definiert
- ✅ GitHub Actions Workflow ist eingerichtet (`.github/workflows/build-docs.yml`)
- ✅ Dokumentation wird lokal gebaut mit `mkdocs build`

### 2. Rails-Integration
- ✅ `DocsController` für statische MkDocs-HTML-Dateien
- ✅ `StaticController#docs_page` für integrierte Markdown-Dokumentation
- ✅ Hilfsmethoden in `ApplicationHelper` für Dokumentationslinks
- ✅ Übersetzungen in `config/locales/de.yml` und `config/locales/en.yml`
- ✅ Breadcrumbs und Sprachumschalter wurden entfernt (wie gewünscht)

### 3. Routen
- ✅ `/docs/*path` für statische MkDocs-Dateien
- ✅ `/docs_page/:path` für integrierte Dokumentation
- ✅ `/docs_page/:locale/:path` für sprachspezifische Dokumentation

## Was noch fehlt

### 1. GitHub Pages aktivieren
Die GitHub Pages-Funktionalität muss im Repository aktiviert werden:

1. **Repository-Einstellungen öffnen**:
   - Gehe zu `https://github.com/GernotUllrich/carambus/settings/pages`

2. **Source auswählen**:
   - Wähle "GitHub Actions" als Source aus

3. **Berechtigungen prüfen**:
   - Stelle sicher, dass der GitHub Actions Workflow die nötigen Berechtigungen hat
   - Der Workflow benötigt `pages: write` und `id-token: write`

### 2. GitHub Actions Workflow
Der aktualisierte Workflow (`.github/workflows/build-docs.yml`) ist bereit und wird:

- Bei jedem Push auf den `master` Branch ausgeführt
- MkDocs-Dokumentation bauen
- Auf GitHub Pages deployen
- Die URL wird in den Workflow-Logs angezeigt

### 3. Erste Deployment
Nach der Aktivierung von GitHub Pages:

1. **Push auf master Branch**:
   ```bash
   git add .
   git commit -m "Update mkdocs workflow and remove breadcrumbs"
   git push carambus master
   ```

2. **Workflow überwachen**:
   - Gehe zu `https://github.com/GernotUllrich/carambus/actions`
   - Überwache den "Build and Deploy Documentation" Workflow

3. **Deployment bestätigen**:
   - Nach erfolgreichem Deployment wird die URL in den Workflow-Logs angezeigt
   - Standardmäßig: `https://GernotUllrich.github.io/carambus-docs`

## Aktuelle Probleme

### 1. Migration Issue
Es gibt ein Problem mit der Migration `20250224131040_migrate_settings_to_yaml.rb`:
- Die Methode `yaml_path` ist nicht definiert
- Dies verhindert das Ausführen der Tests
- **Lösung**: Migration reparieren oder überspringen

### 2. Test Setup
Die Tests können derzeit nicht ausgeführt werden:
```bash
# Fehler beim Ausführen der Tests
bin/rails test test/system/docs_page_test.rb
# ActiveRecord::EnvironmentMismatchError
```

## Nächste Schritte

### Sofort (heute)
1. ✅ Breadcrumbs entfernt
2. ✅ Sprachumschalter entfernt  
3. ✅ GitHub Actions Workflow aktualisiert
4. ✅ MkDocs-Links korrigiert

### Diese Woche
1. **GitHub Pages aktivieren** (Repository-Einstellungen)
2. **Ersten Deployment testen** (Push auf master)
3. **URL bestätigen** und in der Anwendung testen

### Nächste Woche
1. **Migration reparieren** (falls nötig)
2. **Tests reparieren** und ausführbar machen
3. **Dokumentation finalisieren**

## Technische Details

### Git-Konfiguration
- **Remote**: `carambus` (nicht `origin`)
- **Branch**: `master` (nicht `main`)
- **Push-Befehl**: `git push carambus master`

### MkDocs-URLs
- **Lokale Entwicklung**: `http://localhost:3000/docs_page/tournament`
- **GitHub Pages**: `https://GernotUllrich.github.io/carambus-docs`
- **Integrierte Anzeige**: `/docs_page/tournament` (im Carambus-Layout)

### Workflow-Trigger
- **Automatisch**: Bei jedem Push auf `master`
- **Manuell**: Über GitHub Actions UI mit "workflow_dispatch"

### Deployment-Zeit
- **Build**: ~2-3 Minuten
- **Deployment**: ~1-2 Minuten
- **Gesamt**: ~5 Minuten nach Push

## Fazit

Die MkDocs-Integration ist technisch vollständig implementiert. Es fehlt nur noch die Aktivierung von GitHub Pages im Repository. Nach der Aktivierung wird die Dokumentation automatisch bei jedem Push auf den master Branch aktualisiert.
