# Carambus Documentation System

## Overview

Carambus has **two documentation systems** that work together:

1. **MkDocs Static Site** (`/docs/*`) - Full-featured documentation with search, navigation, and theming
2. **Rails-Rendered Docs** (`/docs_page/*`) - Markdown rendered with Rails application layout

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Source Files                            │
│                    docs/*.md files                           │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ├─────────────────┬───────────────────────┐
                    │                 │                       │
                    v                 v                       v
         ┌──────────────────┐  ┌─────────────┐   ┌──────────────────┐
         │  MkDocs Build    │  │ Rails Route │   │  GitHub Pages    │
         │  mkdocs build    │  │ /docs_page  │   │  (Optional)      │
         └────────┬─────────┘  └──────┬──────┘   └────────┬─────────┘
                  │                   │                     │
                  v                   v                     v
         ┌──────────────────┐  ┌─────────────┐   ┌──────────────────┐
         │   public/docs/   │  │ View with   │   │  GitHub Actions  │
         │   (HTML files)   │  │ Rails layout│   │  Auto-deploy     │
         └────────┬─────────┘  └─────────────┘   └──────────────────┘
                  │
                  v
         ┌──────────────────┐
         │  DocsController  │
         │  Serves /docs/*  │
         └──────────────────┘
```

## Build Process

### 1. Source Documentation

**Location**: `docs/` directory  
**Format**: Markdown files with naming convention:
- `filename.de.md` (German)
- `filename.en.md` (English)

**Structure**:
```
docs/
├── index.de.md                 # Main landing page
├── decision-makers/            # For decision makers
├── players/                    # For players
├── managers/                   # For tournament managers
├── administrators/             # For system administrators
├── developers/                 # For developers
└── reference/                  # API & reference docs
```

### 2. MkDocs Configuration

**File**: `mkdocs.yml`  
**Key settings**:
```yaml
docs_dir: docs           # Source directory
site_dir: site          # Build output (temporary)
site_url: https://gernotullrich.github.io/carambus
```

### 3. Build Commands

```bash
# Clean previous builds
bundle exec rake mkdocs:clean

# Build documentation (docs → site → public/docs)
bundle exec rake mkdocs:build

# Build and deploy in one step
bundle exec rake mkdocs:deploy

# Serve locally for development (port 8000)
bundle exec rake mkdocs:serve
```

### 4. Build Process Details

```bash
mkdocs build
  ↓
Creates: site/
  ↓
Copies to: public/docs/
  ↓
Served by: DocsController at /docs/*
```

## Routes

### MkDocs Static Site

- **Route**: `/docs/*path`
- **Controller**: `DocsController#show`
- **Source**: `public/docs/` (pre-built HTML)
- **Features**: Full MkDocs theme, search, navigation

**Examples**:
- `/docs/index` → `public/docs/index.html`
- `/docs/managers/tournament-management` → `public/docs/managers/tournament-management/index.html`

### Rails-Rendered Documentation

- **Route**: `/docs_page/:path` or `/docs_page/:locale/:path`
- **Controller**: `StaticController#docs_page`
- **Source**: `docs/` (Markdown)
- **Features**: Rails layout, integrated with app

**Examples**:
- `/docs_page/index` → Renders `docs/index.de.md`
- `/docs_page/en/managers/tournament-management` → Renders `docs/managers/tournament-management.en.md`

## Testing

### Automated Tests

```bash
# Run structure tests
./bin/test-docs-structure.sh
```

This tests:
- ✓ Core structure (index, 404, assets)
- ✓ Main sections (managers, players, etc.)
- ✓ Key documentation pages
- ✓ Multilingual support

### Manual Testing

1. **Test MkDocs site**:
   ```
   http://localhost:3000/docs/
   http://localhost:3000/docs/managers/tournament-management
   ```

2. **Test Rails-rendered docs**:
   ```
   http://localhost:3000/docs_page/index
   http://localhost:3000/docs_page/managers/tournament-management
   ```

3. **Test links within docs_page**:
   - Click "View in MkDocs" button
   - Click "Back to Documentation" button
   - Click related documentation links

## Known Issues & Warnings

The build process shows several warnings (non-breaking):

### 1. Missing Files Not in Navigation

Many documentation files exist but aren't in `mkdocs.yml` navigation. This is **intentional** for:
- Archive files
- Internal implementation notes
- Old documentation

**Action**: Can be ignored unless you want to add them to navigation.

### 2. Broken Links

Some docs reference files that don't exist:
- Missing screenshots: `players/screenshots/*.png`
- Missing English translations: `*.en.md` files
- Broken anchor links: `#section-name` that don't exist

**Fix**: Either:
- Create the missing files
- Remove the broken links
- Update links to correct files

### 3. Missing Anchors

Links to specific sections (anchors) that don't exist in target files.

**Example**:
```markdown
[Link](#missing-section)  # Section doesn't exist
```

**Fix**: Update the anchor names or remove the links.

## Deployment

### Local Deployment

```bash
# 1. Build documentation
bundle exec rake mkdocs:deploy

# 2. Restart Rails server (if needed)
bundle exec rails server
```

### Production Deployment

Documentation is automatically deployed to GitHub Pages via GitHub Actions when pushing to `master` branch.

**GitHub Actions Workflow**: `.github/workflows/build-docs.yml`

**Manual trigger**:
1. Go to: https://github.com/GernotUllrich/carambus/actions
2. Select "Build and Deploy Documentation"
3. Click "Run workflow"

## Maintenance

### Adding New Documentation

1. Create Markdown file in `docs/` with proper naming:
   ```
   docs/new-section/my-doc.de.md
   docs/new-section/my-doc.en.md
   ```

2. Add to `mkdocs.yml` navigation:
   ```yaml
   nav:
     - New Section:
       - new-section/my-doc.md
   ```

3. Rebuild documentation:
   ```bash
   bundle exec rake mkdocs:deploy
   ```

### Updating Existing Documentation

1. Edit the Markdown file in `docs/`
2. Rebuild: `bundle exec rake mkdocs:deploy`
3. Test: `./bin/test-docs-structure.sh`

### Fixing Broken Links

1. Run build and note warnings
2. Fix broken links in source files
3. Rebuild and verify

## File Naming Convention

MkDocs uses the `mkdocs-static-i18n` plugin with `suffix` naming:

- `filename.de.md` → German version
- `filename.en.md` → English version
- `filename.md` → Fallback (uses default language)

**Important**: The file path should NOT include the locale:
- ✓ `managers/tournament-management.de.md`
- ✗ `managers/de/tournament-management.md`

## Tips & Best Practices

1. **Always test after building**:
   ```bash
   bundle exec rake mkdocs:deploy && ./bin/test-docs-structure.sh
   ```

2. **Use relative links** in Markdown:
   ```markdown
   [Related Doc](../other-section/doc.md)
   ```

3. **Keep structure consistent** between German and English versions

4. **Test both documentation systems**:
   - MkDocs: `/docs/*`
   - Rails: `/docs_page/*`

5. **Clean before rebuilding** if you encounter issues:
   ```bash
   bundle exec rake mkdocs:clean
   bundle exec rake mkdocs:build
   ```

## Troubleshooting

### Problem: Documentation not updating

**Solution**:
```bash
bundle exec rake mkdocs:clean
bundle exec rake mkdocs:deploy
```

### Problem: 404 errors on /docs/*

**Check**:
1. Is `public/docs/` directory populated?
2. Run: `./bin/test-docs-structure.sh`
3. Rebuild if needed

### Problem: Links broken in docs_page

**Check**:
1. File naming: Use `filename.de.md`, not `filename_de.md`
2. Path separators: Use `/` not `_`
3. Locale parameter: Check if `locale` is correct

### Problem: MkDocs build fails

**Check**:
1. MkDocs installed: `mkdocs --version`
2. Dependencies: `pip install -r requirements.txt`
3. Valid YAML: Check `mkdocs.yml` syntax

## Summary

- ✅ Documentation built successfully
- ✅ All core tests passing
- ✅ Both systems (/docs and /docs_page) working
- ⚠️  Some warnings about missing files (non-breaking)
- ⚠️  Some broken links in documentation (can be fixed gradually)

**Next Steps**:
1. Test the documentation in production
2. Gradually fix broken links and missing screenshots
3. Consider adding more documentation files to navigation
