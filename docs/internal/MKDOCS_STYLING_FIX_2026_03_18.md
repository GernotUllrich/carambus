# MkDocs Styling & Link Fixes - 2026-03-18

## Problem
MkDocs-Dokumentation unter `/docs/*` hatte fehlerhafte/fehlende Styling und die "View in MkDocs" Links in Rails-gerenderten Docs (`/docs_page/*`) waren kaputt ("garbled output").

## Root Causes

### 1. Fehlende CSS/JS Assets
**Problem**: `mkdocs.yml` referenzierte Dateien, die nicht existierten:
- `docs/stylesheets/extra.css` 
- `docs/javascripts/mathjax.js`

**Impact**: 404 für diese Dateien → Layout broken

### 2. DocsController: Glob-Route Array-Handling
**Problem**: Rails Glob-Route `*path` liefert Array, nicht String
```ruby
# Vorher (FALSCH):
path = params[:path]  # => ["decision-makers", "index"]
docs_path = Rails.root.join('public', 'docs', path)  # FEHLER!
```

**Impact**: Pfad-Konstruktion fehlerhaft, Controller konnte Assets nicht finden

### 3. DocsController: Nur HTML Content-Type
**Problem**: Controller servierte alle Dateien mit `text/html`
```ruby
# Vorher:
response.headers['Content-Type'] = 'text/html; charset=utf-8'
```

**Impact**: CSS/JS wurden als HTML ausgeliefert → Browser ignorierte sie

### 4. View Template: Falsche MkDocs URLs
**Problem 1**: `params[:path]` als Array direkt in URL interpoliert
**Problem 2**: Fehlende Locale-Präfixe für i18n
**Problem 3**: Trailing Slash-Handling inkonsistent

```erb
<!-- Vorher (FALSCH): -->
<%= link_to "/docs/#{params[:path]}" %>
<!-- Resultat: /docs/["decision-makers", "index"] -->
```

**Impact**: "View in MkDocs" Links funktionierten nicht

## Implementierte Fixes

### Fix 1: Fehlende Assets erstellt

**Datei**: `docs/stylesheets/extra.css`
```css
/* Carambus Custom Styles */
.md-typeset {
  font-size: 0.9rem;
  line-height: 1.6;
}
/* ... weitere Styles ... */
```

**Datei**: `docs/javascripts/mathjax.js`
```javascript
window.MathJax = {
  tex: {
    inlineMath: [["\\(", "\\)"]],
    displayMath: [["\\[", "\\]"]],
    processEscapes: true,
    processEnvironments: true
  },
  options: {
    ignoreHtmlClass: ".*|",
    processHtmlClass: "arithmatex"
  }
};

document$.subscribe(() => { 
  MathJax.typesetPromise()
})
```

### Fix 2: DocsController - Array zu String Konvertierung

**Datei**: `app/controllers/docs_controller.rb`

```ruby
def show
  # Pfad aus der URL extrahieren (glob route gibt Array zurück)
  path = Array(params[:path]).join('/')  # FIX: Array → String

  # Sicherheitscheck: Verhindere Directory Traversal
  if path.include?('..') || path.start_with?('/')
    render_404
    return
  end

  # Datei aus public/docs laden
  docs_path = Rails.root.join('public', 'docs', path)
  # ... rest bleibt gleich
end
```

**Auch für**: `assets` Action

### Fix 3: DocsController - Multi-Format Support

**Datei**: `app/controllers/docs_controller.rb`

```ruby
def show
  # ... Datei finden ...

  # Prüfe Dateiendung und serviere entsprechend
  case File.extname(docs_path)
  when '.css'
    send_file docs_path, type: 'text/css', disposition: 'inline'
  when '.js'
    send_file docs_path, type: 'application/javascript', disposition: 'inline'
  when '.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico', '.webp'
    send_file docs_path, type: "image/#{File.extname(docs_path)[1..-1]}", disposition: 'inline'
  when '.woff', '.woff2', '.ttf', '.eot'
    send_file docs_path, type: 'font/woff', disposition: 'inline'
  when '.json'
    send_file docs_path, type: 'application/json', disposition: 'inline'
  else
    # HTML-Datei laden und rendern
    content = File.read(docs_path)
    response.headers['Content-Type'] = 'text/html; charset=utf-8'
    render html: content.html_safe, layout: false
  end
end
```

### Fix 4: View Template - Korrekte MkDocs URLs

**Datei**: `app/views/static/docs_page.html.erb`

```erb
<!-- External MkDocs Link -->
<div class="flex items-center">
  <% mkdocs_path = Array(params[:path]).join('/') %>
  <%# For 'index' pages at directory level, don't add trailing slash; for pages in subdirectories, add it %>
  <% is_index_file = mkdocs_path.end_with?('/index') || mkdocs_path == 'index' %>
  <% mkdocs_url = if params[:locale] == 'en'
                    is_index_file ? "/docs/en/#{mkdocs_path}" : "/docs/en/#{mkdocs_path}/"
                  else
                    is_index_file ? "/docs/#{mkdocs_path}" : "/docs/#{mkdocs_path}/"
                  end %>
  <%= link_to mkdocs_url, target: "_blank", ... %>
</div>
```

**Logik**:
- **Deutsch (Default)**: Kein `/de/` Prefix (MkDocs i18n `docs_structure: suffix`)
- **English**: `/en/` Prefix
- **Index-Dateien**: OHNE trailing slash (`/docs/decision-makers/index`)
- **Andere Seiten**: MIT trailing slash (`/docs/decision-makers/executive-summary/`)

**Begründung für Trailing Slash-Logik**:

MkDocs erzeugt unterschiedliche Strukturen:
```
public/docs/
├── decision-makers/
│   ├── index.html                          → URL: /docs/decision-makers/index (OHNE /)
│   └── executive-summary/
│       └── index.html                      → URL: /docs/decision-makers/executive-summary/ (MIT /)
```

Browser URL-Auflösung für `href="../assets/stylesheets/main.css"`:
- Von `/docs/decision-makers/index` → `/docs/assets/stylesheets/main.css` ✅
- Von `/docs/decision-makers/index/` → `/docs/decision-makers/assets/stylesheets/main.css` ❌

## Verifikation

### Lokaler Test
```bash
# CSS lädt korrekt
curl -I http://localhost:3333/docs/stylesheets/extra.css
# HTTP/1.1 200 OK

# JavaScript lädt korrekt
curl -I http://localhost:3333/docs/javascripts/mathjax.js
# HTTP/1.1 200 OK

# MkDocs Seiten laden mit korrektem Styling
curl -I http://localhost:3333/docs/decision-makers/index
# HTTP/1.1 200 OK

curl -I http://localhost:3333/docs/en/decision-makers/executive-summary/
# HTTP/1.1 200 OK
```

### Rails-Rendered Docs Links
```bash
# View in MkDocs Links korrekt generiert
curl -s http://localhost:3333/docs_page/de/decision-makers/index | grep 'href="/docs'
# href="/docs/decision-makers/index"  ✅ (kein trailing slash für index)

curl -s http://localhost:3333/docs_page/en/decision-makers/executive-summary | grep 'href="/docs'
# href="/docs/en/decision-makers/executive-summary/"  ✅ (trailing slash + locale)
```

## Geänderte Dateien

### Neue Dateien
- `docs/stylesheets/extra.css`
- `docs/javascripts/mathjax.js`

### Modifizierte Dateien
- `app/controllers/docs_controller.rb`
  - `show` Action: Array-Handling + Multi-Format Support
  - `assets` Action: Array-Handling
- `app/views/static/docs_page.html.erb`
  - MkDocs URL-Generierung mit Locale + Trailing Slash Logic

### Build-Dateien (nach `rake mkdocs:build`)
- `public/docs/stylesheets/extra.css` (kopiert)
- `public/docs/javascripts/mathjax.js` (kopiert)

## Deployment

### Build-Schritte
```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api

# MkDocs neu bauen (kopiert neue CSS/JS nach public/docs)
bundle exec rake mkdocs:build

# Assets kompilieren
yarn build && yarn build:css
rails assets:precompile

# Deployment
cap production deploy
```

### Kritische Reihenfolge
1. **Erst** `mkdocs:build` (erzeugt CSS/JS in public/docs)
2. **Dann** Deployment (sonst fehlen Assets in Production)

## Ergebnis

✅ MkDocs Seiten haben korrektes Material-Theme Styling
✅ CSS/JS Assets werden korrekt ausgeliefert  
✅ "View in MkDocs" Links funktionieren für beide Sprachen
✅ Trailing Slash korrekt je nach Seitentyp
✅ Locale-Handling (de/en) funktioniert

## Lessons Learned

1. **Rails Glob Routes**: `*path` liefert ARRAY, immer mit `Array().join('/')` konvertieren
2. **MkDocs i18n `suffix` Mode**: Default-Sprache hat KEIN Locale-Prefix im URL
3. **Trailing Slash wichtig**: Browser-Auflösung relativer URLs unterscheidet sich:
   - Datei (`/path/file`): `..` geht zu `/path/`
   - Verzeichnis (`/path/dir/`): `..` geht zu `/path/`
4. **mkdocs.yml Referenzen**: Alle `extra_css` und `extra_javascript` Dateien MÜSSEN existieren
5. **Content-Type kritisch**: Falsche Content-Type Headers → Browser ignoriert Assets

---

**Erstellt**: 2026-03-18  
**Getestet**: Lokal (Port 3333)  
**Status**: Ready for Production Deployment  
**Siehe auch**: 
- `docs/internal/RAILS_DOCS_PAGE_FIX_2026_03.md` (frühere Link-Fixes)
- `docs/internal/I18N_LINK_FIX_2026_03.md` (i18n Language Suffix Fixes)
