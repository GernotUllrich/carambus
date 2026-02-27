---
name: scenario-management
description: Manages multi-tenant deployment workflow for Carambus project with multiple git checkouts. Use when working with carambus_master, carambus_bcw, carambus_phat, or carambus_api directories, when modifying code, committing changes, or when user mentions scenarios, deployments, or debugging mode.
---

# Scenario Management System

⚠️ **CRITICAL**: This project uses a multi-tenant deployment system with ONE git repository and MULTIPLE checkouts. Violating these rules causes deployment failures.

## Repository Structure

```
/Volumes/EXT2TB/gullrich/DEV/carambus/
├── carambus_master/   # DEVELOPMENT (modify here)
├── carambus_bcw/      # BCW deployment (git pull only)
├── carambus_phat/     # PHAT deployment (git pull only)
├── carambus_api/      # API deployment (git pull only)
└── carambus_data/     # Scenario configs
```

## Default Workflow (Normal Mode)

**Always follow this unless in Debugging Mode:**

1. ✅ **Modify code ONLY in `carambus_master/`**
2. ✅ **Commit and push from `carambus_master/`** (AI does this)
3. ⏸️ **User runs `git pull` in scenario checkout** (e.g., `carambus_bcw/`)
4. ⏸️ **User deploys via Capistrano**

### Never Do (Normal Mode)

- ❌ Modify files in `carambus_bcw/`, `carambus_phat/`, `carambus_api/`
- ❌ Commit from deployment checkouts
- ❌ Touch production servers directly

### Example: Normal Mode

```bash
# Edit in master
vim /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/app/models/tournament_cc.rb

# Commit from master
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
git add .
git commit -m "Fix: Description"
git push
```

## Debugging Mode Exception

### Entering Debugging Mode

User must explicitly request: **"Enter scenario debugging mode for [scenario_name]"**

### Allowed in Debugging Mode

- ✅ **Modify files in specified scenario checkout** (e.g., `carambus_bcw/`)
- ✅ This is the ONLY exception to the "never modify deployment checkouts" rule

### Restrictions in Debugging Mode

- ❌ **NO commits unless user explicitly requests**
- ✅ **If user requests commit:**
  1. Commit and push from scenario checkout
  2. **IMMEDIATELY** run `git pull` in `carambus_master/` to sync
  3. Continue in debugging mode

### Example: Debugging Mode Workflow

```bash
# User: "Enter scenario debugging mode for carambus_bcw"

# AI can now edit scenario checkout
vim /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/app/models/tournament_cc.rb

# User: "Commit these changes"
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
git add .
git commit -m "Debug: Fix tournament issue"
git push

# IMMEDIATELY sync back to master
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
git pull

# Continue in debugging mode until user exits
```

### Exiting Debugging Mode

User must explicitly request: **"Exit scenario debugging mode"** or **"Return to normal mode"**

## Mode Detection

**Default**: Always assume **Normal Mode** unless user has explicitly entered Debugging Mode.

## Quick Reference

| Scenario | Can Modify? | Can Commit? | Notes |
|----------|-------------|-------------|-------|
| `carambus_master/` | ✅ Always | ✅ Always | Default development location |
| `carambus_bcw/` etc. | ❌ Normal<br>✅ Debug | ❌ Normal<br>✅ If requested | Must sync to master after commit |

## Scenario Configuration

Each scenario has config in `carambus_data/{scenario}/config.yml`:

```yaml
scenario:
  name: carambus_bcw
  location_id: 1
  context: LOCAL
  region_id: 1

environments:
  production:
    webserver_host: 192.168.178.107
    webserver_port: 81
    database_name: carambus_bcw_production
```

## Common Mistakes

1. ❌ Modifying `carambus_bcw/app/models/tournament_cc.rb` in Normal Mode
2. ❌ Committing from scenario checkout without syncing to master
3. ❌ Staying in Debugging Mode when not explicitly entered
4. ❌ Manual production server interventions

## Additional Resources

For detailed deployment documentation: `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/developers/scenario-management.de.md`

## Deployment Workflow

```
prepare_development → prepare_deploy → deploy
       ↓                    ↓             ↓
  Development          Production      Server
  (AI edits)          (User preps)    (User deploys)
```

User handles:
- `git pull` in deployment checkouts
- Capistrano: `rake "scenario:deploy[carambus_bcw]"`
- Production server access (read-only)
