# Rails Routing Fix für /docs_page/* - März 2026

**Problem:** Links zu Pfaden mit Slashes (z.B. `/docs_page/de/decision-makers/index`) funktionierten nicht  
**Status:** ✅ Gefixt  
**Lösung:** `:path` → `*path` (glob parameter)

---

## Das Problem

Nach Phase 4 (Link-Transformation) wurden Links korrekt generiert:

```html
<a href="/docs_page/de/decision-makers/index">Entscheider-Übersicht</a>
```

**Aber:** Beim Klicken → 404 Error!

### Root Cause

**Rails Routing:**
```ruby
# VORHER (BROKEN):
get "docs_page/:locale/:path" => :docs_page

# Beispiel: /docs_page/de/decision-makers/index
# Rails matched: :locale = "de", :path = "decision-makers"
# Problem: :path stoppt beim ersten Slash! ❌
```

**`:path` Parameter:**
- Matched nur bis zum ersten `/`
- `/docs_page/de/decision-makers/index` → `:path` = `"decision-makers"` (nicht `"decision-makers/index"`)
- Datei `docs/decision-makers.de.md` existiert nicht → 404

---

## Die Lösung

**Glob Parameter `*path`:**

```ruby
# NACHHER (FIXED):
get "docs_page/:locale/*path" => :docs_page
get "docs_page/*path" => :docs_page

# Beispiel: /docs_page/de/decision-makers/index
# Rails matched: :locale = "de", :path = "decision-makers/index" ✅
# Datei: docs/decision-makers/index.de.md existiert ✅
```

**`*path` (glob):**
- Matched ALLES nach dem prefix
- Inkludiert Slashes
- `/docs_page/de/decision-makers/index` → `:path` = `"decision-makers/index"` ✅

---

## Geänderte Datei

**`config/routes.rb`:**

```ruby
# Alte Routen (broken für nested paths):
get "docs_page/:locale/:path" => :docs_page, 
    as: :docs_page_with_locale, 
    constraints: { locale: /de|en/ }
get "docs_page/:path" => :docs_page, 
    as: :docs_page, 
    defaults: { locale: "de" }

# Neue Routen (funktionieren für alle Pfade):
get "docs_page/:locale/*path" => :docs_page, 
    as: :docs_page_with_locale, 
    constraints: { locale: /de|en/ }
get "docs_page/*path" => :docs_page, 
    as: :docs_page, 
    defaults: { locale: "de" }
```

**Unterschied:** `:path` → `*path`

---

## Vorher/Nachher

### Vorher (broken)

| URL | Route Match | File Lookup | Result |
|-----|-------------|-------------|--------|
| `/docs_page/index` | `path: "index"` | `docs/index.de.md` ✅ | Works |
| `/docs_page/de/index` | `path: "index"` | `docs/index.de.md` ✅ | Works |
| `/docs_page/de/decision-makers/index` | `path: "decision-makers"` | `docs/decision-makers.de.md` ❌ | **404** |

**Problem:** Nur top-level Pfade funktionieren!

### Nachher (fixed)

| URL | Route Match | File Lookup | Result |
|-----|-------------|-------------|--------|
| `/docs_page/index` | `path: "index"` | `docs/index.de.md` ✅ | Works |
| `/docs_page/de/index` | `path: "index"` | `docs/index.de.md` ✅ | Works |
| `/docs_page/de/decision-makers/index` | `path: "decision-makers/index"` | `docs/decision-makers/index.de.md` ✅ | **Works!** |

**Gelöst:** Alle Pfade funktionieren! ✅

---

## Testing

### Route Recognition Test

```bash
$ bundle exec rails runner "
  app = Rails.application
  puts app.routes.recognize_path('/docs_page/de/decision-makers/index')
"

# Output:
{:controller=>"static", :action=>"docs_page", 
 :locale=>"de", :path=>"decision-makers/index"} ✅
```

### File Resolution Test

```bash
$ bundle exec rails runner "
  path = 'decision-makers/index'
  locale = 'de'
  file = Rails.root.join('docs', \"#{path}.#{locale}.md\")
  puts File.exist?(file) ? '✓ Found' : '✗ Not found'
"

# Output:
✓ Found
```

### End-to-End Test

1. Besuchen: `https://api.carambus.de/docs_page/index`
2. Klicken: "Entscheider-Übersicht" Link
3. URL: `https://api.carambus.de/docs_page/de/decision-makers/index`
4. **Result:** ✅ Seite lädt korrekt!

---

## Warum funktioniert das jetzt?

### Controller-Ablauf

```ruby
def docs_page
  path = params[:path]  # "decision-makers/index" (mit glob!)
  locale = params[:locale] || I18n.locale.to_s  # "de"
  
  # Versuche verschiedene Pfade:
  possible_paths = [
    Rails.root.join('docs', "#{path}.#{locale}.md"),  
    # → docs/decision-makers/index.de.md ✅ FOUND!
  ]
  
  docs_path = possible_paths.find { |p| File.exist?(p) }
  # → docs_path = .../docs/decision-makers/index.de.md ✅
  
  markdown_content = File.read(docs_path)  # ✅ Lädt Datei
  @rendered_content = render_markdown(content, locale: locale)  # ✅ Rendert
end
```

**Kette funktioniert:**
1. Route matched mit glob → `:path` = `"decision-makers/index"` ✅
2. Controller baut Datei-Pfad → `docs/decision-makers/index.de.md` ✅
3. Datei existiert → Laden & Rendern ✅
4. MarkdownRenderer transformiert Links → Weitere Links funktionieren ✅

---

## Rails Glob Parameter Basics

### Normaler Parameter (`:param`)

```ruby
get "docs/:path"  # :path matched nur bis zum ersten /

/docs/index           → :path = "index" ✅
/docs/dir/file        → :path = "dir" ❌ (stoppt bei /)
```

### Glob Parameter (`*param`)

```ruby
get "docs/*path"  # *path matched ALLES

/docs/index           → :path = "index" ✅
/docs/dir/file        → :path = "dir/file" ✅
/docs/a/b/c/d         → :path = "a/b/c/d" ✅
```

**Glob = Greedy Match** (nimmt alles)

---

## Verwandte Fixes

### Phase 4: Link-Transformation

**Vorher:**
```markdown
[Link](decision-makers/index.md)
```

**Nach Phase 4:**
```html
<a href="/docs_page/de/decision-makers/index">
```

**Aber:** Route funktionierte nicht → Phase 5 nötig!

### Phase 5: Routing Fix (diese)

**Routes aktualisiert:**
```ruby
*path statt :path
```

**Jetzt:**
- Links werden korrekt generiert (Phase 4) ✅
- Links werden korrekt geroutet (Phase 5) ✅
- **Alles funktioniert!** 🎉

---

## Best Practices

### ✅ Wann Glob verwenden

```ruby
# Wenn Pfade Slashes enthalten können:
get "docs/*path"          ✅
get "api/v1/*path"        ✅
get "files/*filepath"     ✅

# Für hierarchische Strukturen:
docs/
  managers/
    tournament-management.md
  players/
    scoreboard-guide.md
```

### ❌ Wann NICHT Glob verwenden

```ruby
# Wenn nur einfache Slugs (keine /):
get "articles/:slug"      ✅ (slug = "my-article")
get "users/:id"           ✅ (id = "123")

# Wenn mehrere spezifische Segmente:
get ":org/:repo/:branch"  ✅ (org/repo/branch einzeln)
```

### 🎯 Kombinieren

```ruby
# Prefix + Glob:
get "docs/:locale/*path"  ✅

# Beispiele:
/docs/de/index                    → locale: "de", path: "index"
/docs/en/managers/tournament      → locale: "en", path: "managers/tournament"
```

---

## Lessons Learned

### ✅ Was gelernt

1. **Rails `:param` vs `*param`**
   - `:param` stoppt bei `/`
   - `*param` nimmt alles
   - Für nested Pfade: Immer glob!

2. **Routing before Link-Transformation**
   - Links generieren ist nutzlos wenn Routes nicht matchen
   - Beide Seiten testen (Generation + Resolution)

3. **Testing mit recognize_path**
   ```ruby
   Rails.application.routes.recognize_path(url)
   ```
   - Zeigt was Rails matched
   - Hilft Routing-Probleme zu debuggen

4. **User-Testing unverzichtbar**
   - Entwickler testen oft nur eine Ebene
   - User klicken auf alle Links
   - Real-world URLs testen!

### 💡 Best Practices

1. **Glob für hierarchische Docs**
   ```ruby
   get "docs/*path"  # Nicht get "docs/:path"
   ```

2. **Routes nach Änderungen testen**
   ```bash
   bundle exec rails runner "
     puts Rails.application.routes.recognize_path('/your/url')
   "
   ```

3. **Beide Rendering-Systeme testen**
   - MkDocs: `/docs/*`
   - Rails: `/docs_page/*`
   - Verschiedene Pfad-Tiefen

---

## Timeline

```
Phase 4 (Link-Transformation)
  → Links generiert: /docs_page/de/decision-makers/index
  → Aber broken! (Routing)

User-Feedback
  → "Das funktioniert noch nicht"
  → URL getestet: /docs_page/de/decision-makers/index
  → 404 Error

Phase 5 (Routing Fix)
  → :path → *path
  → Routes funktionieren ✅
  → Ende-zu-Ende funktioniert! 🎉
```

---

## Verifikation

### Checklist

- [x] Route `config/routes.rb` auf `*path` geändert
- [x] Route Recognition Test passing
- [x] File Resolution Test passing
- [x] Top-level Links funktionieren (`/docs_page/index`)
- [x] Nested Links funktionieren (`/docs_page/de/decision-makers/index`)
- [x] Beide Locales funktionieren (de, en)
- [x] MarkdownRenderer transformiert korrekt
- [x] End-to-End Test erfolgreich

### Production URLs getestet

- ✅ `https://api.carambus.de/docs_page/index`
- ✅ `https://api.carambus.de/docs_page/de/index`
- ✅ `https://api.carambus.de/docs_page/de/decision-makers/index`
- ✅ `https://api.carambus.de/docs_page/de/managers/tournament-management`

**Alle funktionieren!** 🎉

---

## Impact

### Vorher (Phase 4 ohne Routing-Fix)

- ✅ Links wurden generiert
- ❌ Nur top-level funktionierte
- ❌ Nested paths: 404

**User Experience:** ⭐⭐ (frustierend)

### Nachher (Phase 5 mit Routing-Fix)

- ✅ Links werden generiert
- ✅ Top-level funktioniert
- ✅ Nested paths funktionieren

**User Experience:** ⭐⭐⭐⭐⭐ (perfekt)

---

## Referenzen

### Rails Guides

- [Routing Guide - Glob Parameter](https://guides.rubyonrails.org/routing.html#route-globbing-and-wildcard-segments)
- [Constraints](https://guides.rubyonrails.org/routing.html#segment-constraints)

### Eigene Docs

- `docs/internal/RAILS_DOCS_PAGE_FIX_2026_03.md` - Phase 4 (Link-Transformation)
- `docs/internal/RAILS_ROUTING_FIX_2026_03.md` - Diese Datei (Phase 5)

---

**Erstellt:** 18. März 2026  
**Phase:** 5 (Routing Fix)  
**Grund:** User-Feedback - nested paths funktionierten nicht  
**Status:** ✅ Alle Links funktionieren jetzt!
