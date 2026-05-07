---
name: scenario-management
description: Manages multi-tenant deployment workflow for Carambus project with multiple git checkouts. Use when working with carambus_master, carambus_bcw, carambus_phat, or carambus_api directories, when modifying code, committing changes, or when user mentions scenarios, deployments, or feature branches.
---

# Scenario Management System

⚠️ **CRITICAL**: This project has ONE git repository with MULTIPLE checkouts (one per scenario). To prevent unmergeable divergence between checkouts, EVERY chat must explicitly declare its work mode BEFORE any edit. No edits without a declared mode.

## Repository Structure

```
/Users/gullrich/DEV/carambus/
├── carambus_master/   # MASTER MODE ONLY (master branch)
├── carambus_bcw/      # BCW scenario (master pull OR scenario/bcw/<topic> feature branch)
├── carambus_phat/     # PHAT scenario (master pull OR scenario/phat/<topic> feature branch)
├── carambus_api/      # API scenario (master pull OR scenario/api/<topic> feature branch)
└── carambus_data/     # Scenario configs (no code edits expected)
```

---

## Mandatory Mode Declaration (CRITICAL)

⚠️ **No edits, commits, or branch operations until the user has explicitly declared the work mode for this chat.** If a request would require an edit and no mode has been declared, the AI MUST stop and ask the user to declare one.

The two valid declarations:

1. **`start master mode`** — work on `carambus_master/` on the `master` branch.
2. **`start feature branch mode <topic> in <scenario>`** — work in the named scenario checkout on a `scenario/<scenario>/<topic>` branch (creating it if it doesn't exist).

Examples:
- "start master mode"
- "start feature branch mode rfid-table-monitor in carambus_bcw"
- "start feature branch mode disk-cleanup in carambus_api"

The declaration sticks for the entire chat unless the user explicitly switches mode (a fresh declaration ends the previous one).

### Mode-switch hygiene

When switching modes inside a chat:
1. Commit or stash any pending work in the previously active checkout.
2. Confirm the new mode's target checkout is in the expected state (clean tree, correct branch).
3. New edits land only in the new mode's scope.

---

## Master Mode

**Declaration:** `start master mode`

### Workflow

1. ✅ All edits land in `carambus_master/` only.
2. ✅ Branch: `master`. Pull first (`git pull --rebase origin master`).
3. ✅ Commit and push from `carambus_master/`.
4. ⏸️ Other scenario checkouts are **not** auto-pulled. The user pulls them when ready to deploy.

### Forbidden in Master Mode

- ❌ Modify files in `carambus_bcw/`, `carambus_phat/`, `carambus_api/`.
- ❌ Commit from any checkout other than `carambus_master/`.
- ❌ Push directly to a remote feature branch.

### Example

```bash
cd /Users/gullrich/DEV/carambus/carambus_master
git pull --rebase origin master
# edits + tests
git add <files>
git commit -m "..."
git push origin master
```

Other scenarios stay on whatever branch they were on (master or a feature branch). Their working trees do not need to be checked.

---

## Feature Branch Mode

**Declaration:** `start feature branch mode <topic> in <scenario>`

Use this when work cannot ship via master directly — e.g., a scenario-specific experiment, a long-running refactor that must coexist with continuing master development, or risky changes that need staging.

### Branch naming convention (mandatory)

```
scenario/<scenario>/<topic>
```

Examples: `scenario/bcw/rfid-table-monitor`, `scenario/phat/streaming-overlay`, `scenario/api/disk-cleanup-refactor`.

The `scenario/<scenario>/` prefix makes it visible at a glance which checkout owns the branch and prevents accidental checkout in the wrong tree.

### Workflow

1. ✅ `cd /Users/gullrich/DEV/carambus/<scenario>` (e.g., `carambus_bcw`).
2. ✅ Verify clean tree (`git status`).
3. ✅ Create or check out the feature branch:
   ```bash
   git fetch origin
   git checkout -b scenario/<scenario>/<topic> origin/master   # first time
   # OR
   git checkout scenario/<scenario>/<topic>                    # already exists
   ```
4. ✅ Edits, commits, push to remote feature branch:
   ```bash
   git push -u origin scenario/<scenario>/<topic>
   ```
5. ✅ Periodic master merge (drift prevention — see below).
6. ✅ Final merge back to master (see Final Merge Procedure).

### Forbidden in Feature Branch Mode

- ❌ Edit files in `carambus_master/` or any other scenario checkout.
- ❌ Push to `master` from the scenario checkout.
- ❌ Use a branch name without the `scenario/<scenario>/` prefix.
- ❌ Reuse a feature branch across two different scenarios (each scenario owns its own branches).

### Example

```bash
# User: "start feature branch mode rfid-experiment in carambus_bcw"
cd /Users/gullrich/DEV/carambus/carambus_bcw
git fetch origin
git checkout -b scenario/bcw/rfid-experiment origin/master
# edits + tests
git add <files>
git commit -m "..."
git push -u origin scenario/bcw/rfid-experiment
```

---

## Drift Prevention

Long-running feature branches drift from master and become painful to merge. To bound the drift:

- **Recommended cadence:** merge `origin/master` into the feature branch at least once per week, or before any major commit.
- **AI behavior:** when entering Feature Branch Mode for an existing branch, check divergence and prompt the user if it's stale.

```bash
# Inside the scenario checkout, on the feature branch:
git fetch origin master
behind=$(git rev-list --count HEAD..origin/master)
echo "Feature branch is $behind commits behind master."
# If > ~50 commits or > 7 days since last merge, prompt to merge master in:
git merge --no-ff origin/master -m "Merge master into scenario/<scenario>/<topic>"
git push
```

Resolve any conflicts here, in the feature branch — never on master.

---

## Final Merge Procedure (Feature Branch → Master)

When the feature branch is done and the user requests final merge:

1. **In the scenario checkout** — ensure the feature branch is current with master (drift merge above), all conflicts resolved, all tests green, branch pushed:
   ```bash
   cd /Users/gullrich/DEV/carambus/<scenario>
   git checkout scenario/<scenario>/<topic>
   git pull
   git fetch origin master
   git merge --no-ff origin/master -m "Final master sync before merge-back"   # if anything to merge
   # run tests, fix conflicts
   git push
   ```

2. **In carambus_master** — AI performs the merge atomically:
   ```bash
   cd /Users/gullrich/DEV/carambus/carambus_master
   git checkout master
   git pull --rebase origin master
   git fetch origin
   git merge --no-ff origin/scenario/<scenario>/<topic> -m "Merge scenario/<scenario>/<topic> into master"
   git push origin master
   ```

3. **Optional cleanup** (only after user confirms merge is good):
   ```bash
   git push origin --delete scenario/<scenario>/<topic>
   ```
   The local branch in the scenario checkout can stay until the user is ready to repurpose that checkout.

The `--no-ff` flag preserves the merge commit so the feature branch's history is identifiable in `git log --graph`.

---

## Pre-Edit Precondition Check

Before the first edit in a declared mode, run a scoped sanity check on **only** the target checkout (other checkouts are decoupled and don't need verification anymore — that's the whole point of the new model).

```bash
# In master mode:
cd /Users/gullrich/DEV/carambus/carambus_master
git fetch -q origin master
echo "Branch:  $(git rev-parse --abbrev-ref HEAD)"   # must be 'master'
counts=$(git rev-list --left-right --count origin/master...HEAD)
echo "vs origin/master: behind=$(echo $counts | awk '{print $1}') ahead=$(echo $counts | awk '{print $2}')"
git status --short

# In feature branch mode:
cd /Users/gullrich/DEV/carambus/<scenario>
git fetch -q origin
echo "Branch:  $(git rev-parse --abbrev-ref HEAD)"   # must be 'scenario/<scenario>/<topic>'
git status --short
```

Stop and ask the user if:
- The current branch doesn't match the declared mode.
- The working tree has uncommitted changes the user didn't expect.
- The local branch has unpushed commits and the user is about to overwrite or rebase.

---

## Mode Quick Reference

| Aspect | Master Mode | Feature Branch Mode |
|---|---|---|
| Declaration | `start master mode` | `start feature branch mode <topic> in <scenario>` |
| Edit location | `carambus_master/` only | `<scenario>/` only |
| Branch | `master` | `scenario/<scenario>/<topic>` |
| Push target | `origin master` | `origin scenario/<scenario>/<topic>` |
| Other checkouts | Untouched (user pulls when ready) | Untouched (incl. `carambus_master`) |
| Drift mgmt | n/a | Periodic `merge origin/master` |
| Closure | Push to master = done | Final merge in `carambus_master` |

---

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

---

## Common Mistakes

1. ❌ Starting any edit without an explicit mode declaration.
2. ❌ Modifying files in a scenario checkout while in master mode (or vice versa).
3. ❌ Using a feature branch name without the `scenario/<scenario>/` prefix.
4. ❌ Letting a feature branch drift weeks from master before merging.
5. ❌ Merging a feature branch from the scenario checkout instead of `carambus_master/` (master-side merge keeps the canonical commit graph in one place).
6. ❌ Direct production server interventions (read-only access only).

---

## Deployment Workflow

```
master commit → user pulls in scenario checkout → user runs Capistrano deploy
```

User handles:
- `git pull` in deployment checkouts when ready (no automatic propagation).
- `rake "scenario:deploy[carambus_bcw]"` for Capistrano deploys.
- Production server access (read-only).

The AI never deploys, never touches production servers, and never auto-pulls scenario checkouts after a master push.

---

## Additional Resources

For detailed deployment documentation: `/Users/gullrich/DEV/carambus/carambus_master/docs/developers/scenario-management.de.md`
