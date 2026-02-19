# Archiv: Pre-STI Migration Dokumente

**Archivierungsdatum:** 19. Februar 2026  
**Grund:** STI-Migration erfolgreich abgeschlossen

---

## Inhalt dieses Archivs

Dieses Archiv enthält Planungs- und Übersichtsdokumente, die **vor der erfolgreichen STI-Migration** erstellt wurden. Die Migration ist mittlerweile abgeschlossen und diese Dokumente dienen nur noch als historische Referenz.

### Archivierte Dokumente:

1. **INTERNATIONAL_TO_STI_MIGRATION_PLAN.md**
   - Ursprünglicher Migrationsplan
   - Status: Plan wurde erfolgreich umgesetzt
   - Ersetzt durch: `UMB_STI_MIGRATION_SUCCESS.md` und `UMB_MIGRATION_TO_STI_COMPLETE.md`

2. **INTERNATIONAL_EXTENSION_COMPLETE.md** (falls vorhanden)
   - Beschreibung des alten Systems vor STI
   - Status: Beschreibt veraltete Architektur (parallel models)
   - Ersetzt durch: Neue STI-basierte Dokumentation

---

## Aktuelle Dokumentation

Die **aktuellen, gültigen** Dokumente befinden sich im Hauptverzeichnis:

### ✅ Aktuelle Referenzen:

| Dokument | Zweck |
|----------|-------|
| `UMB_PDF_PARSING.md` | Parsing-Referenz für PDFs → Games/Participations |
| `UMB_STI_MIGRATION_SUCCESS.md` | Erfolgreicher Abschluss der STI-Migration |
| `VIDEO_SYSTEM_COMPLETE.md` | Polymorphes Video-System |
| `UMB_MIGRATION_TO_STI_COMPLETE.md` | Details zur STI-Implementierung |
| `VIEWS_ANALYSIS_INTERNATIONAL_STI.md` | View-Analyse nach Migration |

---

## Was hat sich geändert?

### Altes System (vor STI):
```
international_tournaments (eigene Tabelle)
international_participations (eigene Tabelle)
international_results (eigene Tabelle)
international_videos (eigene Tabelle)
```

### Neues System (nach STI):
```
Tournament (type: 'InternationalTournament') ← STI
  ├─ Seeding (Teilnehmerliste)
  ├─ Game (Einzelspiele)
  │   └─ GameParticipation (Rankings)
  └─ Video (polymorphe Association)
```

### Vorteile:
- ✅ Einheitliches Schema für deutsche und internationale Turniere
- ✅ Weniger Komplexität (keine parallelen Models)
- ✅ Rankings funktionieren mit bestehendem Code
- ✅ Synchronisation über papertrail möglich

---

## Wichtig

**Diese archivierten Dokumente sollten NICHT mehr als Arbeitsgrundlage verwendet werden!**

Für aktuelle Informationen siehe die Hauptdokumentation im Projektverzeichnis.
