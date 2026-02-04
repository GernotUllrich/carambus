# Integrierte MkDocs-Dokumentation in Carambus

## Übersicht

Diese Funktionalität ermöglicht es, ausgewählte MkDocs-Dokumente direkt in das Carambus-Layout zu integrieren, während die vollständige MkDocs-Dokumentation extern verfügbar bleibt.

## Vorteile

- **Einheitliche Quelle**: Alle Dokumentation kommt aus dem `docs/` Verzeichnis
- **Nahtlose Integration**: Dokumente werden im Carambus-Layout mit Redcarpet gerendert
- **Sprachunterstützung**: Automatische Erkennung und Umschaltung zwischen DE/EN
- **Responsive Design**: Vollständig integriert in das Carambus-Design-System
- **Navigation**: Breadcrumbs und verwandte Dokumentationslinks

## Verwendung

### 1. Einzelne Dokumente anzeigen

```ruby
# In Views oder Controllern
<%= docs_page_link('tournament', locale: 'de', text: 'Turnierverwaltung') %>
<%= docs_page_link('league', locale: 'en', text: 'League Management') %>
```

### 2. Externe MkDocs-Links

```ruby
# Links zu externer MkDocs-Dokumentation
<%= mkdocs_link('tournament', locale: 'de', text: 'In MkDocs öffnen') %>
```

### 3. Direkte URLs

```
# Deutsche Dokumentation
/docs_page/tournament                    # Standard (DE)
/docs_page/de/tournament                 # Explizit DE
/docs_page/en/tournament                 # Explizit EN

# Verschachtelte Pfade
/docs_page/user_guide/tournament         # Unterstützt Unterverzeichnisse
/docs_page/developer_guide/api           # Mehrere Ebenen
```

## Technische Details

### Controller

```ruby
# StaticController#docs_page
def docs_page
  path = params[:path]
  locale = params[:locale] || I18n.locale.to_s
  
  # Markdown-Datei aus docs/ laden
  docs_path = Rails.root.join('docs', locale, "#{path}.md")
  
  # Mit Redcarpet rendern
  @rendered_content = render_markdown(content)
  
  # Im Carambus-Layout anzeigen
  render 'docs_page', layout: 'application'
end
```

### Routen

```ruby
# config/routes.rb
scope controller: :static do
  get 'docs_page/:locale/:path' => :docs_page, as: :docs_page_with_locale, constraints: { locale: /de|en/ }
  get 'docs_page/:path' => :docs_page, as: :docs_page, defaults: { locale: 'de' }
end
```

### Hilfsmethoden

```ruby
# app/helpers/application_helper.rb

# Link zu integrierter Dokumentation
def docs_page_link(path, locale: nil, text: nil, options: {})
  locale ||= I18n.locale.to_s
  text ||= path.split('/').last.humanize
  
  link_to text, docs_page_path(path: path, locale: locale), options
end

# Link zu externer MkDocs-Dokumentation
def mkdocs_link(path, locale: nil, text: nil, options: {})
  locale ||= I18n.locale.to_s
  text ||= path.split('/').last.humanize
  
  url = "https://GernotUllrich.github.io/carambus-docs/#{locale}/#{path}/"
  link_to text, url, options.merge(target: '_blank', rel: 'noopener')
end
```

## Dateistruktur

```
docs/
├── de/                           # Deutsche Dokumentation
│   ├── tournament.md
│   ├── league.md
│   └── user_guide/
│       └── tournament.md
├── en/                           # Englische Dokumentation
│   ├── tournament.md
│   ├── league.md
│   └── user_guide/
│       └── tournament.md
└── assets/                       # Gemeinsame Assets
```

## Features

### Front Matter Support

```yaml
---
title: Turnierverwaltung
summary: Verwaltung von Billard-Turnieren
version: 1.0
published_at: 2025-03-07
tags: [tournament, management]
---
```

### Markdown-Features

- **Code-Highlighting**: Mit Rouge und Redcarpet
- **Tabellen**: Vollständige Markdown-Tabellen
- **Links**: Interne und externe Links
- **Bilder**: Unterstützung für lokale und externe Bilder
- **Listen**: Verschachtelte Listen und Aufzählungen

### Responsive Design

- **Mobile-first**: Optimiert für alle Bildschirmgrößen
- **Dark Mode**: Unterstützt das Carambus Dark Mode System
- **Tailwind CSS**: Vollständig integriert in das Design-System

## Beispiele

### 1. Navigation in bestehenden Views

```erb
<!-- In einer View -->
<div class="documentation-links">
  <h3>Weitere Informationen</h3>
  <ul>
    <li><%= docs_page_link('tournament', text: 'Turnierverwaltung') %></li>
    <li><%= docs_page_link('league', text: 'Ligaspieltage') %></li>
    <li><%= mkdocs_link('api', text: 'API-Dokumentation') %></li>
  </ul>
</div>
```

### 2. Dynamische Dokumentationslinks

```erb
<!-- Basierend auf dem aktuellen Kontext -->
<% if @tournament %>
  <div class="help-section">
    <p>Benötigen Sie Hilfe? Lesen Sie die 
      <%= docs_page_link('tournament', text: 'Turnierverwaltungs-Dokumentation') %>
    </p>
  </div>
<% end %>
```

### 3. Sprachspezifische Links

```erb
<!-- Explizite Sprachauswahl -->
<div class="language-specific-links">
  <h4>Deutsch</h4>
  <%= docs_page_link('tournament', locale: 'de', text: 'Turnierverwaltung') %>
  
  <h4>English</h4>
  <%= docs_page_link('tournament', locale: 'en', text: 'Tournament Management') %>
</div>
```

## Konfiguration

### MkDocs-Integration

```yaml
# mkdocs.yml
docs_dir: docs
nav:
  - Home: index.md
  - User Guide:
      - Tournament: de/user_guide/tournament.md
      - League: de/user_guide/league.md
  - Developer Guide:
      - API: de/developer_guide/api.md
```

### Rails-Konfiguration

```ruby
# config/application.rb
config.autoload_paths += %W(#{config.root}/app/lib)

# Lokalisierung
config.i18n.available_locales = [:de, :en]
config.i18n.default_locale = :de
```

## Wartung

### Neue Dokumente hinzufügen

1. **Markdown-Datei erstellen** in `docs/de/` und `docs/en/`
2. **Front Matter hinzufügen** mit Titel und Metadaten
3. **Navigation aktualisieren** in `mkdocs.yml`
4. **Links in Views hinzufügen** mit `docs_page_link`

### Bestehende Dokumente aktualisieren

1. **Markdown-Datei bearbeiten** in `docs/`
2. **Änderungen testen** über `/docs_page/path`
3. **MkDocs neu bauen** für externe Dokumentation
4. **Links validieren** in integrierten Views

## Troubleshooting

### Häufige Probleme

1. **404-Fehler**: Pfad existiert nicht in `docs/`
2. **Rendering-Fehler**: Ungültiges Markdown oder Front Matter
3. **Sprachprobleme**: Locale nicht korrekt gesetzt
4. **Layout-Probleme**: CSS-Konflikte mit bestehenden Styles

### Debugging

```ruby
# In der Rails-Konsole
Rails.application.routes.recognize_path('/docs_page/tournament')
# => {:controller=>"static", :action=>"docs_page", :path=>"tournament"}

# Pfad-Validierung
File.exist?(Rails.root.join('docs', 'de', 'tournament.md'))
# => true/false
```

## Zukunft

### Geplante Erweiterungen

- **Suchfunktionalität**: Volltext-Suche in integrierten Dokumenten
- **Kategorisierung**: Automatische Gruppierung verwandter Dokumente
- **Versionierung**: Unterstützung für verschiedene Dokumentationsversionen
- **Feedback-System**: Kommentare und Verbesserungsvorschläge
- **Analytics**: Tracking der Dokumentationsnutzung

### Integration mit bestehenden Systemen

- **Admin-Interface**: Dokumentationsverwaltung über Administrate
- **API-Dokumentation**: Automatische Generierung aus Code-Kommentaren
- **Changelog**: Integration mit Git-History und Releases
- **Help-System**: Kontextsensitive Hilfe in der Anwendung

---

**Erstellt von**: AI Assistant  
**Datum**: 18. August 2025  
**Status**: Implementiert und getestet  
**Version**: 1.0 