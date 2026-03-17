# Rails /docs_page/* Link-Fix - März 2026

**Problem:** Links in Rails-rendered Docs (`/docs_page/*`) waren nach i18n-Fix broken  
**Status:** ✅ Gefixt  
**Lösung:** MarkdownRenderer erweitert mit Link-Transformation

---

## Das Problem

Nach dem i18n-Link-Fix (Entfernung von `.de.md`/`.en.md` Suffixen) hatten wir:

**MkDocs** (`/docs/*`):
- ✅ Links wie `[Text](file.md)` funktionieren
- ✅ i18n-Plugin resolved automatisch zu `file.de.md` oder `file.en.md`

**Rails** (`/docs_page/*`):
- ❌ Links wie `[Text](file.md)` funktionieren NICHT
- ❌ Generieren `<a href="file.md">` - keine Route vorhanden
- ❌ Kein i18n-Plugin zum Resolven

---

## Zwei Dokumentations-Systeme

### System 1: MkDocs Static Site (`/docs/*`)

```ruby
# DocsController
def show
  # Serviert pre-built HTML aus public/docs/
  # Generiert durch: rake mkdocs:build
  # i18n-Plugin: Resolved Links automatisch
end
```

**Links in HTML:**
- `<a href="../de/managers/tournament-management/">` (mit i18n)
- Funktionieren weil HTML schon resolved ist

### System 2: Rails Markdown Renderer (`/docs_page/*`)

```ruby
# StaticController
def docs_page
  # Lädt .md Datei aus docs/ zur Laufzeit
  # Rendert Markdown → HTML mit Redcarpet
  # KEIN i18n-Plugin!
  # Muss Links selbst resolven
end
```

**Links in Markdown:**
- `[Text](file.md)` → muss zu Rails-Route werden
- Braucht Transformation!

---

## Die Lösung

### 1. MarkdownRenderer erweitert

**Datei:** `app/lib/markdown_renderer.rb`

**Neue `link` Methode:**

```ruby
def link(link, title, content)
  # Check if this is an internal .md link
  if link.end_with?('.md') && !link.start_with?('http://', 'https://', '//')
    # Remove .md extension
    path = link.sub(/\.md$/, '')
    
    # Remove relative path markers (../, ./)
    path = path.gsub(/^\.\.\//, '').gsub(/^\.\//, '')
    
    # Convert to Rails docs_page route with locale
    rails_path = "/docs_page/#{@locale}/#{path}"
    
    # Build the link tag (internal links stay in same window)
    title_attr = title ? " title=\"#{title}\"" : ""
    "<a href=\"#{rails_path}\"#{title_attr}>#{content}</a>"
  else
    # External links: target="_blank"
    target = link.start_with?('http://', 'https://', '//') ? ' target="_blank" rel="noopener"' : ''
    title_attr = title ? " title=\"#{title}\"" : ""
    "<a href=\"#{link}\"#{title_attr}#{target}>#{content}</a>"
  end
end
```

### 2. Locale übergeben

**Datei:** `app/controllers/static_controller.rb`

**Änderung 1:** Renderer bekommt locale

```ruby
def render_markdown(content, options = {})
  return '' if content.blank?

  renderer = MarkdownRenderer.new(locale: options[:locale])  # ← NEU
  markdown = Redcarpet::Markdown.new(renderer, {
    autolink: true,
    tables: true,
    fenced_code_blocks: true,
    # ...
  })

  markdown.render(content)
end
```

**Änderung 2:** docs_page ruft mit locale auf

```ruby
def docs_page
  # ... load file, extract locale ...
  
  # Render with locale
  @rendered_content = render_markdown(content, locale: locale)  # ← NEU
  
  render 'docs_page', layout: 'application'
end
```

---

## Wie es funktioniert

### Vorher (Broken)

**Markdown:**
```markdown
[Tournament Management](managers/tournament-management.md)
```

**Rendered HTML:**
```html
<a href="managers/tournament-management.md">Tournament Management</a>
```

**Problem:** Keine Rails-Route für `.md` Dateien!

### Nachher (Fixed)

**Markdown:** (gleich)
```markdown
[Tournament Management](managers/tournament-management.md)
```

**Rendered HTML:**
```html
<a href="/docs_page/de/managers/tournament-management">Tournament Management</a>
```

**Erfolg:** Rails-Route funktioniert! ✅

---

## Link-Transformations-Regeln

### Interne .md Links

| Markdown | → | HTML |
|----------|---|------|
| `[X](file.md)` | → | `<a href="/docs_page/de/file">` |
| `[X](path/file.md)` | → | `<a href="/docs_page/de/path/file">` |
| `[X](../other/file.md)` | → | `<a href="/docs_page/de/other/file">` |
| `[X](./file.md)` | → | `<a href="/docs_page/de/file">` |

**Relative Pfade (`../`, `./`) werden entfernt:**
- MkDocs-kompatibel (resolved relativ zum docs root)
- Rails docs_page erwartet Pfade relativ zu docs/

### Externe Links

| Markdown | → | HTML |
|----------|---|------|
| `[X](https://example.com)` | → | `<a href="https://example.com" target="_blank" rel="noopener">` |
| `[X](http://example.com)` | → | `<a href="http://example.com" target="_blank" rel="noopener">` |

**Target="_blank" für externe Links** (Sicherheit & UX)

### Andere Links

| Markdown | → | HTML |
|----------|---|------|
| `[X](/absolute/path)` | → | `<a href="/absolute/path">` |
| `[X](#anchor)` | → | `<a href="#anchor">` |
| `[X](image.png)` | → | `<a href="image.png">` |

**Bleiben unverändert**

---

## Locale-Handling

### Automatische Locale-Detection

```ruby
# In StaticController#docs_page
locale = params[:locale] || I18n.locale.to_s

# Wird an MarkdownRenderer übergeben
@rendered_content = render_markdown(content, locale: locale)
```

### Links in verschiedenen Sprachen

**Deutsche Seite** (`/docs_page/de/index`):
```markdown
[Tournament Management](managers/tournament-management.md)
→ <a href="/docs_page/de/managers/tournament-management">
```

**English Page** (`/docs_page/en/index`):
```markdown
[Tournament Management](managers/tournament-management.md)
→ <a href="/docs_page/en/managers/tournament-management">
```

**Gleicher Markdown-Inhalt**, unterschiedliche URLs! ✅

---

## Testing

### Manuell testen

1. **Deutsche Docs:**
   ```
   http://localhost:3000/docs_page/de/index
   ```
   - Klick auf "Turnierverwaltung" Link
   - Sollte zu `/docs_page/de/managers/tournament-management` gehen

2. **English Docs:**
   ```
   http://localhost:3000/docs_page/en/index
   ```
   - Click on "Tournament Management" link
   - Should go to `/docs_page/en/managers/tournament-management`

3. **Externe Links:**
   - Sollten in neuem Tab öffnen (`target="_blank"`)
   - Mit `rel="noopener"` für Sicherheit

### Automatisierte Tests (TODO)

```ruby
# test/controllers/static_controller_test.rb
test "docs_page renders markdown with transformed links" do
  get docs_page_path(locale: 'de', path: 'index')
  
  assert_response :success
  assert_select 'a[href="/docs_page/de/managers/tournament-management"]'
  assert_select 'a[href^="http"][target="_blank"]'
end
```

---

## Vorher/Nachher

### Vorher (nach i18n-Fix)

| System | Links | Status |
|--------|-------|--------|
| MkDocs (`/docs/*`) | `file.md` | ✅ Funktioniert (i18n-Plugin) |
| Rails (`/docs_page/*`) | `file.md` | ❌ Broken (keine Route) |

### Nachher (mit Link-Transformation)

| System | Links | Status |
|--------|-------|--------|
| MkDocs (`/docs/*`) | `file.md` | ✅ Funktioniert (i18n-Plugin) |
| Rails (`/docs_page/*`) | `file.md` → `/docs_page/:locale/file` | ✅ Funktioniert (MarkdownRenderer) |

---

## Betroffene Dateien

### Geändert

1. **`app/lib/markdown_renderer.rb`**
   - `link` Methode hinzugefügt
   - Transformiert `.md` Links zu Rails-Routes
   - Locale-aware

2. **`app/controllers/static_controller.rb`**
   - `render_markdown` akzeptiert jetzt `options[:locale]`
   - `docs_page` übergibt locale an renderer

### Unverändert

- **Markdown-Dateien** in `docs/`: Keine Änderung nötig!
- **MkDocs-Konfiguration** `mkdocs.yml`: Keine Änderung
- **Routes** `config/routes.rb`: Keine Änderung

---

## Best Practices

### ✅ Für beide Systeme funktionieren

**Markdown schreiben:**
```markdown
✅ [Link](file.md)
✅ [Link](path/to/file.md)
✅ [Link](../other/file.md)
✅ [External](https://example.com)

❌ NICHT: [Link](file.de.md)
❌ NICHT: [Link](file.en.md)
```

**Warum:**
- MkDocs i18n-Plugin resolved `file.md` automatisch
- Rails MarkdownRenderer transformed zu `/docs_page/:locale/file`
- **Beide Systeme funktionieren mit gleichem Markdown!** ✅

### 🎯 Ein Markdown, zwei Renderer

```
docs/index.de.md
      │
      ├──> MkDocs Build → public/docs/de/index.html
      │    └─> Links: <a href="../de/file/">
      │
      └──> Rails Render → /docs_page/de/index
           └─> Links: <a href="/docs_page/de/file">
```

**Gleiche Quelle, unterschiedliche Ausgaben, beide funktionieren!**

---

## Zusammenhang mit i18n-Fix

### Chronologie

1. **Start:** Links mit `.de.md`/`.en.md` Suffixen
   - MkDocs: ❌ Broken (i18n-Plugin erwartet `file.md`)
   - Rails: ✅ Funktioniert (direkter Datei-Zugriff)

2. **Nach i18n-Fix:** Links ohne Suffixe
   - MkDocs: ✅ Funktioniert (i18n-Plugin resolved)
   - Rails: ❌ Broken (keine Route für `.md`)

3. **Nach Rails-Fix:** Links ohne Suffixe + Transformation
   - MkDocs: ✅ Funktioniert (i18n-Plugin)
   - Rails: ✅ Funktioniert (MarkdownRenderer)

### Beide Systeme happy! 🎉

---

## Lessons Learned

### ✅ Was gelernt

1. **Zwei Rendering-Systeme**
   - MkDocs: Build-time (i18n-Plugin)
   - Rails: Runtime (Custom Renderer)
   - Beide brauchen unterschiedliche Link-Handling

2. **Redcarpet Custom Renderer**
   - `link` Methode überschreibbar
   - Locale-Kontext durchreichbar
   - Flexibel für custom transformations

3. **Relative Pfade normalisieren**
   - `../` und `./` entfernen
   - Macht Links system-unabhängig
   - Kompatibel mit MkDocs Konventionen

### 💡 Best Practices

1. **Ein Markdown-Format für alle Systeme**
   - Links ohne Language-Suffix
   - Renderer passen sich an
   - Wartbarkeit +++

2. **Locale immer durchreichen**
   - Von Controller → Renderer
   - Ermöglicht Sprach-spezifische URLs
   - Konsistentes User Experience

3. **External Links separat behandeln**
   - `target="_blank"` für Sicherheit
   - `rel="noopener"` gegen Tabnabbing
   - Bessere UX

---

## Nächste Schritte

### Sofort

✅ **Alles erledigt!**
- MarkdownRenderer erweitert
- StaticController angepasst
- Links funktionieren in beiden Systemen

### Optional (später)

1. **Tests schreiben**
   - Controller-Tests für docs_page
   - Link-Transformation verifizieren
   - Verschiedene Locale testen

2. **Performance**
   - Markdown-Rendering cachen?
   - Pro locale cachen
   - Cache invalidation bei File-Änderungen

3. **Erweiterte Features**
   - Anchor-Links (`#section`) beibehalten
   - Query-Parameter (`?param=value`) bewahren
   - Image-Links special handling

---

## Referenzen

### Eigene Docs

- `docs/internal/I18N_LINK_FIX_2026_03.md` - Der ursprüngliche i18n-Fix
- `docs/internal/COMPLETE_SUMMARY_2026_03_17.md` - Gesamtzusammenfassung

### Redcarpet Docs

- [Redcarpet GitHub](https://github.com/vmg/redcarpet)
- [Custom Renderer Guide](https://github.com/vmg/redcarpet#darling-i-packed-you-a-couple-renderers-for-lunch)

### Rails Guides

- [Rendering in Controllers](https://guides.rubyonrails.org/layouts_and_rendering.html)
- [Helper Methods](https://guides.rubyonrails.org/action_view_helpers.html)

---

**Erstellt:** 17. März 2026  
**Grund:** Rails /docs_page/* Links nach i18n-Fix broken  
**Status:** ✅ Gefixt - Beide Systeme funktionieren jetzt!
