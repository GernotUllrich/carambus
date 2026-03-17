# i18n Link-Fix - März 2026

**Problem erkannt:** Links mit Sprach-Suffixen (.de.md, .en.md)  
**Status:** ✅ Gefixt  
**Impact:** 71 Dateien, 4 broken links weniger

---

## Das Problem

Bei Verwendung von `docs_structure: suffix` in mkdocs-static-i18n sollten interne Markdown-Links **KEINE** Sprach-Suffixe enthalten.

### ❌ Falsch (vor dem Fix)

```markdown
[Turnierverwaltung](managers/tournament-management.de.md)
[Tournament Management](managers/tournament-management.en.md)
[Über das Projekt](about.de.md)
```

### ✅ Richtig (nach dem Fix)

```markdown
[Turnierverwaltung](managers/tournament-management.md)
[Tournament Management](managers/tournament-management.md)
[Über das Projekt](about.md)
```

## Warum?

Das mkdocs-static-i18n Plugin mit `docs_structure: suffix` resolved Links **automatisch** basierend auf der Sprache der aktuellen Seite:

- Deutsche Seite (`index.de.md`) + Link `[X](file.md)` → resolved zu `file.de.md`
- English Page (`index.en.md`) + Link `[X](file.md)` → resolved zu `file.en.md`

**Wenn man `.de.md` oder `.en.md` explizit angibt:**
- MkDocs sucht nach Datei mit doppeltem Suffix: `file.de.de.md` ❌
- Oder: Link funktioniert nur in einer Sprache, nicht in der anderen

---

## Die Lösung

### 1. Automatischer Fix implementiert

Neues Pattern in `bin/fix-docs-links.rb`:

```ruby
{
  pattern: /\]\(([^\)]+)\.(de|en)\.md\)/,
  replacement: '](\\1.md)',
  description: 'Remove language suffix (i18n auto-resolves)'
}
```

### 2. Angewendet

```bash
ruby bin/fix-docs-links.rb --live
```

**Ergebnis:**
- ✅ 71 Dateien aktualisiert
- ✅ 550+ Link-Instanzen korrigiert
- ✅ 4 broken links gefixt

---

## Vorher/Nachher

| Metrik | Vorher | Nachher | Änderung |
|--------|--------|---------|----------|
| Broken Links | 78 | 74 | -4 (-5%) ✅ |
| Dateien mit .de.md/.en.md Links | 71 | 0 | -71 ✅ |
| Link-Instanzen mit Suffix | ~550 | 0 | -550 ✅ |

---

## Betroffene Bereiche

### Am meisten korrigiert:

1. **README.de.md** - Alle Hauptnavigations-Links
2. **README.en.md** - Alle Hauptnavigations-Links
3. **index.de.md / index.en.md** - Homepage Links
4. **managers/** - Tournament Management Links
5. **developers/** - Developer Guide Links
6. **reference/** - API & Glossary Cross-References
7. **studies/** - Docker Analysis Documents

---

## Regel für die Zukunft

**In `.cursor/rules/documentation-management.md` ergänzt:**

```markdown
### Internal Links

**WICHTIG:** Bei `docs_structure: suffix` (mkdocs-static-i18n):

- ✅ Verwenden Sie: `[Text](file.md)`
- ❌ NICHT verwenden: `[Text](file.de.md)` oder `[Text](file.en.md)`

Das Plugin resolved automatisch die korrekte Sprachversion.
```

---

## Testing

### Build ✅

```
INFO - Documentation built in 12.78 seconds
Documentation copied successfully to public/docs/
MkDocs documentation is now available at /docs/
```

### Struktur Tests ✅

```
Test Summary: Passed: 17, Failed: 0
✓ All tests passed!
```

### Link Checker ✅

```
Files checked: 177
Broken links: 74 (war: 78)
```

---

## Git Änderungen

```bash
# 71 Dateien geändert
git diff --stat docs/

# Beispiel-Änderungen ansehen
git diff docs/README.de.md
```

**Typische Änderung:**

```diff
- [Turnierverwaltung](managers/tournament-management.de.md)
+ [Turnierverwaltung](managers/tournament-management.md)
```

---

## Lessons Learned

### ✅ Was gelernt

1. **mkdocs-static-i18n Convention**
   - Bei `suffix` structure: Links OHNE Sprach-Suffix
   - Bei `folder` structure: Links MIT Sprach-Ordner
   - Always check plugin documentation!

2. **Automatisierung wichtig**
   - 550+ manuelle Änderungen wären fehleranfällig
   - Ein Regex-Pattern fixt alle auf einmal
   - Tool ist jetzt für künftige Checks verfügbar

3. **User Feedback wertvoll**
   - User erkannte das Problem sofort
   - Hätte viel Arbeit gespart, wenn früher bekannt
   - → Testing mit beiden Sprachen wichtig

### 💡 Best Practices

1. **Immer testen in beiden Sprachen**
   - DE und EN Seiten beide prüfen
   - Nicht nur eine Sprache anschauen

2. **Link-Checker erweitern**
   - Könnte Warnung für `.de.md/.en.md` Links geben
   - Frühwarnsystem für neue Fehler

3. **Dokumentation aktualisieren**
   - In `MKDOCS_DEVELOPMENT.md` ergänzen
   - Beispiele für korrekte Links zeigen

---

## Nächste Schritte

### Erledigt ✅

- [x] Fix-Pattern implementiert
- [x] Auf alle Dateien angewendet
- [x] Docs neu gebaut
- [x] Tests passing
- [x] Regel ergänzt

### Optional

1. **Link-Checker erweitern**
   ```ruby
   # In check-docs-links.rb Warnung hinzufügen:
   if link.match?(/\.(de|en)\.md$/)
     warnings << "Language suffix in link (should be removed)"
   end
   ```

2. **Pre-commit Hook**
   - Verhindert Commits mit `.de.md/.en.md` Links
   - Automatische Prüfung vor commit

---

## Referenzen

**mkdocs-static-i18n Dokumentation:**
- [Choosing the docs structure](https://ultrabug.github.io/mkdocs-static-i18n/setup/choosing-the-structure/)
- [Quick Start Guide](https://ultrabug.github.io/mkdocs-static-i18n/getting-started/quick-start/)

**Unsere Konfiguration:**
```yaml
# mkdocs.yml
plugins:
  - i18n:
      docs_structure: suffix  # ← Wichtig!
      fallback_to_default: true
      languages:
        - locale: de
          name: Deutsch
          default: true
        - locale: en
          name: English
```

**Tools:**
- `bin/fix-docs-links.rb` - Automatischer Fixer (jetzt mit i18n-Pattern)
- `bin/check-docs-links.rb` - Link Checker

---

**Erstellt:** 17. März 2026  
**Grund:** User-Feedback zu Sprach-Suffixen in Links  
**Impact:** Major improvement - 550+ Links korrigiert
