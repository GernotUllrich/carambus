---
name: scenario-management
description: Manages multi-tenant deployment workflow for Carambus project with multiple git checkouts. Use when working with carambus_master, carambus_bcw, carambus_phat, or carambus_api directories, when modifying code, committing changes, or when user mentions scenarios, deployments, or debugging mode.
---

# Scenario Management System

⚠️ **CRITICAL**: This project uses a multi-tenant deployment system with ONE git repository and MULTIPLE checkouts. Violating these rules causes deployment failures.

## Repository Structure

```
/Users/gullrich/DEV/carambus/
├── carambus_master/   # DEVELOPMENT (modify here)
├── carambus_bcw/      # BCW deployment (git pull only)
├── carambus_phat/     # PHAT deployment (git pull only)
├── carambus_api/      # API deployment (git pull only)
└── carambus_data/     # Scenario configs
```

## Pre-Edit Precondition (CRITICAL)

⚠️ **Before editing in ANY scenario checkout, every other checkout must be either:**

1. **Clean with respect to `master`** — at the same commit as `origin/master`, no uncommitted changes, no extra commits ahead, OR
2. **On its own dedicated feature branch** (decoupled from `master`)

**Why this matters:** This project has 4 independent working trees of the same repo. Two checkouts both sitting on `master` and each making independent commits cannot be linearly merged — one side's work must be reworked or discarded. A 1-minute precondition check prevents hours (or weeks) of conflict resolution. This applies in BOTH Normal Mode and Debugging Mode.

### Verification check (run BEFORE any edit)

```bash
for d in carambus_master carambus_bcw carambus_phat carambus_api; do
  cd /Users/gullrich/DEV/carambus/$d
  echo "═══ $d ═══"
  git fetch -q origin master 2>/dev/null
  branch=$(git rev-parse --abbrev-ref HEAD)
  echo "Branch:  $branch"
  if [ "$branch" = "master" ]; then
    counts=$(git rev-list --left-right --count origin/master...HEAD 2>/dev/null)
    behind=$(echo "$counts" | awk '{print $1}')
    ahead=$(echo "$counts" | awk '{print $2}')
    echo "vs origin/master: behind=$behind ahead=$ahead"
    if [ "$ahead" -gt 0 ]; then echo "  ⚠ has unpushed commits — reconcile before editing elsewhere"; fi
  else
    echo "(feature branch — independent of master, OK)"
  fi
  if [ -z "$(git status --short)" ]; then echo "Working tree: clean"; else echo "Working tree:"; git status --short | sed 's/^/  /'; fi
  echo
done
```

### What "not safe" looks like

- Another checkout is on `master` with `ahead > 0` (unpushed commits) → **STOP**: push them first, then pull in your target checkout
- Another checkout has uncommitted changes to files you're about to touch → **STOP**: commit/stash/discard there first
- Another checkout's `master` is behind `origin/master` AND has divergent unpushed commits → **STOP**: reconcile manually before any new work

If reconciliation isn't possible (e.g., the divergent work represents a different architectural decision), **move one side to a feature branch** before resuming.

---

## Default Workflow (Normal Mode)

**Always follow this unless in Debugging Mode:**

1. ✅ **Run the pre-edit precondition check** (above)
2. ✅ **Modify code ONLY in `carambus_master/`**
3. ✅ **Commit and push from `carambus_master/`** (AI does this)
4. ⏸️ **User runs `git pull` in scenario checkout** (e.g., `carambus_bcw/`)
5. ⏸️ **User deploys via Capistrano**

### Never Do (Normal Mode)

- ❌ Modify files in `carambus_bcw/`, `carambus_phat/`, `carambus_api/`
- ❌ Commit from deployment checkouts
- ❌ Touch production servers directly

### Example: Normal Mode

```bash
# Edit in master
vim /Users/gullrich/DEV/carambus/carambus_master/app/models/tournament_cc.rb

# Commit from master
cd /Users/gullrich/DEV/carambus/carambus_master
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
- ✅ **Run the pre-edit precondition check before starting** — debugging mode does NOT exempt you from cross-checkout cleanliness
- ✅ **If user requests commit:**
  1. Commit and push from scenario checkout
  2. **IMMEDIATELY** run `git pull` in `carambus_master/` AND in every other deployment checkout that tracks `master` to sync
  3. Continue in debugging mode

### Example: Debugging Mode Workflow

```bash
# User: "Enter scenario debugging mode for carambus_bcw"

# AI can now edit scenario checkout
vim /Users/gullrich/DEV/carambus/carambus_bcw/app/models/tournament_cc.rb

# User: "Commit these changes"
cd /Users/gullrich/DEV/carambus/carambus_bcw
git add .
git commit -m "Debug: Fix tournament issue"
git push

# IMMEDIATELY sync back to master
cd /Users/gullrich/DEV/carambus/carambus_master
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
5. ❌ Starting work in any checkout without running the pre-edit precondition check — risks parallel work on `master` across checkouts and unmergeable divergence

## Additional Resources

For detailed deployment documentation: `/Users/gullrich/DEV/carambus/carambus_master/docs/developers/scenario-management.de.md`

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
