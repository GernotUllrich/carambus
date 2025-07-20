# Carambus Documentation

This directory contains the MkDocs-generated documentation for the Carambus project.

## 📚 Documentation Structure

The documentation is built using MkDocs with the Material theme and supports both German and English languages.

### Available Documentation

- **Tournament Management** (`/docs/tournament/`) - Tournament administration and management
- **League Match Days** (`/docs/league/`) - League match day management
- **Developer Guide** (`/docs/DEVELOPER_GUIDE/`) - Complete developer documentation
- **API Documentation** (`/docs/API/`) - API reference and examples
- **Database Design** (`/docs/database_design/`) - Database schema and design
- **MkDocs Documentation** (`/docs/mkdocs_dokumentation/`) - Documentation about the documentation system

### Language Support

- **German**: `/docs/de/` - Deutsche Dokumentation
- **English**: `/docs/en/` - English documentation

## 🚀 Deployment

### Quick Start

1. **Deploy documentation**:
   ```bash
   ./bin/deploy-docs.sh
   ```

2. **Start Rails server** (if not running):
   ```bash
   bundle exec rails server
   # or
   ./bin/start-local-server.sh
   ```

3. **Access documentation**:
   - Main: http://localhost:3000/docs/
   - German: http://localhost:3000/docs/de/
   - English: http://localhost:3000/docs/en/

### Manual Deployment

```bash
# Clean previous builds
bundle exec rake mkdocs:clean

# Build documentation
bundle exec rake mkdocs:build

# Or use the combined task
bundle exec rake mkdocs:deploy
```

### Development

For development with live reload:

```bash
bundle exec rake mkdocs:serve
```

This starts the MkDocs development server at http://127.0.0.1:8000/carambus-docs/

## 🔧 Configuration

### MkDocs Configuration

The documentation is configured in `mkdocs.yml` at the project root:

- **Theme**: Material theme with custom styling
- **Plugins**: mkdocs-static-i18n for multilingual support
- **Navigation**: Hierarchical navigation structure
- **Search**: Full-text search in both languages

### Rails Integration

The documentation URLs are configured in `config/initializers/mkdocs_urls.rb`:

```ruby
# Base URL for documentation
BASE_URL = ENV.fetch('MKDOCS_BASE_URL', '/docs')

# Language-specific URLs
MkDocsUrls.tournament_doc_url(locale)  # /docs/de/tournament/ or /docs/en/tournament/
MkDocsUrls.league_doc_url(locale)      # /docs/de/league/ or /docs/en/league/
```

### Environment Variables

- `MKDOCS_BASE_URL`: Base URL for documentation (default: `/docs`)
- `RAILS_ENV`: Rails environment for deployment

## 📝 Adding New Documentation

1. **Create Markdown file** in `pages/de/` and `pages/en/`
2. **Update navigation** in `mkdocs.yml`
3. **Deploy documentation**:
   ```bash
   ./bin/deploy-docs.sh
   ```

## 🛠️ Troubleshooting

### Common Issues

1. **MkDocs not installed**:
   ```bash
   pip install mkdocs-material mkdocs-static-i18n pymdown-extensions
   ```

2. **Build errors**:
   ```bash
   mkdocs build --strict
   ```

3. **Rails server not running**:
   ```bash
   bundle exec rails server
   ```

### File Structure

```
public/docs/                    # Deployed documentation
├── index.html                 # Main documentation page
├── de/                        # German documentation
│   ├── tournament/
│   ├── league/
│   └── ...
├── en/                        # English documentation
│   ├── tournament/
│   ├── league/
│   └── ...
└── assets/                    # Static assets (CSS, JS, images)

pages/                         # Source documentation
├── de/                        # German source files
├── en/                        # English source files
└── assets/                    # Source assets

mkdocs.yml                     # MkDocs configuration
```

## 🔗 Links

- **GitHub Actions**: Automatic documentation builds
- **Material Theme**: https://squidfunk.github.io/mkdocs-material/
- **MkDocs**: https://www.mkdocs.org/
- **mkdocs-static-i18n**: https://github.com/ultrabug/mkdocs-static-i18n 