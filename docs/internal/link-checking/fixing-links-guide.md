# Fixing Documentation Links - Complete Guide

## Overview

After the documentation reorganization (moving files into subfolders like `players/`, `managers/`, `developers/`, etc.), many internal links are broken because they still point to the old flat structure.

## Current Status

**All Documentation (including archives)**:
- **Total markdown files**: 323
- **Total links checked**: 959
- **External links**: 213 (not checked)
- **Broken internal links**: 124 ❌

**Active Documentation Only** ⭐ (excludes archives/internal):
- **Markdown files**: 191 (132 excluded)
- **Total links**: 849
- **External links**: 198
- **Broken internal links**: 90 ❌ ← Focus on these!

## Tools Available

### 1. Link Checker (`bin/check-docs-links.rb`)

**Checks all markdown links and reports broken ones.**

```bash
# Check all links (including archives)
ruby bin/check-docs-links.rb

# Check only active documentation (exclude archives/internal)
ruby bin/check-docs-links.rb --exclude-archives

# Save report to file
ruby bin/check-docs-links.rb > docs/BROKEN_LINKS_REPORT.txt 2>&1

# Save report excluding archives
ruby bin/check-docs-links.rb --exclude-archives > docs/ACTIVE_DOCS_LINKS.txt 2>&1
```

**Output includes:**
- Source file and line number
- Link text and URL
- Suggested fixes (if files with similar names found)
- Statistics by directory

### 2. Link Fixer (`bin/fix-docs-links.rb`)

**Automatically fixes common broken link patterns.**

```bash
# Dry run (shows what would be changed)
ruby bin/fix-docs-links.rb

# Apply fixes
ruby bin/fix-docs-links.rb --live
```

**Can automatically fix:**
- ✓ Remove `docs/` prefix from paths
- ✓ Fix `table-reservation` path issues
- ✓ Fix old `INSTALLATION/QUICKSTART` paths
- ✓ Fix `test/` references to point to `developers/testing`
- ✓ Fix `TESTING.md` references
- ✓ Fix `doc/doc/Runbook` references
- ✓ Move obsolete references

**Current automatic fixes**: 16 fixes in 9 files

### Usage Examples

```bash
# Check all documentation
ruby bin/check-docs-links.rb
# Output: 323 files, 959 links, 124 broken

# Check only active documentation (RECOMMENDED)
ruby bin/check-docs-links.rb --exclude-archives  
# Output: 191 files, 849 links, 90 broken ✓
```

## Fixing Strategy

### Phase 1: Automatic Fixes (Quick Win)

Apply automatic fixes for common patterns:

```bash
# 1. Review what will be fixed
ruby bin/fix-docs-links.rb

# 2. Apply automatic fixes
ruby bin/fix-docs-links.rb --live

# 3. Verify results
git diff docs/

# 4. Check remaining broken links
ruby bin/check-docs-links.rb
```

This should fix ~14% of broken links (16 out of 117).

### Phase 2: Manual Fixes by Category

#### Category 1: Reorganization Links (High Priority)

**Problem**: Links to files that moved to subfolders

**Examples**:
```markdown
# Old (broken)
[Tournament Management](tournament-management.md)

# New (correct)
[Tournament Management](managers/tournament-management.md)
```

**Affected areas**:
- Links from root docs to subfolder docs
- Links between different subfolders

**How to fix**:
1. Check the suggestion in the link checker output
2. Update the relative path
3. Consider the source file's location when using `../`

#### Category 2: Missing Files (Medium Priority)

**Problem**: Links to files that don't exist

**Common cases**:
- **Screenshots**: `players/screenshots/*.png` - images not committed
- **Test files**: `test/README.md` - should point to `developers/testing/`
- **Old structure**: `INSTALLATION/`, `TESTING.md` - reorganized

**How to fix**:
- Screenshots: Either add the images or remove the links
- Test files: Update to point to new locations
- Old structure: Update to new paths (see mapping below)

#### Category 3: Archive/Internal Files (Low Priority)

**Problem**: Links in archived documents

**Recommendation**: 
- Archive files can be left with broken links (they're historical)
- Focus on active documentation first
- Consider excluding from MkDocs navigation

**To exclude from link checking**:
Edit `bin/check-docs-links.rb` and adjust exclude patterns.

### Phase 3: Path Mapping Reference

#### Old Structure → New Structure

| Old Path | New Path | Notes |
|----------|----------|-------|
| `INSTALLATION/QUICKSTART.md` | `administrators/raspberry-pi-quickstart.de.md` | Renamed |
| `TESTING.md` | `developers/testing/testing-quickstart.md` | Moved |
| `test/README.md` | `developers/testing/testing-quickstart.md` | Consolidated |
| `doc/doc/Runbook` | `developers/developer-guide.de.md` | Merged |
| `obsolete/*` | `developers/*` or remove | Case by case |
| `docs/developers/` | `developers/` | Removed `docs/` prefix |

#### Relative Path Patterns

When fixing links, consider the source file location:

```
Source: docs/managers/tournament-management.de.md
Target: docs/developers/developer-guide.de.md

Link: ../developers/developer-guide.de.md
```

```
Source: docs/index.de.md
Target: docs/managers/tournament-management.de.md

Link: managers/tournament-management.de.md
```

```
Source: docs/developers/testing/testing-quickstart.md
Target: docs/developers/developer-guide.de.md

Link: ../developer-guide.de.md
```

## Workflow

### Complete Fix Workflow

```bash
# 1. Check current state
ruby bin/check-docs-links.rb > docs/BROKEN_LINKS_REPORT.txt 2>&1
echo "Broken links: $(grep -c 'Line [0-9]' docs/BROKEN_LINKS_REPORT.txt)"

# 2. Apply automatic fixes
ruby bin/fix-docs-links.rb --live

# 3. Check progress
ruby bin/check-docs-links.rb

# 4. Manual fixes (work through report)
# Edit files based on suggestions in report

# 5. Test after each batch of fixes
ruby bin/check-docs-links.rb

# 6. Rebuild documentation
bundle exec rake mkdocs:deploy

# 7. Test the built documentation
./bin/test-docs-structure.sh

# 8. Commit when complete
git add docs/
git commit -m "Fix documentation links after reorganization"
```

### Iterative Approach

Don't try to fix all 90 links at once. Work in batches:

**Batch 1: Active Documentation** (Priority 1)
- `managers/` - 10 broken links
- `administrators/` - 5 broken links
- `developers/` - 15 broken links
- `players/` - 8 broken links

**Batch 2: Reference Documentation** (Priority 2)
- `reference/` - 5 broken links
- `decision-makers/` - 3 broken links

**Batch 3: Archive/Internal** (Priority 3)
- `archive/` - 40+ broken links (consider leaving)
- `internal/` - 30+ broken links (consider leaving)

## Common Patterns to Fix Manually

### Pattern 1: Direct subfolder reference

```markdown
# Broken
[Guide](../managers/table-reservation.md)

# Check if file exists with different name
ls docs/managers/*reservation*

# Fix
[Guide](../managers/table-reservation.md)
```

### Pattern 2: Remove docs/ prefix

```markdown
# Broken
[Guide](../developers/testing-strategy.md)

# Fixed
[Guide](../developers/testing-strategy.md)
```

### Pattern 3: Update to new structure

```markdown
# Broken
[Installation](../administrators/raspberry-pi-quickstart.md)

# Fixed
[Installation](../administrators/raspberry-pi-quickstart.md)
```

## Verification

After fixing links, verify with multiple checks:

```bash
# 1. Link checker (should show 0 broken links)
ruby bin/check-docs-links.rb

# 2. MkDocs build (should have fewer warnings)
bundle exec rake mkdocs:build

# 3. Test structure
./bin/test-docs-structure.sh

# 4. Manual spot checks
# - Open /docs/index in browser
# - Click through major sections
# - Verify key links work
```

## Tips

1. **Use search and replace carefully**: Some patterns appear multiple times
2. **Test frequently**: Check links after each batch of fixes
3. **Keep track**: Mark sections as "done" in the report
4. **Focus on user-facing docs first**: Archive can wait
5. **Commit often**: Small commits make it easier to revert if needed

## Expected Timeline

- **Automatic fixes**: 5 minutes
- **Active documentation (Priority 1)**: 1-2 hours
- **Reference documentation (Priority 2)**: 30 minutes  
- **Archive/Internal (Priority 3)**: Optional

**Total for critical paths**: ~2-3 hours

## After Completion

Once all links are fixed:

```bash
# 1. Final check
ruby bin/check-docs-links.rb
# Should show: "✓ All internal links are valid!"

# 2. Rebuild docs
bundle exec rake mkdocs:deploy

# 3. Update this guide
# Mark as complete and add date

# 4. Commit
git add docs/
git commit -m "Complete documentation link fixes

- Fixed all 117 broken links after reorganization
- Verified with automated link checker
- Rebuilt MkDocs documentation
"
```

## Exclusions

To check only active documentation (excluding archives/internal):

```bash
ruby bin/check-docs-links.rb --exclude-archives
```

**What gets excluded**:
- `**/obsolete/**` - Obsolete documents
- `**/archive/**` - Archive documents  
- `**/internal/**` - Internal documents
- `**/studies/**` - Study documents

**Effect**: Reduces from 323 files (124 broken) to 191 files (90 broken)

**Reduction**: 132 files and 34 broken links excluded

This focuses the check on user-facing documentation only.

## Help

If you encounter issues:

1. **Link checker fails**: Check Ruby version, ensure all files readable
2. **Can't find target**: Use `find docs -name "*filename*"` to locate files
3. **Relative paths confusing**: Draw the directory tree or use absolute editor paths
4. **Too many links**: Focus on one directory at a time

## Summary

- ✅ Tools created: Link checker and auto-fixer
- ✅ Report generated: 124 total broken links (90 in active docs)
- ⏳ Automatic fixes: 16 ready to apply
- ⏳ Manual fixes: ~74 remaining in active documentation
- 📋 Strategy: Work in batches, test frequently
- 🎯 Goal: Zero broken links in active documentation

**Recommended approach**:
```bash
# 1. Check active docs only
ruby bin/check-docs-links.rb --exclude-archives

# 2. Apply automatic fixes
ruby bin/fix-docs-links.rb --live

# 3. Check progress
ruby bin/check-docs-links.rb --exclude-archives
```
