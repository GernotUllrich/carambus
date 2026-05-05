# Scenario Workflow - Git Management

## IMPORTANT RULE: Single Source of Truth

**ALL code changes, commits, and pushes are made ONLY in `carambus_master`.**

The other scenarios (`carambus_bcw`, `carambus_api`, `carambus_phat`, `carambus_pbv`) pull changes via `git pull`.

---

## Workflow Rules

### What ALWAYS happens in `carambus_master`:

1. **Code changes**: All edits to Ruby files, views, JavaScript, CSS, etc.
2. **Git commits**: All commits with meaningful commit messages
3. **Git push**: Push to `carambus/master` remote
4. **Testing**: Initial testing of new features

### What happens in scenario repos:

1. **Git pull**: Fetch changes from `carambus_master`
2. **Deployment**: Deploy to the respective servers (e.g., `cap bcw deploy`)
3. **Scenario-specific configuration**:
   - `.env` files (not committed)
   - `config/database.yml` (scenario-specific)
   - Production testing

### What NEVER happens in scenario repos:

- Direct code changes
- Git commits
- Git push
- Manual edits to shared files

---

## Typical Workflow

### Example: Implementing a Bug Fix

```bash
# 1. Work in carambus_master
cd /Users/gullrich/DEV/carambus/carambus_master

# 2. Change code
vim app/controllers/tournaments_controller.rb

# 3. Test (locally or on master server)
rails test

# 4. Commit and push
git add .
git commit -m "Fix: Tournament status update in background jobs"
git push carambus master

# 5. In each scenario repo: pull and deploy
cd ../carambus_bcw
git pull
cap bcw deploy

cd ../carambus_api
git pull
cap api deploy

cd ../carambus_phat
git pull
cap phat deploy

cd ../carambus_pbv
git pull
cap pbv deploy
```

---

## What to Do in Case of Git Conflicts in Scenarios?

If a scenario repo has local changes and `git pull` fails:

```bash
cd /Users/gullrich/DEV/carambus/carambus_bcw

# 1. Check what was changed
git status
git diff

# 2. Discard local changes (if made accidentally)
git reset --hard HEAD
git pull

# 3. OR: Port local changes to carambus_master
# - Copy the changes
# - Insert in carambus_master
# - Commit and push in carambus_master
# - Then in scenario repo: git reset --hard HEAD && git pull
```

---

## Repository Structure

```
carambus/
├── carambus_master/          # SINGLE SOURCE OF TRUTH
│   ├── app/                  # All code changes here
│   ├── docs/                 # All documentation updates here
│   └── .git/                 # All commits here
│
├── carambus_bcw/             # BCW Scenario (Pull only)
│   ├── .env                  # Scenario-specific
│   └── config/database.yml   # Scenario-specific
│
├── carambus_api/             # API Scenario (Pull only)
├── carambus_phat/            # PHAT Scenario (Pull only)
└── carambus_pbv/             # PBV Scenario (Pull only)
```

---

## Cursor AI Rule

**For Cursor AI / AI Assistants:**

```
IMPORTANT RULE:
- All edits, commits, and pushes are made ONLY from carambus_master
- Other scenarios pull versions via git pull
- NEVER edit directly in carambus_bcw, carambus_api, carambus_phat, or carambus_pbv
```

---

## Related Documentation

- CONTRIBUTING.en.md - General contribution guidelines
- README.en.md - Project overview
- carambus_master/docs/developers/ - Developer documentation

---

## Checklist for Code Changes

- [ ] Changes made in `carambus_master`
- [ ] Tested locally
- [ ] Commit with meaningful message
- [ ] Push to `carambus/master`
- [ ] In all relevant scenarios: `git pull`
- [ ] In all relevant scenarios: deployment performed
- [ ] Production test on at least one scenario server

---

**Last Updated**: 2026-02-06
