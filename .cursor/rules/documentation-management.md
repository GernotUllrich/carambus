# Documentation Management - Coding Rules

## CRITICAL: Avoid Creating Redundant Documentation Files

### ❌ NEVER Create New Top-Level Documentation Without Updating Existing Docs

```bash
# BAD - Creates redundant files in docs/
touch docs/NEW_FEATURE_GUIDE.md
touch docs/IMPLEMENTATION_NOTES.md
touch QUICK_START_SOMETHING.md  # Even worse - in Rails.root!

# Result: Fragmented, outdated documentation that nobody maintains
```

### ✅ ALWAYS Follow This Documentation Workflow

```bash
# STEP 1: During Development - Use internal docs
touch docs/internal/implementation-notes/feature-name.md

# STEP 2: After Testing - Update official documentation
# Update existing docs OR integrate into official structure
vim docs/developers/feature-guide.de.md
vim docs/developers/feature-guide.en.md
```

---

## The Problem

### Symptoms of Bad Documentation Practice

1. **Multiple files about the same topic**
   ```
   docs/DOCUMENTATION_SYSTEM.md      (AI created)
   docs/DOCUMENTATION_INDEX.md       (AI created)
   docs/MKDOCS_DEVELOPMENT.md        (AI updated)
   docs/reference/mkdocs_dokumentation.de.md  (official)
   ```
   → **4 files about documentation!** Which one is current?

2. **Files with UPPERCASE names scattered everywhere**
   ```
   docs/NEW_FEATURE_GUIDE.md
   QUICK_START_SOMETHING.md
   IMPLEMENTATION_NOTES.md
   ```
   → Not following naming conventions, hard to find

3. **Official docs become outdated**
   - AI creates new docs instead of updating existing ones
   - Users find multiple conflicting versions
   - Nobody knows which is authoritative

### Impact

- ❌ **User confusion** - Which document to read?
- ❌ **Maintenance burden** - Multiple files to update
- ❌ **Outdated information** - Official docs not kept current
- ❌ **Wasted time** - Searching through redundant docs
- ❌ **Broken links** - Cross-references break

---

## Documentation Workflow

### Phase 1: During Development (Work-in-Progress)

**Use:** `docs/internal/` directory

```bash
# Create implementation notes, ideas, work logs
docs/internal/implementation-notes/
docs/internal/bug-fixes/
docs/internal/performance-analysis/
docs/internal/archive/
```

**Characteristics:**
- ✅ Can be messy, incomplete
- ✅ UPPERCASE names OK (temporary)
- ✅ No translation needed
- ✅ No need for perfect formatting
- ✅ Quick documentation during development

**Example:**
```bash
# During feature development
docs/internal/implementation-notes/NEW_LINK_CHECKER_IMPLEMENTATION.md
docs/internal/bug-fixes/DOCUMENTATION_LINKS_FIX_2026_03.md
```

### Phase 2: After Implementation (Official Documentation)

**Update:** Existing official documentation OR integrate properly

```bash
# Option A: Update existing docs
vim docs/developers/developer-guide.de.md  # Add new section
vim docs/administrators/installation-overview.de.md  # Update

# Option B: Create NEW official doc (if truly new topic)
vim docs/developers/link-checking.de.md  # Following naming convention
vim docs/developers/link-checking.en.md  # With translation
```

**Characteristics:**
- ✅ lowercase-with-dashes naming
- ✅ Bilingual (.de.md + .en.md)
- ✅ Integrated into mkdocs.yml navigation
- ✅ Professional formatting
- ✅ Cross-linked with other docs
- ✅ Version controlled

### Phase 3: Cleanup

**Move or delete:** Internal docs after integration

```bash
# Archive completed internal docs
mv docs/internal/implementation-notes/FEATURE_X.md \
   docs/internal/archive/2026-03/feature-x-notes.md

# Or delete if content fully integrated
rm docs/internal/implementation-notes/TEMPORARY_NOTES.md
```

---

## Naming Conventions

### Official Documentation (docs/)

**Format:** `lowercase-with-dashes.LANG.md`

```bash
✅ GOOD:
docs/developers/developer-guide.de.md
docs/developers/developer-guide.en.md
docs/managers/tournament-management.de.md
docs/administrators/installation-overview.de.md

❌ BAD:
docs/DEVELOPER_GUIDE.md          # UPPERCASE
docs/DeveloperGuide.md           # CamelCase
docs/developer_guide.md          # underscores
docs/developers/new-feature.md   # missing .de or .en
```

### Internal Documentation (docs/internal/)

**More flexible, but still organized:**

```bash
✅ ACCEPTABLE:
docs/internal/implementation-notes/FEATURE_NOTES.md  # UPPERCASE ok
docs/internal/bug-fixes/issue-1234-fix.md
docs/internal/archive/2026-03/old-notes.md

❌ AVOID:
docs/IMPLEMENTATION_NOTES.md     # Wrong location!
QUICK_FIX_GUIDE.md                # Wrong location!
```

---

## File Location Rules

### Root Directory (`/`)

**NEVER** create documentation files in Rails.root!

```bash
❌ NEVER:
/QUICK_START.md
/IMPLEMENTATION_GUIDE.md
/NEW_FEATURE_NOTES.md
```

**ONLY these are allowed in root:**
```bash
✅ OK in root:
README.md           # Project README
CHANGELOG.md        # Version history (if not using docs/changelog/)
CONTRIBUTING.md     # Contribution guidelines
```

### docs/ Directory

**Structure:**
```bash
docs/
├── index.de.md, index.en.md          # Main landing pages
├── decision-makers/                   # User-facing docs
├── players/
├── managers/
├── administrators/
├── developers/                        # Developer docs
├── reference/                         # API, glossary
├── international/                     # International features
└── internal/                          # ⭐ Work-in-progress docs
    ├── implementation-notes/
    ├── bug-fixes/
    ├── performance-analysis/
    └── archive/                       # Old internal docs
```

---

## Before Creating New Documentation

### Checklist

Ask yourself:

1. **Does similar documentation already exist?**
   ```bash
   # Search existing docs
   grep -r "keyword" docs/
   ruby bin/check-docs-links.rb
   ```

2. **Is this work-in-progress or final?**
   - Work-in-progress → `docs/internal/`
   - Final → Update existing or create properly named doc

3. **Is this temporary or permanent?**
   - Temporary → `docs/internal/` (can be deleted later)
   - Permanent → Official docs with translation

4. **Can I update an existing document instead?**
   - YES → Update existing (preferred!)
   - NO → Create new, but follow conventions

### Decision Tree

```
Need to document something?
│
├─ Is this a quick note during development?
│  └─ YES → docs/internal/implementation-notes/QUICK_NOTE.md
│
├─ Does official documentation exist for this topic?
│  └─ YES → Update the existing official doc!
│
├─ Is the feature complete and tested?
│  ├─ NO → docs/internal/ first
│  └─ YES → Create official doc with .de.md + .en.md
│
└─ Is this general project info?
   └─ Consider if it belongs in README.md instead
```

---

## Examples

### Example 1: Link Checker Feature (What I Did Wrong)

**What I did (WRONG):**
```bash
# Created multiple new top-level docs
docs/DOCUMENTATION_SYSTEM.md       # NEW redundant doc
docs/FIXING_DOCUMENTATION_LINKS.md # NEW redundant doc
```

**What I should have done (CORRECT):**
```bash
# Step 1: During development
docs/internal/implementation-notes/link-checker-implementation.md

# Step 2: After testing
# Update existing documentation:
vim docs/MKDOCS_DEVELOPMENT.md  # Add section about link checking
vim docs/developers/developer-guide.de.md  # Add workflow

# Step 3: Move internal doc to archive
mv docs/internal/implementation-notes/link-checker-implementation.md \
   docs/internal/archive/2026-03/
```

### Example 2: New Testing Feature (CORRECT)

```bash
# During development
docs/internal/implementation-notes/NEW_TESTING_APPROACH.md

# After implementation - update existing
vim docs/developers/testing/testing-quickstart.md  # Add new approach
vim docs/developers/developer-guide.de.md          # Update workflow

# Clean up
rm docs/internal/implementation-notes/NEW_TESTING_APPROACH.md
```

### Example 3: Bug Fix Documentation (CORRECT)

```bash
# Document the fix (internal)
docs/internal/bug-fixes/link-checker-fix-2026-03.md

# If fix requires user action - update official docs
vim docs/MKDOCS_DEVELOPMENT.md  # Update troubleshooting section

# Archive internal doc
mv docs/internal/bug-fixes/link-checker-fix-2026-03.md \
   docs/internal/archive/2026-03/
```

---

## AI Assistant Guidelines

### When I (AI) Help with Documentation

**I MUST:**

1. ✅ **Check existing docs first**
   ```bash
   # Before creating anything
   find docs -name "*keyword*"
   grep -r "topic" docs/
   ```

2. ✅ **Ask before creating new top-level docs**
   - "I found existing documentation at X. Should I update that instead?"
   - "This seems like work-in-progress. Should I put it in docs/internal/?"

3. ✅ **Prefer updating over creating**
   - Default to updating existing official documentation
   - Only create new if truly necessary

4. ✅ **Use internal/ for work-in-progress**
   - Implementation notes → `docs/internal/implementation-notes/`
   - Bug fix docs → `docs/internal/bug-fixes/`
   - Temporary guides → `docs/internal/`

5. ✅ **Follow naming conventions**
   - Official docs: `lowercase-with-dashes.de.md`
   - Internal docs: Can be flexible, but organized

**I MUST NOT:**

1. ❌ **Create UPPERCASE files in docs/ without asking**
2. ❌ **Create files in Rails.root**
3. ❌ **Duplicate existing documentation**
4. ❌ **Create docs without checking if similar exist**
5. ❌ **Skip translation (.de.md + .en.md) for official docs**

---

## Maintenance

### Regular Cleanup

**Monthly:**
```bash
# Review internal docs
ls -la docs/internal/implementation-notes/

# Archive completed items
mv docs/internal/implementation-notes/OLD_* docs/internal/archive/$(date +%Y-%m)/

# Delete truly temporary docs
rm docs/internal/implementation-notes/TEMP_*.md
```

### Quarterly Review

```bash
# Find redundant documentation
find docs -name "*.md" -exec basename {} \; | sort | uniq -d

# Check for UPPERCASE files (should be rare)
find docs -name "[A-Z]*.md" | grep -v "internal/"

# Review and consolidate
```

---

## Code Review Checklist

When reviewing pull requests:

- [ ] No new UPPERCASE .md files in docs/ (except internal/)
- [ ] No documentation files in Rails.root
- [ ] New docs follow lowercase-with-dashes.LANG.md convention
- [ ] Official docs have both .de.md and .en.md versions
- [ ] Work-in-progress docs are in docs/internal/
- [ ] Changes update existing docs instead of creating new ones
- [ ] mkdocs.yml navigation updated if new official doc
- [ ] Internal docs archived/deleted if feature complete

---

## Related

- Link checking: `ruby bin/check-docs-links.rb`
- Documentation system: `docs/MKDOCS_DEVELOPMENT.md`
- MkDocs configuration: `mkdocs.yml`
- i18n plugin: `mkdocs-static-i18n`

---

## Enforcement

This rule is **CRITICAL** for:
- ✅ Documentation maintainability
- ✅ User experience (finding current docs)
- ✅ Avoiding redundancy and confusion
- ✅ Long-term project health

**Summary:**
- 🔴 **During development**: Use `docs/internal/`
- 🟢 **After testing**: Update existing official docs OR integrate properly
- 🔵 **Never**: Create redundant top-level docs without consolidation

**Violations should be caught in code review before merge.**

---

## Internal Links (i18n)

**CRITICAL:** When using mkdocs-static-i18n with `docs_structure: suffix`:

- ✅ **USE:** `[Text](file.md)` (without language suffix)
- ❌ **DO NOT USE:** `[Text](file.de.md)` or `[Text](file.en.md)`

The mkdocs-static-i18n plugin automatically resolves the correct language version based on the current page's locale.

**Example:**
```markdown
✅ [Tournament Management](managers/tournament-management.md)
❌ [Turnierverwaltung](managers/tournament-management.de.md)
```

**Why:** Links with explicit language suffixes break because:
1. MkDocs tries to find `file.de.de.md` (double suffix)
2. OR link only works in one language, not both
3. The plugin is designed to handle this automatically

Always use relative paths and verify that the target file exists.

**See:** `docs/internal/I18N_LINK_FIX_2026_03.md` for details on this fix.
