# Internal Documentation

Dieser Ordner enthält **Work-in-Progress** Dokumentation, die während der Entwicklung entsteht.

## Zweck

- 📝 Implementierungs-Notizen während der Entwicklung
- 🐛 Bug-Fix Dokumentation
- 📊 Performance-Analysen
- 💡 Ideen und Experimente
- 🗄️ Archiv alter interner Docs

## Struktur

```
internal/
├── implementation-notes/    # Notizen während Feature-Entwicklung
├── bug-fixes/              # Bug-Fix Dokumentation
├── performance-analysis/   # Performance-Untersuchungen
└── archive/                # Alte interne Docs (nach Datum organisiert)
    └── 2026-03/
```

## Workflow

### 1. Während der Entwicklung

Erstelle Docs hier für:
- Implementierungs-Details
- Entscheidungsfindung
- Temporäre Anleitungen
- Debug-Informationen

**Beispiel:**
```bash
docs/internal/implementation-notes/NEW_FEATURE_NOTES.md
docs/internal/bug-fixes/ISSUE_1234_FIX.md
```

### 2. Nach Fertigstellung

Wenn Feature/Fix abgeschlossen:

**Option A:** Inhalt in offizielle Dokumentation integrieren
```bash
# Inhalte aus internal/ Doc in offizielle Docs übertragen
vim docs/developers/developer-guide.de.md  # Abschnitt hinzufügen
```

**Option B:** Archivieren
```bash
# Ins Archiv verschieben
mv docs/internal/implementation-notes/OLD_NOTES.md \
   docs/internal/archive/2026-03/
```

**Option C:** Löschen
```bash
# Wenn vollständig integriert und nicht mehr benötigt
rm docs/internal/implementation-notes/TEMP_NOTES.md
```

## Regeln

### ✅ ERLAUBT in internal/

- UPPERCASE Dateinamen (z.B. `NEW_FEATURE.md`)
- Unvollständige, rohe Dokumentation
- Keine Übersetzungen erforderlich
- Schnelle, ungefilterte Notizen

### ❌ NICHT in internal/

- Finale, user-facing Dokumentation (gehört nach `docs/`)
- API-Dokumentation (gehört nach `docs/reference/`)
- Anleitungen für Endbenutzer (gehört nach `docs/players/`, `docs/managers/`, etc.)

## Naming Conventions

**In internal/ sind flexibel:**
```bash
✅ OK:
FEATURE_IMPLEMENTATION_NOTES.md
bug-fix-1234.md
performance_analysis_2026_03.md
quick-notes.md
```

**Aber trotzdem organisiert:**
- Beschreibende Namen
- Datum im Namen wenn sinnvoll
- In passenden Unterordner

## Verlinkung

Interne Docs sollten:
- NICHT in `mkdocs.yml` navigation aufgenommen werden
- NICHT von offizieller Dokumentation verlinkt werden
- NUR von anderen internen Docs referenziert werden

## Cleanup

### Regelmäßig (monatlich)

```bash
# Alte Notizen archivieren
mv docs/internal/implementation-notes/OLD_* \
   docs/internal/archive/$(date +%Y-%m)/

# Vollständig integrierte Docs löschen
rm docs/internal/implementation-notes/INTEGRATED_*.md
```

### Bei Release

Vor jedem Release:
- Abgeschlossene Implementierungs-Notizen archivieren
- Inhalte in offizielle Docs integrieren
- Veraltete Docs löschen

## Siehe auch

- **Dokumentations-Regeln**: `.cursor/rules/documentation-management.md`
- **MkDocs Development**: `docs/MKDOCS_DEVELOPMENT.md`
- **Link Checking**: `bin/check-docs-links.rb`

---

**Merke:** Dieser Ordner ist für **temporäre Entwickler-Dokumentation**. Finale Docs gehören in die offizielle Struktur!
